package com.example.pianoscope

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    companion object {
        init {
            System.loadLibrary("rust_lib_pianoscope")
        }
    }
}
