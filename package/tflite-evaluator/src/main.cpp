#include <iostream>
#include <vector>
#include <memory>
#include <random>
#include <algorithm>
#include <cmath>

#include "tensorflow/lite/interpreter.h"
#include "tensorflow/lite/kernels/register.h"
#include "tensorflow/lite/model.h"
#include "tensorflow/lite/delegates/xnnpack/xnnpack_delegate.h"

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <path_to_model.tflite>\n";
        return -1;
    }
    const std::string model_path = argv[1];

    std::unique_ptr<tflite::FlatBufferModel> model = tflite::FlatBufferModel::BuildFromFile(model_path.c_str());
    if (!model) {
        std::cerr << "Failed to load model: " << model_path << "\n";
        return -1;
    }

    tflite::ops::builtin::BuiltinOpResolver resolver;
    tflite::InterpreterBuilder builder(*model, resolver);
    std::unique_ptr<tflite::Interpreter> interpreter;
    builder(&interpreter);
    if (!interpreter) {
        std::cerr << "Failed to create interpreter!\n";
        return -1;
    }

    // Configure XNNPACK Delegate for multi-threaded performance
    TfLiteXNNPackDelegateOptions xnnpack_options = TfLiteXNNPackDelegateOptionsDefault();
    xnnpack_options.num_threads = 4; 

    std::unique_ptr<TfLiteDelegate, void(*)(TfLiteDelegate*)> xnnpack_delegate(
        TfLiteXNNPackDelegateCreate(&xnnpack_options),
        TfLiteXNNPackDelegateDelete
    );

    if (interpreter->ModifyGraphWithDelegate(xnnpack_delegate.get()) != kTfLiteOk) {
        std::cerr << "Warning: Failed to apply XNNPACK delegate. Falling back to CPU.\n";
    } else {
        std::cout << "Successfully accelerated graph execution using XNNPACK!\n";
    }

    if (interpreter->AllocateTensors() != kTfLiteOk) {
        std::cerr << "Failed to allocate tensors!\n";
        return -1;
    }

    int input_index = interpreter->inputs()[0];
    TfLiteTensor* input_tensor = interpreter->tensor(input_index);
    if (input_tensor->type != kTfLiteInt8) {
        std::cerr << "Error: Model input is not INT8!\n";
        return -1;
    }

    float input_scale = input_tensor->params.scale;
    int32_t input_zero_point = input_tensor->params.zero_point;
    int input_size = input_tensor->bytes; 

    // Generate random testing metrics
    std::vector<float> fake_fp32_input(input_size);
    std::mt19937 gen(42); 
    std::uniform_real_distribution<float> dis(0.0, 1.0);
    for (int i = 0; i < input_size; ++i) fake_fp32_input[i] = dis(gen);

    // Quantize: q = round(f / scale) + zero_point
    int8_t* input_data_ptr = interpreter->typed_input_tensor<int8_t>(0);
    for (int i = 0; i < input_size; ++i) {
        float scaled_val = std::round(fake_fp32_input[i] / input_scale) + input_zero_point;
        input_data_ptr[i] = static_cast<int8_t>(std::max(-128.0f, std::min(127.0f, scaled_val)));
    }

    if (interpreter->Invoke() != kTfLiteOk) {
        std::cerr << "Failed to invoke interpreter!\n";
        return -1;
    }

    int output_index = interpreter->outputs()[0];
    TfLiteTensor* output_tensor = interpreter->tensor(output_index);
    float output_scale = output_tensor->params.scale;
    int32_t output_zero_point = output_tensor->params.zero_point;
    int8_t* output_data_ptr = interpreter->typed_output_tensor<int8_t>(0);

    std::cout << "\n--- Accelerated Evaluation Complete ---\n";
    std::cout << "Dequantized Output (Index 0): " 
              << (static_cast<float>(output_data_ptr[0]) - output_zero_point) * output_scale << "\n";

    return 0;
}
