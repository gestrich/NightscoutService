//
//  NSRemoteOverridePayload.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 12/24/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

public struct NSRemoteOverridePayload: NSRemotePayloadV1, Codable {
    
    public let name: String
    public let durationInMinutes: Double?
    public let remoteAddress: String
    public let expiration: Date?
    public let sentAt: Date?
    
    func durationTime() -> TimeInterval? {
        guard let durationInMinutes = durationInMinutes else {
            return nil
        }
        return TimeInterval(minutes: durationInMinutes)
    }
    
    
    //MARK: NSRemotePayload
    
    func toRemoteAction() -> RemoteAction {
        
        //TODO: Remove this hack in V1 which supports updating a few
        //settings via hacked remote overrides
        if let setting = SULoopBoolSetting(remoteKey: name) {
            if setting.settingKey == "autoBolusEnabled" {
                return .autobolus(RemoteAutobolusAction(active: setting.settingValue))
            } else if setting.settingKey == "dosingEnabled" {
                return .closedLoop(RemoteClosedLoopAction(active: setting.settingValue))
            } else {
                assertionFailure("Unrecognized settings key \(setting.settingKey)")
            }
        }
        
        
        let action = RemoteOverrideAction(name: name, durationTime: durationTime(), remoteAddress: remoteAddress)
        return .temporaryScheduleOverride(action)
    }
    
    
    //MARK: Codable
    
    enum CodingKeys: String, CodingKey {
        case name = "override-name"
        case remoteAddress = "remote-address"
        case durationInMinutes = "override-duration-minutes"
        case expiration = "expiration"
        case sentAt = "sent-at"
    }
    
    
    static func includedInNotification(_ notification: [String: Any]) -> Bool {
        return notification["override-name"] != nil
    }
}

extension NSRemoteOverridePayload {
    
    func toNSRemoteCommand(otpManager: OTPManager, commandSource: NSRemoteCommandSource) -> NSRemoteCommand {
        let expirationValidation = ExpirationValidator(expiration: expiration)
        return NSRemoteCommand(id: id,
                               action: toRemoteAction(),
                               status: RemoteCommandStatus(state: .Pending, message: ""),
                               validators: [expirationValidation],
                               commandSource: commandSource
        )
    }
}

