import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart'; // IMPORTANT: Helper for strings

// C signatures
typedef NativeLoadModel = Int32 Function(Pointer<Utf8> path);
typedef NativeCompletion = Pointer<Utf8> Function(Pointer<Utf8> prompt);

// Dart signatures
typedef DartLoadModel = int Function(Pointer<Utf8> path);
typedef DartCompletion = Pointer<Utf8> Function(Pointer<Utf8> prompt);

class NativeBridge {
  late DynamicLibrary _lib;
  late DartLoadModel _loadModel;
  late DartCompletion _completion;

  NativeBridge() {
    if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libnative_lib.so');
    } else {
      _lib = DynamicLibrary.process();
    }

    _loadModel = _lib
        .lookup<NativeFunction<NativeLoadModel>>('load_model')
        .asFunction<DartLoadModel>();

    _completion = _lib
        .lookup<NativeFunction<NativeCompletion>>('completion')
        .asFunction<DartCompletion>();
  }

  // 1. Load the model from a file path
  Future<bool> loadModel(String path) async {
    // Convert String -> C String
    final cPath = path.toNativeUtf8();
    try {
      // Run on a background isolate usually, but simple call here:
      int result = _loadModel(cPath);
      return result == 0;
    } finally {
      malloc.free(cPath); // Clean up memory
    }
  }

  // 2. Send prompt and get response
  String generate(String prompt) {
    final cPrompt = prompt.toNativeUtf8();
    try {
      // Call C++
      Pointer<Utf8> resultPtr = _completion(cPrompt);
      // Convert C String -> Dart String
      String result = resultPtr.toDartString();
      // Note: In production, we should free resultPtr too
      return result;
    } finally {
      malloc.free(cPrompt);
    }
  }
}