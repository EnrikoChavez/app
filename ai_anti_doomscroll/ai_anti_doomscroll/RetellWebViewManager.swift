//
//  RetellWebViewManager.swift
//  ai_anti_doomscroll
//

import Foundation
import WebKit
import SwiftUI

struct RetellWebView: UIViewRepresentable {
    let accessToken: String
    @ObservedObject var callManager: RetellCallManager
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        // Load Retell's Web SDK HTML
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script src="https://cdn.jsdelivr.net/npm/retell-client-js-sdk@latest/dist/index.js"></script>
        </head>
        <body>
            <div id="status">Initializing...</div>
            <script>
                const retellWebClient = new RetellWebClient.RetellWebClient();
                
                retellWebClient.on("conversation-started", () => {
                    window.webkit.messageHandlers.status.postMessage("Connected");
                });
                
                retellWebClient.on("conversation-ended", () => {
                    window.webkit.messageHandlers.status.postMessage("Ended");
                });
                
                retellWebClient.on("error", (error) => {
                    window.webkit.messageHandlers.status.postMessage("Error: " + error.message);
                });
                
                retellWebClient.on("update", (update) => {
                    if (update.transcript) {
                        window.webkit.messageHandlers.transcript.postMessage(update.transcript);
                    }
                });
                
                retellWebClient.startCall({
                    accessToken: "\(accessToken)",
                    sampleRate: 24000
                }).catch(err => {
                    window.webkit.messageHandlers.status.postMessage("Start Error: " + err.message);
                });
            </script>
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Add message handlers
        let contentController = webView.configuration.userContentController
        contentController.removeAllScriptMessageHandlers()
        contentController.add(context.coordinator, name: "status")
        contentController.add(context.coordinator, name: "transcript")
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(callManager: callManager)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let callManager: RetellCallManager
        
        init(callManager: RetellCallManager) {
            self.callManager = callManager
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "status" {
                if let status = message.body as? String {
                    DispatchQueue.main.async {
                        self.callManager.callStatus = status
                    }
                }
            } else if message.name == "transcript" {
                if let transcript = message.body as? String {
                    DispatchQueue.main.async {
                        self.callManager.transcript = transcript
                    }
                }
            }
        }
    }
}
