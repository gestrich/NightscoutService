//
//  OTPValidator.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 12/27/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import LoopKit

struct OTPValidator: RemoteCommandValidation {
    
    let sentAt: Date?
    let otp: String?
    let otpManager: OTPManager
    let nowDateSource: () -> Date = {Date()}
    
    enum NotificationValidationError: LocalizedError {
        case missingOTP
        
        var errorDescription: String? {
            switch  self {
            case .missingOTP:
                return NSLocalizedString("Missing OTP", comment: "Remote command error description: Missing OTP.")
            }
        }
    }
    
    func checkValidity() throws {
        
        guard let otp = otp else {
            throw NotificationValidationError.missingOTP
        }
        
        try otpManager.validatePassword(password: otp, deliveryDate: sentAt)
    }
    
}
