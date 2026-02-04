//
//  LoginView.swift
//  ai_anti_doomscroll
//
//  Created by Enriko Chavez on 8/17/25.
//

import SwiftUI

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
    
    // Popular countries with their codes and flags (sorted reverse alphabetically)
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
        VStack(spacing: 30) {
            Text("sign in with phone")
                .font(.largeTitle).bold()
                .padding(.top, 40)

            if stage == "phone" {
                phoneInputView
                
                Button("Send OTP") {
                    sendOTP()
                }
                .buttonStyle(.borderedProminent)
                .disabled(phoneNumber.isEmpty)
                .padding(.top, 20)
            }

            if stage == "otp" {
                otpInputView
                
                HStack(spacing: 15) {
                    Button("Back") {
                        goBackToPhone()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Verify OTP") {
                        verifyOTP()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(otp.isEmpty)
                }
                .padding(.top, 20)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Phone Input View
    
    var phoneInputView: some View {
        VStack(spacing: 20) {
            
            HStack(spacing: 12) {
                // Country Code Picker
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
                
                // Phone Number (single field)
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
            withJSONObject: ["phone": fullPhoneNumber]
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
        let body = ["phone": fullPhoneNumber, "otp": otp]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data,
               let result = try? JSONDecoder().decode([String: String].self, from: data),
               let token = result["token"] {
                
                // ✅ Save token in Keychain (already done)
                KeychainHelper.saveToken(token)

                // ✅ Save phone number in UserDefaults
                UserDefaults.standard.set(fullPhoneNumber, forKey: "userPhone")

                DispatchQueue.main.async {
                    isLoggedIn = true
                }
                // after saving Keychain token & setting isLoggedIn = true
                Shared.defaults.set(fullPhoneNumber, forKey: Shared.phoneKey)
            } else {
                DispatchQueue.main.async {
                    errorMessage = "Invalid OTP"
                    // Clear OTP field on error
                    otp = ""
                }
            }
        }.resume()
    }
}

#Preview {
    LoginView()
}
