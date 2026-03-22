//
//  OnboardingView.swift
//  ai_anti_doomscroll
//

import SwiftUI

private struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
}

private let pages: [OnboardingPage] = [
    OnboardingPage(
        icon: "iphone.slash",
        iconColor: .green,
        title: "Stop Doomscrolling",
        description: "Set time limits on distracting apps. When you hit your limit, they get blocked automatically — no willpower required."
    ),
    OnboardingPage(
        icon: "checkmark.circle.fill",
        iconColor: .blue,
        title: "Plan Your Day",
        description: "Dump your ideas into \"All Tasks\" then pick what matters most for today. Your AI companion will hold you accountable."
    ),
    OnboardingPage(
        icon: "waveform.circle.fill",
        iconColor: .purple,
        title: "Earn Your Apps Back",
        description: "Blocked? Have a quick voice call or text chat with your AI companion. Convince it you've done your work — then get unblocked."
    ),
    OnboardingPage(
        icon: "trophy.fill",
        iconColor: .green,
        title: "Build Better Habits",
        description: "Complete your tasks, watch your progress in the Gallery, and gradually reclaim your focus one day at a time."
    ),
]

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    pageView(page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            VStack(spacing: 20) {
                // Dot indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.blue : Color.gray.opacity(0.35))
                            .frame(width: index == currentPage ? 10 : 7, height: index == currentPage ? 10 : 7)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }

                // Action button
                Button(action: advance) {
                    Text(currentPage == pages.count - 1 ? "Get Started" : "Next")
                        .font(.body).bold()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 32)

                // Skip button (hidden on last page)
                if currentPage < pages.count - 1 {
                    Button("Skip") {
                        Analytics.onboardingSkipped(atPage: currentPage)
                        hasSeenOnboarding = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                } else {
                    Color.clear.frame(height: 20)
                }
            }
            .padding(.bottom, 48)
        }
        .preferredColorScheme(.light)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private func advance() {
        if currentPage < pages.count - 1 {
            withAnimation { currentPage += 1 }
        } else {
            Analytics.onboardingCompleted()
            hasSeenOnboarding = true
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: page.icon)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundColor(page.iconColor)
            }

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.title).bold()
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }
}
