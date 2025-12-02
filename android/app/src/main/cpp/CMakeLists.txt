cmake_minimum_required(VERSION 3.10.2)

# Name of the library
project(llm_companion)

# Create a shared library named 'native_lib' from our source file
add_library( 
    native_lib 
    SHARED 
    native_lib.cpp 
)