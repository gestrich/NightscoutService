//
//  OverideRemoteNotification.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 2/25/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import NightscoutUploadKit
import LoopKit

extension OverrideRemoteNotification {
    
    func toRemoteCommand(otpManager: OTPManager, commandSource: RemoteCommandSource) -> NightscoutRemoteCommand {
        let expirationValidator = ExpirationValidator(expiration: expiration)
        return NightscoutRemoteCommand(id: id,
                                       action: toRemoteAction(),
                                       validators: [expirationValidator],
                                       commandSource: commandSource
        )
    }
    
    func toRemoteAction() -> Action {
        let action = OverrideAction(name: name, durationTime: durationTime(), remoteAddress: remoteAddress)
        return .temporaryScheduleOverride(action)
    }
}
