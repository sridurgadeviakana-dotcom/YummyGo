package com.example.yummy_go_application

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.yummy_go_application/navigation"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openGoogleMapsDirections") {
                val address = call.argument<String>("address") ?: ""
                val lat = call.argument<Double>("latitude")
                val lng = call.argument<Double>("longitude")

                try {
                    val destination = if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
                        "$lat,$lng"
                    } else if (address.isNotBlank()) {
                        val clean = address.trim()
                        if (!clean.lowercase().contains("hyderabad") && !clean.lowercase().contains("india")) {
                            "$clean, Hyderabad, Telangana"
                        } else {
                            clean
                        }
                    } else {
                        "17.4442,78.3845"
                    }

                    val encodedDest = Uri.encode(destination)
                    val dirUri = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$encodedDest&travelmode=driving")

                    // 1. Try launching Google Maps app directly with the driving route
                    val mapIntent = Intent(Intent.ACTION_VIEW, dirUri)
                    mapIntent.setPackage("com.google.android.apps.maps")
                    mapIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK

                    try {
                        startActivity(mapIntent)
                        result.success(true)
                    } catch (eMaps: Exception) {
                        // 2. Try geo navigation intent
                        try {
                            val geoUri = Uri.parse("geo:0,0?q=$encodedDest")
                            val geoIntent = Intent(Intent.ACTION_VIEW, geoUri)
                            geoIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(geoIntent)
                            result.success(true)
                        } catch (eGeo: Exception) {
                            // 3. Fallback: Launch directions URL in any browser/maps handler
                            val browserIntent = Intent(Intent.ACTION_VIEW, dirUri)
                            browserIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(browserIntent)
                            result.success(true)
                        }
                    }
                } catch (e: Exception) {
                    result.error("LAUNCH_FAILED", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
