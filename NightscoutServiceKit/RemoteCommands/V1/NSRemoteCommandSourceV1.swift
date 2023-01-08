//
//  NSRemoteCommandSourceV1.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 12/24/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

class NSRemoteCommandSourceV1: NSRemoteCommandSource {
    
    private let otpManager: OTPManager
    /*
     TODO: Keep an in-memory only store for the V1 remote notifications.
     This could become a Core Data store if we want to have parity with the
     V2 Views which will allow you to see command history in Loop. Or we can just
     not show the option for V1.
     */
    private var commandsAndStatus = [(command: NSRemoteCommand, status: RemoteCommandStatus)]()
    private var nightscoutV2FormatVersion = 2.0
    
    init(otpManager: OTPManager) {
        self.otpManager = otpManager
    }
    
    private func updateCommandAndStatus(_ comamndAndStatus: (command: NSRemoteCommand, status: RemoteCommandStatus)) throws {
        guard let index = commandsAndStatus.firstIndex(where: {$0.command.id == comamndAndStatus.command.id}) else {
            throw NSRemoteCommandSourceV1Error.invalidCommandType
        }
        commandsAndStatus.replaceSubrange(index...index, with: [comamndAndStatus])
    }
    
    private func allCommands() -> [RemoteCommand] {
        return commandsAndStatus.map({$0.command})
    }
    
    private func commandFromID(_ id: String) -> RemoteCommand? {
        return allCommands().first(where: {$0.id == id})
    }
    
    private enum NSRemoteCommandSourceV1Error: LocalizedError {
        case unhandledNotification(_ notification: [String: Any])
        case invalidCommandType
        
        var errorDescription: String? {
            switch self {
            case .unhandledNotification(let notification):
                return "Unhandled notification: \(notification)"
            case .invalidCommandType:
                return "Invalid Command Type"
            }
        }
    }

    
    //MARK: NSRemoteCommandSource
    
    func supportsPushNotification(_ notification: [String: AnyObject]) -> Bool {
        guard let versionString = notification["version"] as? String else {
            return true //Backwards support before version was added
        }
        
        guard let version = Double(versionString) else {
            assertionFailure("Unexpected version \(versionString)")
            return false
        }
        
        return version < nightscoutV2FormatVersion
    }
    
    func commandFromPushNotification(_ notification: [String: AnyObject]) async throws -> RemoteCommand {
        let payload = try payloadFromPushNotification(notification: notification)
        let command = payload.toNSRemoteCommand(otpManager: otpManager, commandSource: self)
        commandsAndStatus.append((command, RemoteCommandStatus(state: .Pending, message: "")))
        return command
    }
    
    func payloadFromPushNotification(notification: [String: AnyObject]) throws -> NSRemotePayloadV1 {
        if NSRemoteOverridePayload.includedInNotification(notification) {
            return try NSRemoteOverridePayload(dictionary: notification)
        } else if NSRemoteOverrideCancelPayload.includedInNotification(notification) {
            return try NSRemoteOverrideCancelPayload(dictionary: notification)
        }  else if NSRemoteBolusPayload.includedInNotification(notification) {
            return try NSRemoteBolusPayload(dictionary: notification)
        } else if NSRemoteCarbPayload.includedInNotification(notification) {
            return try NSRemoteCarbPayload(dictionary: notification)
        } else {
            throw NSRemoteCommandSourceV1Error.unhandledNotification(notification)
        }
    }
    
    func fetchRemoteCommands() async throws -> [RemoteCommand] {
        return allCommands()
    }
    
    func fetchPendingRemoteCommands() async throws -> [RemoteCommand] {
        return commandsAndStatus
            .filter({$0.status.state == RemoteCommandStatus.RemoteComandState.Pending})
            .map({$0.command})
    }
    
    func updateRemoteCommandStatus(command: RemoteCommand, status: RemoteCommandStatus) async throws {
        
        guard let nsRemoteCommand = command as? NSRemoteCommand else {
            throw NSRemoteCommandSourceV1Error.invalidCommandType
        }
        
        try updateCommandAndStatus((nsRemoteCommand, status))
    }

}
