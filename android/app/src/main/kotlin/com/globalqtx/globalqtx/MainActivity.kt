package com.globalqtx.globalqtx

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import com.pichillilorenzo.flutter_inappwebview_android.InAppWebViewFlutterPlugin

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // هاد السطر مهم جداً عشان المكتبة تشتغل
        InAppWebViewFlutterPlugin()
    }
}
