cmake_minimum_required(VERSION 3.16)
project(image_classifier CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# file(COPY "${BR2_EXTERNAL_EXTPACK_PATH}/src/stb/stb_image.h" DESTINATION "${D}/stb")

add_executable(image_classifier main.cpp)

# Include the source directory from Buildroot so "stb/stb_image.h" is found
target_include_directories(image_classifier PRIVATE "${BR2_EXTERNAL_EXTPACK_PATH}/src")
# target_include_directories(image_classifier PRIVATE "${D}")

find_package(absl REQUIRED COMPONENTS log check)

target_link_libraries(image_classifier
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

install(TARGETS image_classifier DESTINATION bin)
