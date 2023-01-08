//
//  NSRemotePayloadV1.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 12/25/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

protocol NSRemotePayloadV1: Codable {
    
    var id: String {get}
    var expiration: Date? {get}
    var sentAt: Date? {get}
    var remoteAddress: String {get}
    
    func toRemoteAction() -> RemoteAction
    func toNSRemoteCommand(otpManager: OTPManager, commandSource: NSRemoteCommandSource) -> NSRemoteCommand
    static func includedInNotification(_ notification: [String: Any]) -> Bool
}

extension NSRemotePayloadV1 {
    
    public var id: String {
        //There is no unique identifier so we use the sent date when possible
        if let sentAt = sentAt {
            return "\(sentAt.timeIntervalSince1970)"
        } else {
            return UUID().uuidString
        }
    }
    
    init(dictionary: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: dictionary)
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601DateDecoder)
        self = try jsonDecoder.decode(Self.self, from: data) //TODO: Not sure about Self.self
    }
}

extension DateFormatter {
    static var iso8601DateDecoder: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ" //Ex: 2022-12-24T21:34:02.090Z
        return formatter
    }()
}
