#include <stdint.h>

// This ensures the function is exported correctly for Dart to see
extern "C" __attribute__((visibility("default"))) __attribute__((used))
int32_t native_add(int32_t x, int32_t y) {
    return x + y;
}