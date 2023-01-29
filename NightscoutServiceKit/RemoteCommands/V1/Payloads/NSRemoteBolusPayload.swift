//
//  NSRemoteBolusPayload.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 12/24/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

public struct NSRemoteBolusPayload: NSRemotePayloadV1, Codable {
    
    public let amount: Double
    public let remoteAddress: String
    public let expiration: Date?
    public let sentAt: Date?
    public let otp: String
    
    //MARK: NSRemotePayload
    
    func toRemoteAction() -> RemoteAction {
        return .bolusEntry(RemoteBolusAction(amountInUnits: amount))
    }
    
    
    //MARK: Codable
    
    enum CodingKeys: String, CodingKey {
        case remoteAddress = "remote-address"
        case amount = "bolus-entry"
        case expiration = "expiration"
        case sentAt = "sent-at"
        case otp = "otp"
    }
    
    
    static func includedInNotification(_ notification: [String: Any]) -> Bool {
        return notification["bolus-entry"] != nil
    }
}


extension NSRemoteBolusPayload {
    
    func toNSRemoteCommand(otpManager: OTPManager, commandSource: NSRemoteCommandSource) -> NSRemoteCommand {
        let expirationValidation = ExpirationValidator(expiration: expiration)
        let otpValidator = OTPValidator(sentAt: sentAt, otp: otp, otpManager: otpManager)
        return NSRemoteCommand(id: id,
                               action: toRemoteAction(),
                               status: RemoteCommandStatus(state: .Pending, message: ""),
                               validators: [expirationValidation, otpValidator],
                               commandSource: commandSource
        )
    }
}
