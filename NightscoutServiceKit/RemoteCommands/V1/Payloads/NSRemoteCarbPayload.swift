//
//  NSRemoteCarbPayload.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 12/24/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

public struct NSRemoteCarbPayload: NSRemotePayloadV1, Codable {
    
    public let amount: Double
    public let absorptionInHours: Double?
    public let foodType: String? //TODO: Requires a NS change that is not pushed to my repo yet
    public let startDate: Date?
    public let remoteAddress: String
    public let expiration: Date?
    public let sentAt: Date?
    public let otp: String
    
    func absorptionTime() -> TimeInterval? {
        guard let absorptionInHours = absorptionInHours else {
            return nil
        }
        return TimeInterval(hours: absorptionInHours)
    }
    
    //MARK: NSRemotePayload
    
    func toRemoteAction() -> RemoteAction {
        let action = RemoteCarbAction(amountInGrams: amount, absorptionTime: absorptionTime(), foodType: foodType, startDate: startDate)
        return .carbsEntry(action)
    }
    
    
    //MARK: Codable
    
    enum CodingKeys: String, CodingKey {
        case remoteAddress = "remote-address"
        case amount = "carbs-entry"
        case absorptionInHours = "absorption-time"
        case foodType = "food-type"
        case startDate = "start-time"
        case expiration = "expiration"
        case sentAt = "sent-at"
        case otp = "otp"
    }
   
    static func includedInNotification(_ notification: [String: Any]) -> Bool {
        return notification["carbs-entry"] != nil
    }

}


extension NSRemoteCarbPayload {
    
    func toNSRemoteCommand(otpManager: OTPManager, commandSource: NSRemoteCommandSource) -> NSRemoteCommand {
        let otpValidator = OTPValidator(sentAt: sentAt, otp: otp, otpManager: otpManager)
        let expirationValidation = ExpirationValidator(expiration: expiration)
        return NSRemoteCommand(id: id,
                               action: toRemoteAction(),
                               status: RemoteCommandStatus(state: .Pending, message: ""),
                               validators: [expirationValidation, otpValidator],
                               commandSource: commandSource
        )
    }
}
