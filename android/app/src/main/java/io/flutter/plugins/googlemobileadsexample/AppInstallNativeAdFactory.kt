package io.flutter.plugins.googlemobileadsexample

import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.RatingBar
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.NativeAdFactory
import com.fruitblast.match3.game.R

class AppInstallNativeAdFactory(private val layoutInflater: LayoutInflater) : NativeAdFactory {

    companion object {
        private const val DEFAULT_HEADLINE_COLOR = "#1e3a8a"
        private const val DEFAULT_BODY_COLOR = "#475569"
        private const val DEFAULT_BUTTON_BG_COLOR = "#059669"
        private const val DEFAULT_BUTTON_TEXT_COLOR = "#FFFFFF"
    }

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        android.util.Log.d("AppInstallNativeAdFactory", "Creating app install native ad view")
        android.util.Log.d("AppInstallNativeAdFactory", "Headline: ${nativeAd.headline}")
        android.util.Log.d("AppInstallNativeAdFactory", "Store: ${nativeAd.store}")
        android.util.Log.d("AppInstallNativeAdFactory", "Star Rating: ${nativeAd.starRating}")
        android.util.Log.d("AppInstallNativeAdFactory", "Custom options: $customOptions")

        val adView = layoutInflater.inflate(
            R.layout.native_ad_app_install,
            null
        ) as NativeAdView

        adView.layoutParams = android.view.ViewGroup.LayoutParams(
            android.view.ViewGroup.LayoutParams.MATCH_PARENT,
            android.view.ViewGroup.LayoutParams.MATCH_PARENT
        )

        // Register views
        adView.headlineView = adView.findViewById(R.id.app_name)
        adView.iconView = adView.findViewById(R.id.app_icon)
        adView.mediaView = adView.findViewById(R.id.ad_media)
        adView.starRatingView = adView.findViewById(R.id.star_rating)
        adView.storeView = adView.findViewById(R.id.store_name)
        adView.callToActionView = adView.findViewById(R.id.install_button)

        // --- Headline ---
        val headlineView = adView.headlineView as TextView
        headlineView.text = nativeAd.headline
        headlineView.visibility = View.VISIBLE

        // --- Media ---
        val mediaView = adView.mediaView as MediaView
        if (nativeAd.mediaContent != null) {
            mediaView.setMediaContent(nativeAd.mediaContent!!)
            mediaView.visibility = View.VISIBLE
        } else {
            mediaView.visibility = View.INVISIBLE
        }

        // --- App Icon ---
        val iconView = adView.iconView as ImageView
        if (nativeAd.icon == null) {
            iconView.visibility = View.INVISIBLE
        } else {
            iconView.setImageDrawable(nativeAd.icon!!.drawable)
            iconView.visibility = View.VISIBLE
        }

        // --- Star Rating ---
        val ratingBar = adView.starRatingView as RatingBar
        if (nativeAd.starRating == null) {
            ratingBar.visibility = View.INVISIBLE
        } else {
            ratingBar.rating = nativeAd.starRating!!.toFloat()
            ratingBar.visibility = View.VISIBLE
        }

        // --- Store Name ---
        val storeView = adView.storeView as TextView
        if (nativeAd.store == null) {
            storeView.visibility = View.INVISIBLE
        } else {
            storeView.text = nativeAd.store
            storeView.visibility = View.VISIBLE
        }

        // --- Install Button ---
        val installButton = adView.callToActionView as Button
        if (nativeAd.callToAction == null) {
            installButton.visibility = View.INVISIBLE
        } else {
            installButton.text = nativeAd.callToAction
            installButton.visibility = View.VISIBLE
        }

        // ✅ Always apply styling — null check ની બહાર
        applyCustomHeadlineStyle(headlineView, customOptions)
        applyCustomButtonStyle(installButton, customOptions)

        adView.setNativeAd(nativeAd)
        return adView
    }

    /**
     * Applies custom or default color to Headline TextView.
     * Falls back to DEFAULT_HEADLINE_COLOR if customOptions is null or missing.
     */
    private fun applyCustomHeadlineStyle(
        headline: TextView,
        customOptions: MutableMap<String, Any>?
    ) {
        val headlineColor = customOptions?.get("headlineTextColor") as? String
            ?: DEFAULT_HEADLINE_COLOR
        try {
            headline.setTextColor(Color.parseColor(headlineColor))
        } catch (e: IllegalArgumentException) {
            headline.setTextColor(Color.parseColor(DEFAULT_HEADLINE_COLOR))
        }
    }

    /**
     * Applies custom or default styling to the Install Button.
     * Uses GradientDrawable to preserve rounded corners from XML drawable
     * while still applying custom background color.
     *
     * Supported options:
     * - "buttonBackgroundColor": String hex color e.g. "#1976D2"
     * - "buttonTextColor": String hex color e.g. "#FFFFFF"
     * - "buttonCornerRadius": Double corner radius in dp e.g. 8.0
     * - "buttonTextSize": Double text size in sp e.g. 16.0
     * - "buttonMinHeight": Double min height in dp e.g. 48.0
     */
    private fun applyCustomButtonStyle(
        button: Button,
        customOptions: MutableMap<String, Any>?
    ) {
        val density = button.context.resources.displayMetrics.density

        // Button background color — default if not provided
        val bgColor = customOptions?.get("buttonBackgroundColor") as? String
            ?: DEFAULT_BUTTON_BG_COLOR

        // Corner radius — default 8dp if not provided
        val cornerRadiusDp = (customOptions?.get("buttonCornerRadius") as? Number)?.toFloat() ?: 8f
        val cornerRadiusPx = cornerRadiusDp * density

        // ✅ GradientDrawable use karo — rounded corners preserve thay
        try {
            val drawable = GradientDrawable()
            drawable.shape = GradientDrawable.RECTANGLE
            drawable.cornerRadius = cornerRadiusPx
            drawable.setColor(Color.parseColor(bgColor))
            button.background = drawable
        } catch (e: IllegalArgumentException) {
            val drawable = GradientDrawable()
            drawable.shape = GradientDrawable.RECTANGLE
            drawable.cornerRadius = cornerRadiusPx
            drawable.setColor(Color.parseColor(DEFAULT_BUTTON_BG_COLOR))
            button.background = drawable
        }

        // Button text color — default if not provided
        val textColor = customOptions?.get("buttonTextColor") as? String
            ?: DEFAULT_BUTTON_TEXT_COLOR
        try {
            button.setTextColor(Color.parseColor(textColor))
        } catch (e: IllegalArgumentException) {
            button.setTextColor(Color.parseColor(DEFAULT_BUTTON_TEXT_COLOR))
        }

        // Button text size (optional)
        val textSize = customOptions?.get("buttonTextSize") as? Number
        if (textSize != null) {
            button.textSize = textSize.toFloat()
        }

        // Button min height (optional)
        val minHeight = customOptions?.get("buttonMinHeight") as? Number
        if (minHeight != null) {
            button.minimumHeight = (minHeight.toFloat() * density).toInt()
        }
    }
}