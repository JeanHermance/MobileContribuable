package com.tsirylab.contribuablemarche

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // FIX: Clear SharedPreferences to resolve OutOfMemoryError
        // This is a temporary fix to wipe the large data causing the crash.
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val editor = prefs.edit()
            editor.clear()
            editor.commit()
            android.util.Log.d("MainActivity", "✅ SharedPreferences CLEARED to fix OOM")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "❌ Error clearing SharedPreferences", e)
        }
    }
}
