cmake_minimum_required(VERSION 3.10.2)
project(llm_companion)

# 1. Setup flags for Android (Performance optimizations)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3 -DNDEBUG")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -DNDEBUG")

# 2. Add the llama.cpp library
# We disable its examples/tests to speed up the build
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)

# This adds all the llama.cpp code to our project
add_subdirectory(llama.cpp)

# 3. Create our bridge library
add_library(native_lib SHARED native_lib.cpp)

# 4. Link our bridge to the llama engine
target_link_libraries(
    native_lib
    llama       # The core AI library
    ggml        # The tensor library (part of llama)
    android     # Android logging
    log
)