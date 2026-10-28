package com.globalqtx.globalqtx

import android.os.Bundle
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.globalqtx.globalqtx/bridge"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // قناة تواصل مع Flutter (ممكن نحتاجها لاحقاً)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getPlatformVersion") {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            } else {
                result.notImplemented()
            }
        }
    }
}
