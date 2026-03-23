//
//  AppTheme.swift
//  ai_anti_doomscroll
//
//  Central design tokens for the app's visual style.

import SwiftUI

enum AppTheme {
    // ── Background ─────────────────────────────────────────────────────
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.93, green: 0.92, blue: 0.95),
            Color(red: 0.86, green: 0.85, blue: 0.90)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // ── Cards ───────────────────────────────────────────────────────────
    static let cardBackground   = Color.white
    static let cardShadowColor  = Color.black.opacity(0.07)
    static let cardShadowRadius: CGFloat = 14
    static let cardShadowY: CGFloat      = 6

    static func cardStyle<V: View>(_ view: V, cornerRadius: CGFloat = 20) -> some View {
        view
            .background(cardBackground)
            .cornerRadius(cornerRadius)
            .shadow(color: cardShadowColor, radius: cardShadowRadius, x: 0, y: cardShadowY)
    }

    // ── Elevated rows (inside cards) ────────────────────────────────────
    static let rowBackground = Color(white: 0.97)

    // ── Buttons ─────────────────────────────────────────────────────────
    /// Primary dark action button (the "almost black" look from the reference)
    static let primaryButton       = Color(white: 0.10)
    static let primaryButtonShadow = Color.black.opacity(0.22)

    // ── Tab bar ─────────────────────────────────────────────────────────
    static let tabActive   = Color(white: 0.10)
    static let tabInactive = Color(white: 0.60)
}

// MARK: - ViewModifier helpers

struct PrimaryButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.primaryButton)
            .foregroundColor(.white)
            .cornerRadius(15)
            .shadow(color: AppTheme.primaryButtonShadow, radius: 10, x: 0, y: 5)
    }
}

struct CardStyle: ViewModifier {
    var cornerRadius: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .background(AppTheme.cardBackground)
            .cornerRadius(cornerRadius)
            .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }
}

extension View {
    func primaryButtonStyle() -> some View { modifier(PrimaryButtonStyle()) }
    func cardStyle(cornerRadius: CGFloat = 20) -> some View { modifier(CardStyle(cornerRadius: cornerRadius)) }
}
