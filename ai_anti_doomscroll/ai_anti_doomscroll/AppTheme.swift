//
//  AppTheme.swift
//  ai_anti_doomscroll
//
//  Central design tokens for the app's visual style.

import SwiftUI

// Custom environment key so the real system colorScheme is accessible
// even inside views wrapped with .environment(\.colorScheme, .light)
private struct SystemColorSchemeKey: EnvironmentKey {
    static let defaultValue: ColorScheme = .light
}
extension EnvironmentValues {
    var systemColorScheme: ColorScheme {
        get { self[SystemColorSchemeKey.self] }
        set { self[SystemColorSchemeKey.self] = newValue }
    }
}

enum AppTheme {
    // ── Dark mode custom palette ────────────────────────────────────────
    // Using medium grays instead of near-black system defaults
    static let darkBackground = Color(red: 0.32, green: 0.32, blue: 0.34)   // medium-dark gray
    static let darkCard       = Color(red: 0.34, green: 0.34, blue: 0.36)   // lighter — cards pop
    static let darkRow        = Color(red: 0.40, green: 0.40, blue: 0.42)   // lightest — rows inside cards

    // ── Background ─────────────────────────────────────────────────────
    static func backgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [darkBackground, darkBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(red: 0.93, green: 0.92, blue: 0.95),
                    Color(red: 0.86, green: 0.85, blue: 0.90)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // ── Cards ───────────────────────────────────────────────────────────
    // Use cardBg(for:) with systemColorScheme env key — bypasses .colorScheme(.light) override
    static func cardBg(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.87) : Color.white
    }
    static let cardBackground = Color.white  // fallback for light-mode-only contexts
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
    static let rowBackground = Color(UIColor.tertiarySystemGroupedBackground)

    // ── Buttons ─────────────────────────────────────────────────────────
    static let primaryButton       = Color(white: 0.10)
    static let primaryButtonShadow = Color.black.opacity(0.22)

    // ── Tab bar ─────────────────────────────────────────────────────────
    // Color.primary adapts: near-black in light, near-white in dark
    static let tabActive   = Color.primary
    static let tabInactive = Color.secondary
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
    @Environment(\.systemColorScheme) private var systemColorScheme
    var cornerRadius: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .background(AppTheme.cardBg(for: systemColorScheme))
            .cornerRadius(cornerRadius)
            .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }
}

extension View {
    func primaryButtonStyle() -> some View { modifier(PrimaryButtonStyle()) }
    func cardStyle(cornerRadius: CGFloat = 20) -> some View { modifier(CardStyle(cornerRadius: cornerRadius)) }
}

// MARK: - Subscription Gate Overlay

struct SubscriptionGateOverlay: View {
    var cornerRadius: CGFloat = 15
    var isLoggedIn: Bool = true
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                Text(isLoggedIn ? "Subscription feature" : "Sign in required")
                    .font(.caption2).bold()
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemFill))
            .cornerRadius(cornerRadius)
        }
        .buttonStyle(.plain)
    }
}
