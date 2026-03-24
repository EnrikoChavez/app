//
//  SignupPromptView.swift
//  ai_anti_doomscroll
//

import SwiftUI
import AuthenticationServices

struct SignupPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("hasSkippedSignup") private var hasSkippedSignup = false

    @State private var selectedCountry = LoginView.countries.first(where: { $0.code == "+1" }) ?? LoginView.countries[0]
    @State private var phoneNumber = ""
    @State private var otp = ""
    @State private var stage = "phone"
    @State private var errorMessage: String?
    @State private var isLoading = false

    private let bg = Color(red: 1.0, green: 0.88, blue: 0.88, opacity: 0.4)

    var fullPhoneNumber: String { selectedCountry.code + phoneNumber }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 28) {
                        // Top messaging
                        VStack(spacing: 12) {
                            Text("Signup")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .multilineTextAlignment(.center)

                            Text("Create an account and subscribe to be able to unblock apps via convincing an AI (and in a way yourself) through voice calls and texts that you've done or are going to do your tasks.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 56)
                        .padding(.horizontal, 24)

                        // Benefit pills
                        VStack(spacing: 10) {
                            benefitRow(icon: "mic.fill", color: .blue,
                                text: "AI voice companions to talk you out of doomscrolling")
                            benefitRow(icon: "lock.fill", color: .green,
                                text: "Automatic app blocking when time limits are hit")
                            benefitRow(icon: "checklist", color: .purple,
                                text: "Daily focus tasks understood by AI chats")
                        }
                        .padding(.horizontal, 24)

                        // Sign in with Apple
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.email, .fullName]
                        } onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 52)
                        .cornerRadius(14)
                        .padding(.horizontal, 24)

                        // Divider
                        HStack {
                            Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.25))
                            Text("or use phone").font(.caption).foregroundColor(.secondary)
                            Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.25))
                        }
                        .padding(.horizontal, 24)

                        // Phone / OTP
                        if stage == "phone" {
                            phoneInputSection
                        } else {
                            otpInputSection
                        }

                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        Button(action: { hasSkippedSignup = true; dismiss() }) {
                            Text("Skip for now")
                                .font(.subheadline)
                                .foregroundColor(.secondary.opacity(0.55))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }

    // MARK: - Phone input

    var phoneInputSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(LoginView.countries) { country in
                        Button { selectedCountry = country } label: {
                            Label {
                                Text("\(country.code)  \(country.name)")
                            } icon: {
                                Text(country.flag)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(selectedCountry.flag).font(.title3)
                        Text(selectedCountry.code).font(.body).foregroundColor(.primary)
                    }
                    .frame(width: 86)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 10)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 1))
                }

                TextField("Phone number", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 12)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 1))
            }

            Button(action: sendOTP) {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Send verification code").bold()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(phoneNumber.isEmpty ? Color.gray.opacity(0.3) : Color.black.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(phoneNumber.isEmpty || isLoading)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - OTP input

    var otpInputSection: some View {
        VStack(spacing: 14) {
            Text("Enter the verification code sent to \(fullPhoneNumber)")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            TextField("Verification code", text: $otp)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .padding(.vertical, 14)
                .padding(.horizontal, 12)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 1))
                .padding(.horizontal, 24)

            HStack(spacing: 12) {
                Button("Back") { stage = "phone"; otp = ""; errorMessage = nil }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 20)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 1))

                Button(action: verifyOTP) {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Verify").bold()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(otp.isEmpty ? Color.gray.opacity(0.3) : Color.black.opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(otp.isEmpty || isLoading)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Benefit row

    private func benefitRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: icon).font(.system(size: 15)).foregroundColor(color)
            }
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.6))
        .cornerRadius(12)
    }

    // MARK: - Apple Sign In

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                errorMessage = "Could not process Apple credentials."
                return
            }
            var nameStr: String?
            if let fullName = credential.fullName {
                let parts = [fullName.givenName, fullName.familyName].compactMap { $0 }
                if !parts.isEmpty { nameStr = parts.joined(separator: " ") }
            }
            authenticateWithApple(identityToken: identityToken, email: credential.email, fullName: nameStr)
        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue { return }
            errorMessage = "Apple Sign In failed. Please try again."
        }
    }

    func authenticateWithApple(identityToken: String, email: String?, fullName: String?) {
        guard let url = APIConfig.url("/auth/apple") else { return }
        isLoading = true
        errorMessage = nil
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        var body: [String: Any] = ["identity_token": identityToken]
        if let email { body["email"] = email }
        if let fullName { body["full_name"] = fullName }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false
                guard error == nil,
                      let data,
                      let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let token = result["token"] as? String else {
                    errorMessage = error == nil ? "Sign in failed." : "No internet connection."
                    return
                }
                KeychainHelper.saveToken(token)
                if let userId = result["user_id"] as? String {
                    UserDefaults.standard.set(userId, forKey: "userId")
                    Analytics.identify(userId: userId)
                }
                UserDefaults.standard.removeObject(forKey: "userPhone")
                Analytics.signedInWithApple()
                isLoggedIn = true
            }
        }.resume()
    }

    // MARK: - Phone OTP

    func sendOTP() {
        guard let url = APIConfig.url("/otp/send") else { return }
        isLoading = true
        errorMessage = nil
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["phone": fullPhoneNumber])
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error {
                    errorMessage = (error as NSError).code == NSURLErrorTimedOut
                        ? "Request timed out." : "Could not send code. Please try again."
                    return
                }
                if let http = response as? HTTPURLResponse, http.statusCode == 429 {
                    errorMessage = "Too many requests. Please wait."
                    return
                }
                stage = "otp"
            }
        }.resume()
    }

    func verifyOTP() {
        guard let url = APIConfig.url("/otp/verify") else { return }
        isLoading = true
        errorMessage = nil
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["phone": fullPhoneNumber, "otp": otp])
        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false
                guard error == nil,
                      let data,
                      let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let token = result["token"] as? String else {
                    errorMessage = error == nil ? "Incorrect code. Try again." : "No internet connection."
                    otp = ""
                    return
                }
                KeychainHelper.saveToken(token)
                UserDefaults.standard.set(fullPhoneNumber, forKey: "userPhone")
                Shared.defaults.set(fullPhoneNumber, forKey: Shared.phoneKey)
                if let userId = result["user_id"] as? String {
                    UserDefaults.standard.set(userId, forKey: "userId")
                    Analytics.identify(userId: userId)
                }
                Analytics.signedInWithPhone()
                isLoggedIn = true
            }
        }.resume()
    }
}
