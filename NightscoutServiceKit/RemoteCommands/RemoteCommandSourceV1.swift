//
//  RemoteCommandSourceV1.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 2/25/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

class RemoteCommandSourceV1: RemoteCommandSource {
    
    private let otpManager: OTPManager
    /*
     TODO: Keep an in-memory only store for the V1 remote notifications.
     This could become a Core Data store if we want to have parity with the
     V2 Views which will allow you to see command history in Loop. Or we can just
     not show the option for V1.
     */
    private var commandsAndStatus = [(command: NightscoutRemoteCommand, status: RemoteCommandStatus)]()
    private var nightscoutV2FormatVersion = 2.0
    
    init(otpManager: OTPManager) {
        self.otpManager = otpManager
    }
    
    private func updateCommandAndStatus(_ comamndAndStatus: (command: NightscoutRemoteCommand, status: RemoteCommandStatus)) throws {
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
    
    
    //MARK: RemoteCommandSource
    
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
        
        enum RemoteNotificationError: Error {
            case unhandledNotification
        }
        
        guard let remoteNotification = try notification.toRemoteNotification() else {
            throw RemoteNotificationError.unhandledNotification
        }
        
        let command = remoteNotification.toRemoteCommand(otpManager: otpManager, commandSource: self)
        commandsAndStatus.append((command, RemoteCommandStatus(state: .Pending, message: "")))
        return command
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
        
        guard let nsRemoteCommand = command as? NightscoutRemoteCommand else {
            throw NSRemoteCommandSourceV1Error.invalidCommandType
        }
        
        try updateCommandAndStatus((nsRemoteCommand, status))
    }
}
