package com.globalqtx.globalqtx

import android.annotation.SuppressLint
import android.os.Bundle
import android.webkit.WebView
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterPlugin

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.globalqtx.globalqtx/bridge"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // تسجيل قناة للتواصل (ممكن نحتاجها لاحقاً)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getPlatformVersion") {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            } else {
                result.notImplemented()
            }
        }
    }
}
