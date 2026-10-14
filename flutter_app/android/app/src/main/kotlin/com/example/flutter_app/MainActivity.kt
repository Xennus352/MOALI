package com.example.flutter_app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Host activity.
 *
 * Beyond the default Flutter host, this exposes a small `moali/auth` method
 * channel so the Dart layer can receive the Google sign-in deep link
 * (`moali://auth?token=...`). Android delivers the link either in [onCreate]
 * (cold start) or [onNewIntent] (the app was already running); both funnel into
 * [handleIntent], which invokes `deepLink` on the channel once it exists, or
 * parks the link until `configureFlutterEngine` runs.
 */
class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "moali/auth"
    }

    private var methodChannel: MethodChannel? = null
    private var pendingLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> {
                    result.success(pendingLink)
                    pendingLink = null
                }
                else -> result.notImplemented()
            }
        }
        // A cold-start link may have arrived before the engine was ready.
        pendingLink?.let { link ->
            channel.invokeMethod("deepLink", link)
            pendingLink = null
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val data = intent?.data ?: return
        if (data.scheme != "moali") return
        val link = data.toString()
        val channel = methodChannel
        if (channel != null) {
            channel.invokeMethod("deepLink", link)
        } else {
            pendingLink = link
        }
    }
}
