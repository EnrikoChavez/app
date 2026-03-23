//
//  OnboardingView.swift
//  ai_anti_doomscroll
//

import SwiftUI

#if canImport(FamilyControls)
import FamilyControls
#endif

private enum OnboardingStep: Int, CaseIterable, Hashable {
    case hook       = 0
    case attention  = 1
    case blocking   = 2
    case ai         = 3
    case task       = 4
    case permission = 5
}

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var step: OnboardingStep = .hook
    @State private var taskText = ""
    @State private var isRequestingPermission = false
    @FocusState private var taskFieldFocused: Bool

    private var progress: Double {
        Double(step.rawValue + 1) / Double(OnboardingStep.allCases.count)
    }

    var body: some View {
        ZStack {
            Color(red: 1.0, green: 0.88, blue: 0.88, opacity: 0.6).ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, 28)
                    .padding(.top, 60)
                    .padding(.bottom, 8)

                ZStack {
                    slideContent(for: step)
                        .id(step)
                        .transition(.opacity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { taskFieldFocused = false }

                bottomControls
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(.light)
        .animation(.easeInOut(duration: 0.38), value: step)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(0.09))
                .frame(height: 5)

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppTheme.primaryButton)
                    .frame(width: geo.size.width * progress, height: 5)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
            }
            .frame(height: 5)
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 14) {
            if step == .permission {
                Button(action: requestPermission) {
                    HStack(spacing: 8) {
                        if isRequestingPermission {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.85)
                        }
                        Text("Allow Screen Time")
                            .font(.body).bold()
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.primaryButton)
                    .cornerRadius(14)
                    .shadow(color: AppTheme.primaryButtonShadow, radius: 10, x: 0, y: 5)
                }
                .disabled(isRequestingPermission)

                Button("Not now") {
                    saveTaskAndFinish()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            } else {
                Button(action: advance) {
                    Text(nextButtonLabel)
                        .font(.body).bold()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.primaryButton)
                        .cornerRadius(14)
                        .shadow(color: AppTheme.primaryButtonShadow, radius: 10, x: 0, y: 5)
                }
            }
        }
    }

    private var nextButtonLabel: String {
        switch step {
        case .task:
            return taskText.trimmingCharacters(in: .whitespaces).isEmpty
                ? "Continue"
                : "Add to Today's Focus →"
        case .ai:
            return "Almost there →"
        default:
            return "Next →"
        }
    }

    // MARK: - Slide Content

    @ViewBuilder
    private func slideContent(for s: OnboardingStep) -> some View {
        switch s {
        case .hook:
            storySlide(
                icon: "iphone",
                iconColor: .orange,
                headline: "Sound familiar?",
                body: "You open an app with a low effort check... and look up 42 minutes later.\n\nNot your fault this happens. These apps are built by hundreds of experts specifically to keep you around."
            )
        case .attention:
            storySlide(
                icon: "hourglass",
                iconColor: .red,
                headline: "Your attention is finite.",
                body: "Every minute spent mindlessly scrolling is a minute taken from the things you actually care about.\n\nThis app helps you take those accidental \"42 minutes\" sessions back one at a time."
            )
        case .blocking:
            storySlide(
                icon: "iphone.slash",
                iconColor: .indigo,
                headline: "Automatic App Blocking",
                body: "Set a daily time limit on any distracting app. When you hit it, the app gets blocked — automatically.\n\n Immediately rerouting your focus."
            )
        case .ai:
            storySlide(
                icon: "waveform.circle.fill",
                iconColor: .purple,
                headline: "Your AI Accountability Partner",
                body: "Blocked and need back in? Have a quick voice or text chat with your AI companion.\n\nConvince your companion you're good to use distracting apps again — then get unblocked."
            )
        case .task:
            taskInputSlide
        case .permission:
            permissionSlide
        }
    }

    // MARK: - Slide Layouts

    private func storySlide(icon: String, iconColor: Color, headline: String, body: String) -> some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: icon)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(spacing: 16) {
                Text(headline)
                    .font(.title).bold()
                    .multilineTextAlignment(.center)

                Text(body)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 20)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 12)
    }

    private var taskInputSlide: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundColor(.green)
            }

            VStack(spacing: 14) {
                Text("Before we begin...")
                    .font(.title).bold()
                    .multilineTextAlignment(.center)

                Text("What's one thing you need to get done today? We'll add it straight to your Today's Focus list.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 20)
            }

            TextField("e.g. Finish the project proposal", text: $taskText)
                .focused($taskFieldFocused)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 3)
                .padding(.horizontal, 4)
                .submitLabel(.done)
                .onSubmit { advance() }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var permissionSlide: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundColor(.blue)
            }

            VStack(spacing: 16) {
                Text("One last thing")
                    .font(.title).bold()
                    .multilineTextAlignment(.center)

                Text("To block distracting apps, we need access to Screen Time.\n\nYour usage data stays on your device and is never shared with anyone.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 20)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Actions

    private func advance() {
        taskFieldFocused = false
        let nextRaw = step.rawValue + 1
        guard nextRaw < OnboardingStep.allCases.count,
              let next = OnboardingStep(rawValue: nextRaw) else { return }
        withAnimation(.easeInOut(duration: 0.38)) {
            step = next
        }
    }

    private func saveTaskAndFinish() {
        let trimmed = taskText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            UserDefaults.standard.set(trimmed, forKey: "onboardingPendingFocusTask")
        }
        Analytics.onboardingCompleted()
        hasSeenOnboarding = true
    }

    private func requestPermission() {
        isRequestingPermission = true
        Task {
            #if canImport(FamilyControls)
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            } catch {
                print("⚠️ Screen Time authorization declined: \(error.localizedDescription)")
            }
            #endif
            await MainActor.run {
                saveTaskAndFinish()
                isRequestingPermission = false
            }
        }
    }
}
