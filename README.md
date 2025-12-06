# Local LLM Companion 🤖📱

**A high-performance, offline AI chat application built with Flutter and C++.**

![Flutter](https://img.shields.io/badge/Flutter-3.19-blue) ![C++](https://img.shields.io/badge/C++-17-red) ![Platform](https://img.shields.io/badge/Platform-Android-green) ![License](https://img.shields.io/badge/License-MIT-purple)

## 📖 Overview
Local LLM Companion is a cross-platform mobile application that runs Large Language Models (LLMs) directly on-device. Unlike cloud-based solutions (ChatGPT, Gemini), this app performs all inference **locally** using a custom C++ backend powered by `llama.cpp`. This ensures 100% privacy, zero latency dependency, and offline capability.

It features a custom **Dart FFI bridge** to communicate between the Flutter UI and the native C++ engine, enabling real-time token streaming and efficient memory management.

## ✨ Key Features
* **🚀 High Performance:** Custom C++ inference engine using the Android NDK.
* **⚡ Real-time Streaming:** Token-by-token generation (Typewriter effect) via Isolate-based background threads.
* **🧠 Model Agnostic:** Supports GGUF models (Qwen, TinyLlama, etc.) with dynamic prompt templating.
* **💾 Persistent Memory:** SQLite database stores chat history and conversations locally.
* **🎨 Rich UI:** Markdown rendering (code blocks, tables), Dark Mode support, and smooth animations.
* **⚙️ Custom Personas:** Configurable System Prompts to change the AI's personality.
* **📊 Observability:** Real-time TPS (Tokens Per Second) monitoring.

## 🏗 Architecture
The app follows a **Clean Architecture** pattern with a strict separation of concerns:

1.  **UI Layer (Flutter):** Handles user input, Markdown rendering, and state management.
2.  **Logic Layer (Dart):** `PromptEngine` manages context windows (sliding window memory) and format tags (`<|im_start|>`).
3.  **Bridge Layer (Dart FFI):** Uses `dart:ffi` to bind to native C symbols.
4.  **Native Backend (C++):** A custom wrapper around `llama.cpp` that handles:
    * Model loading & Quantization.
    * KV Cache management (Context clearing).
    * Token generation loop with stop-word detection.

## 🛠️ Tech Stack
* **Frontend:** Flutter (Dart)
* **Backend:** C++ (Standard Library + JNI)
* **AI Engine:** llama.cpp (Optimized for ARM64)
* **Database:** SQLite (via `sqflite`)
* **State Management:** `setState` + `Streams`
* **Concurrency:** Dart Isolates for non-blocking inference.

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (3.x+)
* Android Studio + NDK (Side-by-side)
* CMake

### Installation
1.  Clone the repository:
    ```bash
    git clone [https://github.com/your-username/llm_companion.git](https://github.com/your-username/llm_companion.git)
    cd llm_companion
    ```
2.  Install dependencies:
    ```bash
    flutter pub get
    ```
3.  Run the app (Release mode recommended for speed):
    ```bash
    flutter run --release
    ```

### Usage
1.  Open the app and tap the **Settings** icon (top right).
2.  Download a model (e.g., **Qwen 1.5B**).
3.  Once loaded, start chatting!
4.  Use the **Psychology** icon to change the System Prompt (e.g., "You are a pirate").

## 📸 Screenshots
![alt text](<media/Screenshot from 2025-12-06 20-31-43.png>)
![alt text](<media/Screenshot from 2025-12-06 20-31-50.png>)
![alt text](<media/Screenshot from 2025-12-06 20-31-59.png>)
![alt text](<media/Screenshot from 2025-12-06 20-38-10.png>)
![alt text](<media/Screenshot from 2025-12-06 20-41-44.png>)