//
//  ExpirationValidator.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 12/27/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

struct ExpirationValidator: RemoteCommandValidation {
    
    let expiration: Date?
    let nowDateSource: () -> Date = {Date()}
    
    enum NotificationValidationError: LocalizedError {
        
        case expiredNotification

        var errorDescription: String? {
            switch  self {
            case .expiredNotification:
                //TODO: Add description in Error on when the command expired.
                return NSLocalizedString("Expired", comment: "Remote command error description: expired.")
            }
        }
    }
    
    func checkValidity() throws {
        
        guard let expirationDate = expiration else {
            return //Skip validation if no date included
        }
        
        if nowDateSource() > expirationDate {
            throw NotificationValidationError.expiredNotification
        }
    }
    
}
