//
//  RemoteCommandSourceV2.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 12/24/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import NightscoutKit

class RemoteCommandSourceV2: RemoteCommandSource {
    
    private let otpManager: OTPManager
    private let nightscoutClient: NightscoutClient
    private var minimumNSCommandFormatVersion = 2.0
    
    private enum RemoteCommandSourceV2Error: LocalizedError {
        case unhandledNotication
        case missingCommand
        
        var errorDescription: String? {
            switch self {
            case .unhandledNotication:
                return "Could not find handler for notification."
            case .missingCommand:
                return "Could not find command"
            }
        }
    }
    
    init(otpManager: OTPManager, nightscoutClient: NightscoutClient) {
        self.otpManager = otpManager
        self.nightscoutClient = nightscoutClient
    }
    
    private var resultsLookbackInterval: DateInterval {
        let maxLookbackTime = TimeInterval(hours: 24)
        return DateInterval(start: Date().addingTimeInterval(-maxLookbackTime), duration: maxLookbackTime)
    }
    
    
    //MARK: NSRemoteCommandSource
    
    func supportsPushNotification(_ notification: [String: AnyObject]) -> Bool {
        guard let versionString = notification["version"] as? String else {
            return false
        }
        
        guard let version = Double(versionString) else {
            return false
        }
        
        return version >= minimumNSCommandFormatVersion
    }
    
    func commandFromPushNotification(_ notification: [String: AnyObject]) async throws -> RemoteCommand {
        let payload = try payloadFromPushNotification(notification: notification)
        let notificationCommand = try payload.toNSRemoteCommand(commandSource: self, otpManager: otpManager)
        let pendingCommands = try await fetchPendingRemoteCommands()
        guard let pendingCommand = pendingCommands.first(where: {$0.id == notificationCommand.id}) else {
            throw RemoteCommandSourceV2Error.missingCommand
        }
        
        return pendingCommand
    }
    
    func payloadFromPushNotification(notification: [String: AnyObject]) throws -> NSRemoteCommandPayload {
        return try NSRemoteCommandPayload(dictionary: notification)
    }
    
    public func fetchRemoteCommands() async throws -> [RemoteCommand] {
        let payloads = try await nightscoutClient.fetchRemoteCommands(earliestDate: resultsLookbackInterval.start)
        var results = [NightscoutRemoteCommand]()
        for payload in payloads {
            let command = try payload.toNSRemoteCommand(commandSource: self, otpManager: otpManager)
            results.append(command)
        }
        
        return results
    }
    
    public func fetchPendingRemoteCommands() async throws -> [RemoteCommand] {
        let payloads = try await nightscoutClient.fetchPendingRemoteCommands(earliestDate: resultsLookbackInterval.start)
        var results = [NightscoutRemoteCommand]()
        for payload in payloads {
            print(payload)
            let command = try payload.toNSRemoteCommand(commandSource: self, otpManager: otpManager)
            results.append(command)
        }
        
        return results
    }
    
    public func updateRemoteCommandStatus(command: RemoteCommand, status: RemoteCommandStatus) async throws {
        let commandUpdate = NSRemoteCommandPayloadUpdate(status: status.toNSRemoteCommandStatus())
        let _ = try await nightscoutClient.updateRemoteCommand(commandUpdate: commandUpdate, commandID: command.id)
    }

}
