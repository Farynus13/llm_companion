import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// C signatures
typedef NativeLoadModel = Int32 Function(Pointer<Utf8> path);

typedef NativeCompletion = Pointer<Utf8> Function(Pointer<Utf8> prompt, Pointer<Utf8> stopToken);

// Dart signatures
typedef DartLoadModel = int Function(Pointer<Utf8> path);
typedef DartCompletion = Pointer<Utf8> Function(Pointer<Utf8> prompt, Pointer<Utf8> stopToken);

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

  Future<bool> loadModel(String path) async {
    final cPath = path.toNativeUtf8();
    try {
      int result = _loadModel(cPath);
      return result == 0;
    } finally {
      malloc.free(cPath);
    }
  }

  String generate(String prompt, String stopToken) {
    final cPrompt = prompt.toNativeUtf8();
    final cStop = stopToken.toNativeUtf8(); // Convert to C string
    try {
      Pointer<Utf8> resultPtr = _completion(cPrompt, cStop);
      String result = resultPtr.toDartString();
      return result;
    } finally {
      malloc.free(cPrompt);
      malloc.free(cStop);
    }
  }
}