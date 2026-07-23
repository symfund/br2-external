cmake_minimum_required(VERSION 3.16)
project(tflite_evaluator CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(tflite_evaluator main.cpp)

find_package(absl REQUIRED COMPONENTS log check)

target_link_libraries(tflite_evaluator
    PRIVATE
    tensorflow-lite
    XNNPACK
    pthreadpool
    cpuinfo
    kleidiai
    fft2d_fftsg2d
    fft2d_fftsg
    eight_bit_int_gemm
    absl::log
    absl::check
    pthread
    dl
)

install(TARGETS tflite_evaluator DESTINATION bin)
