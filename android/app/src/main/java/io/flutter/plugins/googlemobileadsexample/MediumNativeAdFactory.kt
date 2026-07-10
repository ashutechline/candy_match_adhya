package io.flutter.plugins.googlemobileadsexample

import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.LayoutInflater
import android.view.View
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.NativeAdFactory
import com.fruitblast.match3.game.R

class MediumNativeAdFactory(private val layoutInflater: LayoutInflater) : NativeAdFactory {

    companion object {
        private const val DEFAULT_HEADLINE_COLOR = "#FF5CA8"
        private const val DEFAULT_BODY_COLOR = "#F3ECFF"
        private const val DEFAULT_BUTTON_BG_COLOR = "#FF5CA8"
        private const val DEFAULT_BUTTON_TEXT_COLOR = "#FFFFFF"
    }

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        android.util.Log.d("MediumNativeAdFactory", "Creating medium native ad view")
        android.util.Log.d("MediumNativeAdFactory", "Headline: ${nativeAd.headline}")
        android.util.Log.d("MediumNativeAdFactory", "CTA: ${nativeAd.callToAction}")
        android.util.Log.d("MediumNativeAdFactory", "Custom options: $customOptions")

        val adView = layoutInflater.inflate(
            R.layout.native_ad_medium,
            null
        ) as NativeAdView

        adView.layoutParams = android.view.ViewGroup.LayoutParams(
            android.view.ViewGroup.LayoutParams.MATCH_PARENT,
            android.view.ViewGroup.LayoutParams.MATCH_PARENT
        )

        // --- Media View ---
        val mediaView = adView.findViewById<MediaView>(R.id.media_view)
        adView.mediaView = mediaView
        if (nativeAd.mediaContent != null) {
            mediaView.setMediaContent(nativeAd.mediaContent!!)
            mediaView.visibility = View.VISIBLE
        } else {
            mediaView.visibility = View.INVISIBLE
        }

        // --- Headline ---
        val headlineView = adView.findViewById<TextView>(R.id.primary)
        headlineView.text = nativeAd.headline
        headlineView.visibility = View.VISIBLE
        adView.headlineView = headlineView

        // --- Body ---
        val bodyView = adView.findViewById<TextView>(R.id.body)
        if (nativeAd.body != null && nativeAd.body!!.isNotEmpty()) {
            bodyView.text = nativeAd.body
            bodyView.visibility = View.VISIBLE
            adView.bodyView = bodyView
        } else {
            bodyView.visibility = View.INVISIBLE
            adView.bodyView = null
        }

        // ✅ Always apply text styling — body null/empty હોય તો પણ
        applyCustomTextStyle(headlineView, bodyView, customOptions)

        // --- Icon ---
        val iconView = adView.findViewById<ImageView>(R.id.icon)
        if (nativeAd.icon != null) {
            iconView.setImageDrawable(nativeAd.icon!!.drawable)
            iconView.visibility = View.VISIBLE
            adView.iconView = iconView
        } else {
            iconView.visibility = View.INVISIBLE
            adView.iconView = null
        }

        // --- CTA Button ---
        val ctaButton = adView.findViewById<TextView>(R.id.cta)
        if (nativeAd.callToAction != null && nativeAd.callToAction!!.isNotEmpty()) {
            ctaButton.text = nativeAd.callToAction
            ctaButton.visibility = View.VISIBLE
            adView.callToActionView = ctaButton
        } else {
            ctaButton.visibility = View.INVISIBLE
            adView.callToActionView = null
        }

        // ✅ Always apply button styling — CTA null/empty હોય તો પણ
        applyCustomButtonStyle(ctaButton, customOptions)

        adView.setNativeAd(nativeAd)
        return adView
    }

    /**
     * Applies custom or default styling to Headline and Body TextViews.
     * Falls back to default colors if customOptions is null or key is missing.
     */
    private fun applyCustomTextStyle(
        headline: TextView,
        body: TextView,
        customOptions: MutableMap<String, Any>?
    ) {
        // Headline color — default if not provided
        val headlineColor = customOptions?.get("headlineTextColor") as? String
            ?: DEFAULT_HEADLINE_COLOR
        try {
            headline.setTextColor(Color.parseColor(headlineColor))
        } catch (e: IllegalArgumentException) {
            headline.setTextColor(Color.parseColor(DEFAULT_HEADLINE_COLOR))
        }

        // Body color — default if not provided
        val bodyColor = customOptions?.get("bodyTextColor") as? String
            ?: DEFAULT_BODY_COLOR
        try {
            body.setTextColor(Color.parseColor(bodyColor))
        } catch (e: IllegalArgumentException) {
            body.setTextColor(Color.parseColor(DEFAULT_BODY_COLOR))
        }
    }

    /**
     * Applies custom or default styling to the CTA button (TextView).
     * Uses GradientDrawable to preserve rounded corners from XML drawable.
     *
     * Supported options:
     * - "buttonBackgroundColor": String hex color e.g. "#1976D2"
     * - "buttonTextColor": String hex color e.g. "#FFFFFF"
     * - "buttonCornerRadius": Double corner radius in dp e.g. 8.0
     * - "buttonTextSize": Double text size in sp e.g. 16.0
     * - "buttonMinHeight": Double min height in dp e.g. 48.0
     */
    private fun applyCustomButtonStyle(
        button: TextView,
        customOptions: MutableMap<String, Any>?
    ) {
        val density = button.context.resources.displayMetrics.density

        // Button background color — default if not provided
        val bgColor = customOptions?.get("buttonBackgroundColor") as? String
            ?: DEFAULT_BUTTON_BG_COLOR

        // Corner radius — default 8dp
        val cornerRadiusDp = (customOptions?.get("buttonCornerRadius") as? Number)?.toFloat() ?: 8f
        val cornerRadiusPx = cornerRadiusDp * density

        // ✅ GradientDrawable — rounded corners preserve thay
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