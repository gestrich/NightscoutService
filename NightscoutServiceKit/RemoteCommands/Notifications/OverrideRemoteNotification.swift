//
//  OverrideRemoteNotification.swift
//  NightscoutUploadKit
//
//  Created by Bill Gestrich on 2/25/23.
//  Copyright © 2023 Pete Schwamb. All rights reserved.
//

import Foundation
import LoopKit

public struct OverrideRemoteNotification: RemoteNotification, Codable {
    
    public let name: String
    public let durationInMinutes: Double?
    public let remoteAddress: String
    public let expiration: Date?
    public let sentAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case name = "override-name"
        case remoteAddress = "remote-address"
        case durationInMinutes = "override-duration-minutes"
        case expiration = "expiration"
        case sentAt = "sent-at"
    }
    
    public func durationTime() -> TimeInterval? {
        guard let durationInMinutes = durationInMinutes else {
            return nil
        }
        return TimeInterval(minutes: durationInMinutes)
    }
    
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
    
    public static func includedInNotification(_ notification: [String: Any]) -> Bool {
        return notification["override-name"] != nil
    }
}
