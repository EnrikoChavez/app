//
//  LoginView.swift
//  ai_anti_doomscroll
//
//  Created by Enriko Chavez on 8/17/25.
//

import SwiftUI
import AuthenticationServices

struct Country: Identifiable {
    let id = UUID()
    let name: String
    let code: String
    let flag: String
}

struct LoginView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @State private var selectedCountry = countries.first(where: { $0.code == "+1" }) ?? countries[0]
    @State private var phoneNumber = ""
    @State private var otp = ""
    @State private var stage = "phone" // "phone" or "otp"
    @State private var errorMessage: String?
    @State private var isLoading = false
    
    static let countries: [Country] = [
        Country(name: "United States", code: "+1", flag: "🇺🇸"),
        Country(name: "United Kingdom", code: "+44", flag: "🇬🇧"),
        Country(name: "United Arab Emirates", code: "+971", flag: "🇦🇪"),
        Country(name: "Turkey", code: "+90", flag: "🇹🇷"),
        Country(name: "Switzerland", code: "+41", flag: "🇨🇭"),
        Country(name: "Sweden", code: "+46", flag: "🇸🇪"),
        Country(name: "Spain", code: "+34", flag: "🇪🇸"),
        Country(name: "South Korea", code: "+82", flag: "🇰🇷"),
        Country(name: "South Africa", code: "+27", flag: "🇿🇦"),
        Country(name: "Singapore", code: "+65", flag: "🇸🇬"),
        Country(name: "Saudi Arabia", code: "+966", flag: "🇸🇦"),
        Country(name: "Russia", code: "+7", flag: "🇷🇺"),
        Country(name: "Portugal", code: "+351", flag: "🇵🇹"),
        Country(name: "Poland", code: "+48", flag: "🇵🇱"),
        Country(name: "Norway", code: "+47", flag: "🇳🇴"),
        Country(name: "New Zealand", code: "+64", flag: "🇳🇿"),
        Country(name: "Netherlands", code: "+31", flag: "🇳🇱"),
        Country(name: "Mexico", code: "+52", flag: "🇲🇽"),
        Country(name: "Japan", code: "+81", flag: "🇯🇵"),
        Country(name: "Italy", code: "+39", flag: "🇮🇹"),
        Country(name: "Ireland", code: "+353", flag: "🇮🇪"),
        Country(name: "India", code: "+91", flag: "🇮🇳"),
        Country(name: "Greece", code: "+30", flag: "🇬🇷"),
        Country(name: "Germany", code: "+49", flag: "🇩🇪"),
        Country(name: "France", code: "+33", flag: "🇫🇷"),
        Country(name: "Denmark", code: "+45", flag: "🇩🇰"),
        Country(name: "China", code: "+86", flag: "🇨🇳"),
        Country(name: "Canada", code: "+1", flag: "🇨🇦"),
        Country(name: "Brazil", code: "+55", flag: "🇧🇷"),
        Country(name: "Australia", code: "+61", flag: "🇦🇺"),
        Country(name: "Argentina", code: "+54", flag: "🇦🇷"),
    ]

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 24) {
                    Spacer()

                    Text("sign in")
                        .font(.largeTitle).bold()

                    // MARK: - Sign in with Apple
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Divider
                    HStack {
                        Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3))
                        Text("or").font(.subheadline).foregroundColor(.secondary)
                        Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3))
                    }
                    .padding(.horizontal, 30)

                    // MARK: - Phone sign in
                    if stage == "phone" {
                        phoneInputView

                        Button(isLoading ? "Sending..." : "Send OTP") {
                            sendOTP()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(phoneNumber.isEmpty || isLoading)
                        .padding(.top, 8)
                    }

                    if stage == "otp" {
                        otpInputView

                        HStack(spacing: 15) {
                            Button("Back") {
                                goBackToPhone()
                            }
                            .buttonStyle(.bordered)

                            Button(isLoading ? "Verifying..." : "Verify OTP") {
                                verifyOTP()
                            }
                        .buttonStyle(.borderedProminent)
                        .disabled(otp.isEmpty || isLoading)
                    }
                    .padding(.top, 8)
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
            .frame(minHeight: geo.size.height)
        }
        .background(Color(.systemGroupedBackground))
        }
    }
    
    // MARK: - Phone Input View
    
    var phoneInputView: some View {
        VStack(spacing: 20) {
            
            HStack(spacing: 12) {
                Menu {
                    ForEach(LoginView.countries) { country in
                        Button {
                            selectedCountry = country
                        } label: {
                            Label {
                                Text("\(country.code)  \(country.name)")
                            } icon: {
                                Text(country.flag)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedCountry.flag)
                            .font(.title3)
                        Text(selectedCountry.code)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .frame(width: 90)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 10)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }
                
                TextField("Phone number", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 12)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - OTP Input View
    
    var otpInputView: some View {
        VStack(spacing: 20) {
            Text("Enter verification code")
                .font(.headline)
                .foregroundColor(.secondary)
            
            TextField("", text: $otp)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .padding(.vertical, 16)
                .padding(.horizontal, 12)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        }
        .padding(.horizontal)
    }
    
    // MARK: - Computed Properties
    
    var fullPhoneNumber: String {
        selectedCountry.code + phoneNumber
    }
    
    func goBackToPhone() {
        stage = "phone"
        otp = ""
        errorMessage = nil
    }

    // MARK: - Apple Sign In

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                errorMessage = "Could not process Apple Sign In credentials."
                return
            }

            var nameStr: String?
            if let fullName = credential.fullName {
                let parts = [fullName.givenName, fullName.familyName].compactMap { $0 }
                if !parts.isEmpty { nameStr = parts.joined(separator: " ") }
            }

            authenticateWithApple(
                identityToken: identityToken,
                email: credential.email,
                fullName: nameStr
            )

        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
            errorMessage = "Apple Sign In failed. Please try again."
            print("❌ Apple Sign In error: \(error.localizedDescription)")
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
        if let email = email { body["email"] = email }
        if let fullName = fullName { body["full_name"] = fullName }

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    if (error as NSError).code == NSURLErrorNotConnectedToInternet {
                        errorMessage = "No internet connection. Please check your network."
                    } else if (error as NSError).code == NSURLErrorTimedOut {
                        errorMessage = "Request timed out. Please try again."
                    } else {
                        errorMessage = "Could not sign in. Please try again."
                    }
                    return
                }
                if let data = data,
                   let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let token = result["token"] as? String {
                    KeychainHelper.saveToken(token)
                    if let userId = result["user_id"] as? String {
                        UserDefaults.standard.set(userId, forKey: "userId")
                    }
                    UserDefaults.standard.removeObject(forKey: "userPhone")
                    isLoggedIn = true
                } else {
                    errorMessage = "Sign in failed. Please try again."
                }
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
        request.httpBody = try? JSONSerialization.data(
            withJSONObject: ["phone": fullPhoneNumber]
        )

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    if (error as NSError).code == NSURLErrorNotConnectedToInternet {
                        errorMessage = "No internet connection. Please check your network."
                    } else if (error as NSError).code == NSURLErrorTimedOut {
                        errorMessage = "Request timed out. Please try again."
                    } else {
                        errorMessage = "Could not send code. Please try again."
                    }
                    return
                }
                if let http = response as? HTTPURLResponse, http.statusCode == 429 {
                    errorMessage = "Too many requests. Please wait before trying again."
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
        let body = ["phone": fullPhoneNumber, "otp": otp]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    if (error as NSError).code == NSURLErrorNotConnectedToInternet {
                        errorMessage = "No internet connection. Please check your network."
                    } else if (error as NSError).code == NSURLErrorTimedOut {
                        errorMessage = "Request timed out. Please try again."
                    } else {
                        errorMessage = "Could not verify code. Please try again."
                    }
                    return
                }
                if let data = data,
                   let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let token = result["token"] as? String {
                    KeychainHelper.saveToken(token)
                    UserDefaults.standard.set(fullPhoneNumber, forKey: "userPhone")
                    Shared.defaults.set(fullPhoneNumber, forKey: Shared.phoneKey)
                    if let userId = result["user_id"] as? String {
                        UserDefaults.standard.set(userId, forKey: "userId")
                    }
                    isLoggedIn = true
                } else {
                    errorMessage = "Incorrect code. Please try again."
                    otp = ""
                }
            }
        }.resume()
    }
}

#Preview {
    LoginView()
}
