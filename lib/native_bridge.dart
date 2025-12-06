import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate'; // Required for threading
import 'package:ffi/ffi.dart';

// --- FFI TYPES ---
typedef NativeCallback = Void Function(Pointer<Utf8>);
typedef NativeCompletion = Void Function(
    Pointer<Utf8> prompt, 
    Pointer<Utf8> stopToken, 
    Pointer<NativeFunction<NativeCallback>> callback 
);
typedef DartCompletion = void Function(
    Pointer<Utf8> prompt, 
    Pointer<Utf8> stopToken, 
    Pointer<NativeFunction<NativeCallback>> callback
);

typedef NativeLoadModel = Int32 Function(Pointer<Utf8> path);
typedef DartLoadModel = int Function(Pointer<Utf8> path);

// --- GLOBAL VARIABLES FOR ISOLATE ---
// These live ONLY inside the background isolate
SendPort? _isolateSendPort;

// Static function for C++ to call synchronously
// It MUST be static and cannot capture variables (that's why we use the global _isolateSendPort)
void _onTokenReceived(Pointer<Utf8> tokenPtr) {
  if (_isolateSendPort != null) {
    final token = tokenPtr.toDartString();
    _isolateSendPort!.send(token);
  }
}

// Data object to pass parameters to the Isolate
class _GenerateRequest {
  final SendPort sendPort;
  final String prompt;
  final String stopToken;
  
  _GenerateRequest(this.sendPort, this.prompt, this.stopToken);
}

class NativeBridge {
  late DynamicLibrary _lib;
  late DartLoadModel _loadModel;

  NativeBridge() {
    // We keep loadModel on the main thread because it's fast enough or handled via Futures
    _lib = _openLib();
    _loadModel = _lib
        .lookup<NativeFunction<NativeLoadModel>>('load_model')
        .asFunction<DartLoadModel>();
  }

  static DynamicLibrary _openLib() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libnative_lib.so');
    }
    return DynamicLibrary.process();
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

  // --- STREAMING (ISOLATE BASED) ---
  Stream<String> generateStream(String prompt, String stopToken) {
    StreamController<String> controller = StreamController();
    ReceivePort receivePort = ReceivePort();

    // Spawn the background thread
    Isolate.spawn(
      _isolateEntry, 
      _GenerateRequest(receivePort.sendPort, prompt, stopToken)
    );

    // Listen for messages from the background thread
    receivePort.listen((message) {
      if (message == null) {
        // Null means "Done"
        controller.close();
        receivePort.close();
      } else if (message is String) {
        // String means "Token"
        controller.add(message);
      } else if (message is List) {
        // Error tuple [error_string]
        controller.addError(message[0]);
        controller.close();
        receivePort.close();
      }
    });

    return controller.stream;
  }

  // This function runs on the BACKGROUND THREAD
  static void _isolateEntry(_GenerateRequest request) {
    // 1. Setup Global Port so the static callback can use it
    _isolateSendPort = request.sendPort;

    // 2. Open Library (Each isolate needs its own FFI handle)
    final lib = _openLib();
    final completion = lib
        .lookup<NativeFunction<NativeCompletion>>('completion')
        .asFunction<DartCompletion>();

    // 3. Prepare Arguments
    final cPrompt = request.prompt.toNativeUtf8();
    final cStop = request.stopToken.toNativeUtf8();
    
    // 4. Create the Function Pointer
    // Pointer.fromFunction creates a raw C pointer to our static Dart function.
    // This allows C++ to call it DIRECTLY without waiting for the event loop.
    final callbackPtr = Pointer.fromFunction<NativeCallback>(_onTokenReceived);

    try {
      // 5. BLOCKING CALL (This is fine, we are in a background thread)
      completion(cPrompt, cStop, callbackPtr);
      
      // 6. Signal Done
      request.sendPort.send(null);
      
    } catch (e) {
      request.sendPort.send(["Error: $e"]); // Send error as list
    } finally {
      malloc.free(cPrompt);
      malloc.free(cStop);
      // We don't close the isolate explicitly; Dart handles it when the function exits
    }
  }
}