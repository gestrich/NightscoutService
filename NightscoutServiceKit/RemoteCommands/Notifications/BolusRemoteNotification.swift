//
//  BolusRemoteNotification.swift
//  NightscoutUploadKit
//
//  Created by Bill Gestrich on 2/25/23.
//  Copyright © 2023 Pete Schwamb. All rights reserved.
//

import Foundation
import LoopKit

public struct BolusRemoteNotification: RemoteNotification, Codable {
    
    public let amount: Double
    public let remoteAddress: String
    public let expiration: Date?
    public let sentAt: Date?
    public let otp: String
    
    enum CodingKeys: String, CodingKey {
        case remoteAddress = "remote-address"
        case amount = "bolus-entry"
        case expiration = "expiration"
        case sentAt = "sent-at"
        case otp = "otp"
    }
    
    func toRemoteCommand(otpManager: OTPManager, commandSource: RemoteCommandSource) -> NightscoutRemoteCommand {
        let expirationValidator = ExpirationValidator(expiration: expiration)
        let otpValidator = OTPValidator(sentAt: sentAt, otp: otp, otpManager: otpManager)
        return NightscoutRemoteCommand(id: id,
                                       action: toRemoteAction(),
                                       status: RemoteCommandStatus(state: .Pending, message: ""),
                                       validators: [expirationValidator, otpValidator],
                                       commandSource: commandSource
        )
    }
    
    func toRemoteAction() -> Action {
        return .bolusEntry(BolusAction(amountInUnits: amount))
    }
    
    public static func includedInNotification(_ notification: [String: Any]) -> Bool {
        return notification["bolus-entry"] != nil
    }
}
