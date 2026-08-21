#include <iostream>
#include <fstream>
#include <vector>
#include <memory>
#include <algorithm>
#include <cmath>
#include <thread>

#define STB_IMAGE_IMPLEMENTATION
#include "stb/stb_image.h"

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb/stb_image_write.h"

#include "tensorflow/lite/interpreter.h"
#include "tensorflow/lite/kernels/register.h"
#include "tensorflow/lite/model.h"
#include "tensorflow/lite/delegates/xnnpack/xnnpack_delegate.h"

int main(int argc, char* argv[]) {
    if (argc < 3) {
        std::cerr << "Usage: " << argv[0] << " <model.tflite> <image.jpg>\n";
        return -1;
    }

    const std::string model_path = argv[1];
    const std::string test_image = argv[2];

    std::unique_ptr<tflite::FlatBufferModel> model = tflite::FlatBufferModel::BuildFromFile(model_path.c_str());
    if (!model) {
        std::cerr << "Failed to parse model file.\n";
        return -1;
    }

    tflite::ops::builtin::BuiltinOpResolver resolver;
    tflite::InterpreterBuilder builder(*model, resolver);
    std::unique_ptr<tflite::Interpreter> interpreter;

    if (builder(&interpreter) != kTfLiteOk || !interpreter) {
        std::cerr << "Error: Failed to construct interpreter pipeline.\n";
        return -1;
    }

    // Configure XNNPACK Delegate for multi-threaded performance
    TfLiteXNNPackDelegateOptions xnnpack_options = TfLiteXNNPackDelegateOptionsDefault();
    xnnpack_options.num_threads = std::max(2U, std::thread::hardware_concurrency());

    std::unique_ptr<TfLiteDelegate, void(*)(TfLiteDelegate*)> xnnpack_delegate(
        TfLiteXNNPackDelegateCreate(&xnnpack_options),
        TfLiteXNNPackDelegateDelete
        );

    if (interpreter->ModifyGraphWithDelegate(xnnpack_delegate.get()) != kTfLiteOk) {
        std::cerr << "Warning: Failed to apply XNNPACK delegate. Falling back to CPU.\n";
    } else {
        std::cout << "Successfully accelerated graph execution using XNNPACK!\n";
    }

    if (!interpreter || interpreter->AllocateTensors() != kTfLiteOk) {
        std::cerr << "Failed to allocate memory layers for interpreter pipeline.\n";
        return -1;
    }

    TfLiteTensor* input_tensor = interpreter->input_tensor(0);

    int output_index = interpreter->outputs()[0];
    TfLiteTensor* output_tensor = interpreter->tensor(output_index);

    if (!input_tensor || !output_tensor) {
        std::cerr << "Error: Invalid or missing graph tensors.\n";
        return -1;
    }

    if (input_tensor->type != kTfLiteInt8 || output_tensor->type != kTfLiteInt8) {
        std::cerr << "Error: Model layers are not strict INT8. Re-check Python conversion config!\n";
        return -1;
    }

    const int model_h = input_tensor->dims->data[1];
    const int model_w = input_tensor->dims->data[2];

    const float input_scale = input_tensor->params.scale;
    const int32_t input_zero_point = input_tensor->params.zero_point;
    const float output_scale = output_tensor->params.scale;
    const int32_t output_zero_point = output_tensor->params.zero_point;

    std::cout << "Target Quantization Mapping Configured:\n"
              << " -> Input Scale: " << input_scale << " | Zero Point: " << input_zero_point << "\n"
              << " -> Output Scale: " << output_scale << " | Zero Point: " << output_zero_point << "\n\n";

    const int8_t quantized_threshold = static_cast<int8_t>(std::round(0.5f / output_scale) + output_zero_point);

    int img_width, img_height, img_channels;
    std::unique_ptr<unsigned char, void(*)(void*)> img_data(
        stbi_load(test_image.c_str(), &img_width, &img_height, &img_channels, 3),
        stbi_image_free
        );

    if (!img_data) {
        std::cerr << "Error: Failed to decode image file.\n";
        return -1;
    }

    int8_t* base_input_ptr = interpreter->typed_input_tensor<int8_t>(0);
    if (!base_input_ptr) {
        std::cerr << "Error: Unable to acquire a valid mutable pointer to input buffer.\n";
        return -1;
    }

    // Bilinear Resizing and Normalization
    for (int y = 0; y < model_h; ++y) {
        float src_y_f = ((float)y + 0.5f) * ((float)img_height / model_h) - 0.5f;
        src_y_f = std::clamp(src_y_f, 0.0f, (float)(img_height - 1));
        int y0 = static_cast<int>(src_y_f);
        int y1 = std::min(y0 + 1, img_height - 1);
        float y_weight = src_y_f - y0;

        int8_t* dest_row = &base_input_ptr[y * model_w * 3];

        for (int x = 0; x < model_w; ++x) {
            float src_x_f = ((float)x + 0.5f) * ((float)img_width / model_w) - 0.5f;
            src_x_f = std::clamp(src_x_f, 0.0f, (float)(img_width - 1));
            int x0 = static_cast<int>(src_x_f);
            int x1 = std::min(x0 + 1, img_width - 1);
            float x_weight = src_x_f - x0;

            int channel_map[3] = {0, 1, 2}; // Standard RGB format

            for (int c = 0; c < 3; ++c) {
                int src_c = channel_map[c];

                float p00 = img_data.get()[(y0 * img_width + x0) * 3 + src_c];
                float p10 = img_data.get()[(y0 * img_width + x1) * 3 + src_c];
                float p01 = img_data.get()[(y1 * img_width + x0) * 3 + src_c];
                float p11 = img_data.get()[(y1 * img_width + x1) * 3 + src_c];

                float top = p00 + x_weight * (p10 - p00);
                float bottom = p01 + x_weight * (p11 - p01);

                // This is your raw pixel value ranging from 0.0f to 255.0f
                float raw_pixel = top + y_weight * (bottom - top);

                // Quantize the raw [0, 255] value directly using the new model parameters
                float quantized = std::round(raw_pixel / input_scale) + input_zero_point;

                dest_row[x * 3 + c] = static_cast<int8_t>(std::clamp(static_cast<int32_t>(quantized), -128, 127));
            }
        }
    }

    // =====================================================================
    // HARDWARE INPUT DEBUGGER HOOK: RECONSTRUCT INT8 BACK TO IMAGE DATA
    // =====================================================================
    {
        std::vector<uint8_t> debug_pixels(model_w * model_h * 3);
        int8_t* active_model_input = interpreter->typed_input_tensor<int8_t>(0);

        for (int i = 0; i < model_w * model_h * 3; ++i) {
            int8_t quantized_val = active_model_input[i];

            // Map straight back from INT8 to [0, 255]
            float raw_pixel_f = (static_cast<float>(quantized_val) - input_zero_point) * input_scale;

            debug_pixels[i] = static_cast<uint8_t>(std::clamp(std::round(raw_pixel_f), 0.0f, 255.0f));
        }

        std::string debug_out_path = "rescale.jpg";
        stbi_write_jpg(debug_out_path.c_str(), model_w, model_h, 3, debug_pixels.data(), 90);
    }
    // =====================================================================

    if (interpreter->Invoke() != kTfLiteOk) {
        std::cerr << "Inference execution error on file: " << test_image.c_str() << "\n";
        return -1;
    }

    // Read the actual data value inside the 0-th index of the output array buffer
    int8_t* output_data_ptr = interpreter->typed_output_tensor<int8_t>(0);
    if (!output_data_ptr) {
        std::cerr << "Error: Output array data is missing.\n";
        return -1;
    }

    int8_t raw_int8_output = output_data_ptr[0];

    // Convert the validated tensor element back to a confidence probability scale
    float real_probability = (static_cast<float>(raw_int8_output) - output_zero_point) * output_scale;

    std::string predicted_class;
    float confidence = 0.0f;

    if (raw_int8_output >= quantized_threshold) {
        predicted_class = "dog";
        confidence = real_probability;
    } else {
        predicted_class = "cat";
        confidence = 1.0f - real_probability;
    }

    std::cout << test_image.c_str() << " is classified as " << predicted_class
              << " with " << (confidence * 100.0f) << "\n";

    return 0;
}
