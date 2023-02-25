//
//  RemoteCommandSourceV1.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 2/25/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import NightscoutUploadKit

class RemoteCommandSourceV1: RemoteCommandSource {
    
    private let otpManager: OTPManager
    
    init(otpManager: OTPManager) {
        self.otpManager = otpManager
    }
    
    
    //MARK: RemoteCommandSource
    
    func supportsPushNotification(_ notification: [String: AnyObject]) -> Bool {
        guard let versionString = notification["version"] as? String else {
            return true //Backwards support before version was added
        }
        
        guard let version = Double(versionString) else {
            return false
        }
        
        return version < 2.0
    }
    
    func commandFromPushNotification(_ notification: [String: AnyObject]) async throws -> RemoteCommand {
        
        enum NSRemoteCommandSourceV1Error: Error {
            case unhandledNotification
        }
        
        if BolusRemoteNotification.includedInNotification(notification) {
            let bolusNotification = try BolusRemoteNotification(dictionary: notification)
            return bolusNotification.toRemoteCommand(otpManager: otpManager, commandSource: self)
        } else if CarbRemoteNotification.includedInNotification(notification) {
            let carbNotification = try CarbRemoteNotification(dictionary: notification)
            return carbNotification.toRemoteCommand(otpManager: otpManager, commandSource: self)
        }  else if OverrideRemoteNotification.includedInNotification(notification) {
            let overrideNotification = try OverrideRemoteNotification(dictionary: notification)
            return overrideNotification.toRemoteCommand(otpManager: otpManager, commandSource: self)
        } else if OverrideCancelRemoteNotification.includedInNotification(notification) {
            let overrideCancelNotification = try OverrideCancelRemoteNotification(dictionary: notification)
            return overrideCancelNotification.toRemoteCommand(otpManager: otpManager, commandSource: self)
        } else {
            throw NSRemoteCommandSourceV1Error.unhandledNotification
        }
    }
}
