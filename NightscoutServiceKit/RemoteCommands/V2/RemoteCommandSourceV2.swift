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
import os.log

actor RemoteCommandSourceV2: RemoteCommandSource {
    
    private let log = OSLog(category: "Remote Command Source V2")
    private weak var delegate: RemoteCommandSourceV2Delegate?
    private let otpManager: OTPManager
    
    init(otpManager: OTPManager) {
        self.otpManager = otpManager
    }
    
    func setDelegate(_ delegate: RemoteCommandSourceV2Delegate) async {
        self.delegate = delegate
    }
    
    
    //MARK: RemoteCommandSource
    
    func remoteNotificationWasReceived(_ notification: [String: AnyObject]) async {
        
        do {
            let command = try await fetchCommandFromPushNotification(notification)
            try await handleCommand(command)
            log.default("Remote Notification: Finished handling %{public}@", String(describing: notification))
        } catch {
            log.error("Remote Notification: %{public}@. Error: %{public}@", String(describing: notification), String(describing: error))
        }
    }
    
    func loopDidComplete() async throws {
        
        //TODO: What if NS instance does not support V2 Commands?
        //We proably need to periodically fetch the NS Remote API version
        //and store it to disk
        
        for command in try await fetchPendingRemoteCommands() {
            do { //Nested try/catch is so we can still continue processing commands when a single one fails.
                switch command.action {
                case .bolus, .carbs:
                    //TODO: Not supporting the processing of remote bolus or carbs yet.
                    //Activate this with more testing.
                    continue
                default:
                    try await handleCommand(command)
                }
            } catch {
                self.log.error("Error handling pending command: %{public}@", String(describing: error))
            }
        }
    }
    

    
    func fetchCommandFromPushNotification(_ notification: [String: AnyObject]) async throws -> NSRemoteCommandPayload {
        let payload = try NSRemoteCommandPayload(dictionary: notification)
        let pendingCommands = try await fetchPendingRemoteCommands()
        guard let pendingCommand = pendingCommands.first(where: {$0._id == payload._id}) else {
            throw RemoteCommandSourceV2Error.missingCommand
        }
        
        return pendingCommand
    }
    
    public func fetchRemoteCommands() async throws -> [NSRemoteCommandPayload] {
        guard let delegate = delegate else { throw RemoteCommandSourceV2Error.missingDelegate }
        return try await delegate.commandSourceV2(self, fetchCommandsWithStartDate: resultsLookbackInterval.start)
    }
    
    public func fetchPendingRemoteCommands() async throws -> [NSRemoteCommandPayload] {
        guard let delegate = delegate else {throw RemoteCommandSourceV2Error.missingDelegate}
        return try await delegate.commandSourceV2(self, fetchPendingCommandsWithStartDate: resultsLookbackInterval.start)
    }
    
    public func updateNSRemoteCommandStatus(command: NSRemoteCommandPayload, status: NSRemoteCommandStatus) async throws {
        guard let delegate = delegate else {throw RemoteCommandSourceV2Error.missingDelegate}
        try await delegate.commandSourceV2(self, updateCommand: command, status: status)
    }
    
    func handleCommand(_ command: NSRemoteCommandPayload) async throws {
        do {
            guard let delegate = delegate else { throw RemoteCommandSourceV2Error.missingDelegate }
            guard try !commandWasPreviouslyQueued(command: command) else {
                throw RemoteCommandSourceV2Error.unexpectedDuplicateCommand
            }
            
            try markCommandAsQueued(command: command)
            try command.validate(otpManager: otpManager)
            try await updateNSRemoteCommandStatus(command: command, status: NSRemoteCommandStatus(state: .InProgress, message: ""))
            
            try await delegate.commandSourceV2(self, handleAction: command.toRemoteAction())
            try await updateNSRemoteCommandStatus(command: command, status: NSRemoteCommandStatus(state: .Success, message: ""))
        } catch {
            //TODO: This will truncate the NSError. See https://stackoverflow.com/questions/39176196/how-to-provide-a-localized-description-with-an-error-type-in-swift
            try await updateNSRemoteCommandStatus(command: command, status: NSRemoteCommandStatus(state: .Error, message: error.localizedDescription))
            throw error
        }
    }
    
    private var resultsLookbackInterval: DateInterval {
        let maxLookbackTime = TimeInterval(hours: 24)
        return DateInterval(start: Date().addingTimeInterval(-maxLookbackTime), duration: maxLookbackTime)
    }
    
    
    //MARK: Remote Command Persistence
    
    private func commandWasPreviouslyQueued(command: NSRemoteCommandPayload) throws -> Bool {
        return try handledCommandIDs().contains(where: {$0 == command._id})
    }
    
    private func markCommandAsQueued(command: NSRemoteCommandPayload) throws {
        var allCommandIds = try handledCommandIDs()
        guard let id = command._id else { throw RemoteCommandPayloadError.missingID }
        allCommandIds.append(id)
        let jsonData = try JSONEncoder().encode(allCommandIds)
        try jsonData.write(to: commandIDFileURL())
        guard try handledCommandIDs().last == command._id else {
            throw RemoteCommandSourceV2Error.failedCommandIDPersistenceSave
        }
    }
    
    private func handledCommandIDs() throws -> [String] {
        if !FileManager.default.fileExists(atPath: commandIDFileURL().path) {
            return []
        }
        let jsonData = try Data(contentsOf: commandIDFileURL())
        return try JSONDecoder().decode([String].self, from: jsonData)
    }
    
    private func commandIDFileURL() -> URL {
        let docsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        return URL(fileURLWithPath: docsPath).appendingPathComponent("handledRemoteCommandIDs.json")
    }
    
    
    private enum RemoteCommandSourceV2Error: LocalizedError {
        case missingDelegate
        case missingCommand
        case missingCommandID
        case failedCommandIDPersistenceSave
        case unexpectedDuplicateCommand
        
        
        //TODO: localize
        var errorDescription: String? {
            switch self {
            case .missingDelegate:
                return "Could not find delegate"
            case .missingCommand:
                return "Could not find command"
            case .failedCommandIDPersistenceSave:
                return "Could not persist command"
            case .missingCommandID:
                return "Missing command ID"
            case .unexpectedDuplicateCommand:
                return "Unexpected duplicate command"
            }
        }
    }
}

protocol RemoteCommandSourceV2Delegate: AnyObject {
    func commandSourceV2(_: RemoteCommandSourceV2, fetchCommandsWithStartDate startDate: Date) async throws -> [NSRemoteCommandPayload]
    func commandSourceV2(_: RemoteCommandSourceV2, fetchPendingCommandsWithStartDate startDate: Date) async throws -> [NSRemoteCommandPayload]
    func commandSourceV2(_: RemoteCommandSourceV2, updateCommand command: NSRemoteCommandPayload, status: NSRemoteCommandStatus) async throws
    func commandSourceV2(_: RemoteCommandSourceV2, handleAction action: Action) async throws
}

    
