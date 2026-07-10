package com.fruitblast.match3.game

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import io.flutter.plugins.googlemobileadsexample.AppInstallNativeAdFactory
import io.flutter.plugins.googlemobileadsexample.JobStyleNativeAdFactory
import io.flutter.plugins.googlemobileadsexample.MediumNativeAdFactory
import io.flutter.plugins.googlemobileadsexample.NativeAdFactoryExample

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register existing factory
        val factory = NativeAdFactoryExample(layoutInflater)
        GoogleMobileAdsPlugin.registerNativeAdFactory(flutterEngine, "adFactoryExample", factory)

        // Register job-style native ad factory with full-width CTA button
        try {
            val jobStyleFactory = JobStyleNativeAdFactory(layoutInflater)
            GoogleMobileAdsPlugin.registerNativeAdFactory(flutterEngine, "jobStyleAdFactory", jobStyleFactory)
            Log.d("MainActivity", "JobStyleNativeAdFactory registered successfully")
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to register JobStyleNativeAdFactory: ${e.message}")
            e.printStackTrace()
        }

        // Register app install native ad factory
        try {
            val appInstallFactory = AppInstallNativeAdFactory(layoutInflater)
            GoogleMobileAdsPlugin.registerNativeAdFactory(flutterEngine, "appInstallAdFactory", appInstallFactory)
            Log.d("MainActivity", "AppInstallNativeAdFactory registered successfully")
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to register AppInstallNativeAdFactory: ${e.message}")
            e.printStackTrace()
        }

        // Register medium native ad factory
        try {
            val mediumFactory = MediumNativeAdFactory(layoutInflater)
            GoogleMobileAdsPlugin.registerNativeAdFactory(flutterEngine, "mediumAdFactory", mediumFactory)
            Log.d("MainActivity", "MediumNativeAdFactory registered successfully")
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to register MediumNativeAdFactory: ${e.message}")
            e.printStackTrace()
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "adFactoryExample")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "jobStyleAdFactory")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "appInstallAdFactory")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "mediumAdFactory")
    }
}


