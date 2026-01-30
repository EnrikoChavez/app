//
//  ShieldActionExtension.swift
//  ShieldActionExtension
//

import ManagedSettings
import Foundation

class ShieldActionExtension: ShieldActionDelegate {
    
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        
        switch action {
        case .primaryButtonPressed:
            // Standard behavior: Close the blocked app
            completionHandler(.close)
        case .secondaryButtonPressed:
            // Standard behavior: Do nothing (keeps the shield up)
            completionHandler(.none)
        @unknown default:
            completionHandler(.none)
        }
    }
}
