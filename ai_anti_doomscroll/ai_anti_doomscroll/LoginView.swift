//
//  LoginView.swift
//  ai_anti_doomscroll
//
//  Created by Enriko Chavez on 8/17/25.
//

import SwiftUI

struct LoginView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @State private var phone = ""
    @State private var otp = ""
    @State private var stage = "phone" // "phone" or "otp"
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Sign in with Phone")
                .font(.largeTitle).bold()

            if stage == "phone" {
                TextField("Phone number", text: $phone)
                #if os(iOS)
                    .keyboardType(.phonePad)
                #endif
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button("Send OTP") {
                    sendOTP()
                }
                .buttonStyle(.borderedProminent)
            }

            if stage == "otp" {
                TextField("Enter OTP", text: $otp)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    #endif
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                HStack(spacing: 15) {
                    Button("Back") {
                        goBackToPhone()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Verify OTP") {
                        verifyOTP()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if let error = errorMessage {
                Text(error).foregroundColor(.red)
            }
        }
        .padding()
    }
    
    func goBackToPhone() {
        stage = "phone"
        otp = "" // Clear the OTP field
        errorMessage = nil // Clear any error messages
    }

    func sendOTP() {
        // build full URL using your baseURL property
        guard let url = APIConfig.url("/otp/send") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try? JSONSerialization.data(
            withJSONObject: ["phone": phone]
        )

        URLSession.shared.dataTask(with: request) { _, _, _ in
            DispatchQueue.main.async {
                stage = "otp"
                errorMessage = nil // Clear any previous errors
            }
        }.resume()
    }

    func verifyOTP() {
        guard let url = APIConfig.url("/otp/verify") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["phone": phone, "otp": otp]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data,
               let result = try? JSONDecoder().decode([String: String].self, from: data),
               let token = result["token"] {
                
                // ✅ Save token in Keychain (already done)
                KeychainHelper.saveToken(token)

                // ✅ Save phone number in UserDefaults
                UserDefaults.standard.set(phone, forKey: "userPhone")

                DispatchQueue.main.async {
                    isLoggedIn = true
                }
                // after saving Keychain token & setting isLoggedIn = true
                Shared.defaults.set(phone, forKey: Shared.phoneKey)
            } else {
                DispatchQueue.main.async {
                    errorMessage = "Invalid OTP"
                }
            }
        }.resume()
    }
}

#Preview {
    LoginView()
}
