// Analytics.swift
// Thin wrapper around PostHog for easy event tracking throughout the app.

import Foundation
import PostHog

enum Analytics {

    // MARK: - Setup

    private static let apiKey = "phc_Ps4HEKzvvEeDSp2OfELWTWmJ4j5Kqo29LsSlKos81m3"

    static func setup() {
        let config = PostHogConfig(apiKey: apiKey, host: "https://us.i.posthog.com")
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = false  // we track screens manually
        #if DEBUG
        config.debug = true
        #endif
        PostHogSDK.shared.setup(config)
    }

    // MARK: - Identity

    static func identify(userId: String) {
        PostHogSDK.shared.identify(userId)
    }

    static func reset() {
        PostHogSDK.shared.reset()
    }

    // MARK: - Auth

    static func signedInWithApple() {
        PostHogSDK.shared.capture("signed_in_apple")
    }

    static func signedInWithPhone() {
        PostHogSDK.shared.capture("signed_in_phone")
    }

    static func loggedOut() {
        PostHogSDK.shared.capture("logged_out")
    }

    static func accountDeleted() {
        PostHogSDK.shared.capture("account_deleted")
    }

    // MARK: - Onboarding

    static func onboardingCompleted() {
        PostHogSDK.shared.capture("onboarding_completed")
    }

    static func onboardingSkipped(atPage page: Int) {
        PostHogSDK.shared.capture("onboarding_skipped", properties: ["page": page])
    }

    // MARK: - Todos

    static func todoAdded() {
        PostHogSDK.shared.capture("todo_added")
    }

    static func todoCompleted() {
        PostHogSDK.shared.capture("todo_completed")
    }

    static func todoDeleted() {
        PostHogSDK.shared.capture("todo_deleted")
    }

    static func todoSetAsFocus() {
        PostHogSDK.shared.capture("todo_set_as_focus")
    }

    // MARK: - Monitoring

    static func monitoringStarted(minutes: Int, withWarning: Bool, appCount: Int, categoryCount: Int) {
        PostHogSDK.shared.capture("monitoring_started", properties: [
            "minutes": minutes,
            "with_warning": withWarning,
            "app_count": appCount,
            "category_count": categoryCount
        ])
    }

    static func monitoringStopped() {
        PostHogSDK.shared.capture("monitoring_stopped")
    }

    static func appsBlocked(minutes: Int) {
        PostHogSDK.shared.capture("apps_blocked", properties: ["threshold_minutes": minutes])
    }

    static func warningShownBeforeBlock() {
        PostHogSDK.shared.capture("warning_shield_shown")
    }

    static func warningDismissed() {
        PostHogSDK.shared.capture("warning_shield_dismissed")
    }

    // MARK: - Unblocking

    static func manualUnblockAttempted() {
        PostHogSDK.shared.capture("manual_unblock_attempted")
    }

    static func manualUnblockSucceeded() {
        PostHogSDK.shared.capture("manual_unblock_succeeded")
    }

    static func manualUnblockLimitReached() {
        PostHogSDK.shared.capture("manual_unblock_limit_reached")
    }

    // MARK: - AI Voice Call

    static func voiceCallStarted() {
        PostHogSDK.shared.capture("voice_call_started")
    }

    static func voiceCallEnded(durationSeconds: Double, unblocked: Bool) {
        PostHogSDK.shared.capture("voice_call_ended", properties: [
            "duration_seconds": durationSeconds,
            "unblocked": unblocked
        ])
    }

    static func voiceCallLimitReached() {
        PostHogSDK.shared.capture("voice_call_limit_reached")
    }

    // MARK: - AI Chat

    static func chatStarted() {
        PostHogSDK.shared.capture("chat_started")
    }

    static func chatEnded(unblocked: Bool) {
        PostHogSDK.shared.capture("chat_ended", properties: ["unblocked": unblocked])
    }

    // MARK: - Paywall

    static func paywallShown() {
        PostHogSDK.shared.capture("paywall_shown")
    }

    static func subscriptionStarted(productId: String) {
        PostHogSDK.shared.capture("subscription_started", properties: ["product_id": productId])
    }
}
