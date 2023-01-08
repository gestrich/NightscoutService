//
//  NSRemoteOverrideCancelPayload.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 12/24/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

struct NSRemoteOverrideCancelPayload: NSRemotePayloadV1, Codable {
    
    public let remoteAddress: String
    public let expiration: Date?
    public let sentAt: Date?
    
    
    //MARK: NSRemotePayload
    
    func toRemoteAction() -> RemoteAction {
        let action = RemoteOverrideCancelAction(remoteAddress: remoteAddress)
        return .cancelTemporaryOverride(action)
    }
    
    
    //MARK: Codable
    
    enum CodingKeys: String, CodingKey {
        case remoteAddress = "remote-address"
        case expiration = "expiration"
        case sentAt = "sent-at"
    }
    
    
    static func includedInNotification(_ notification: [String: Any]) -> Bool {
        return notification["cancel-temporary-override"] != nil
    }
}

extension NSRemoteOverrideCancelPayload {
    
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

