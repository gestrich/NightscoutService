//
//  CarbRemoteNotification.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 2/25/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import NightscoutUploadKit
import LoopKit

extension CarbRemoteNotification {
    
    func toRemoteCommand(otpManager: OTPManager, commandSource: RemoteCommandSource) -> NightscoutRemoteCommand {
        let expirationValidator = ExpirationValidator(expiration: expiration)
        let otpValidator = OTPValidator(sentAt: sentAt, otp: otp, otpManager: otpManager)
        return NightscoutRemoteCommand(id: id,
                                       action: toRemoteAction(),
                                       validators: [expirationValidator, otpValidator],
                                       commandSource: commandSource
        )
    }
    
    func toRemoteAction() -> Action {
        let action = CarbAction(amountInGrams: amount, absorptionTime: absorptionTime(), foodType: foodType, startDate: startDate)
        return .carbsEntry(action)
    }
}
