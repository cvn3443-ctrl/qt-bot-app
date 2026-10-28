package com.globalqtx.globalqtx

import android.os.Bundle
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterPlugin
import io.flutter.plugins.webviewflutter.WebViewHostApiImpl
import io.flutter.plugins.webviewflutter.WebViewProxyApi
import io.flutter.plugins.webviewflutter.WebViewFlutterPlugin

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // هذا الجزء لحقن السكريبت مبكراً
        if (WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
            // رح نحقن السكريبت في التطبيق الرئيسي
        }
    }
}
