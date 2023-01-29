//
//  NSRemoteCommand.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 12/24/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

class NSRemoteCommand: RemoteCommand, CustomStringConvertible {
    
    //RemoteCommand
    let id: String
    let action: RemoteAction
    private(set) var status: RemoteCommandStatus
    private(set) var validators: [RemoteCommandValidation]
    
    private let commandSource: NSRemoteCommandSource
    
    init(id: String,
         action: RemoteAction,
         status: RemoteCommandStatus,
         validators: [RemoteCommandValidation],
         commandSource: NSRemoteCommandSource)
    {
        self.id = id
        self.action = action
        self.status = status
        self.validators = validators
        self.commandSource = commandSource
    }
    
    private func updateStatus(_ newStatus: RemoteCommandStatus) async throws {
        try await commandSource.updateRemoteCommandStatus(command: self, status: newStatus)
        status = newStatus
    }
    
    var description: String {
        //TODO: Add the status time.
        return action.description
    }
    
    
    //MARK: RemoteCommand
    
    public func checkValidity() throws {
        for validator in validators {
            try validator.checkValidity()
        }
    }
    
    public func markInProgress() async throws {
        try await updateStatus(RemoteCommandStatus(state: .InProgress, message: ""))
    }
    
    public func markError(_ error: Error) async throws {
        //TODO: This will truncate the NSError. See https://stackoverflow.com/questions/39176196/how-to-provide-a-localized-description-with-an-error-type-in-swift
        try await updateStatus(RemoteCommandStatus(state: .Error, message: error.localizedDescription))
    }
    
    public func markSuccess() async throws {
        try await updateStatus(RemoteCommandStatus(state: .Success, message: ""))
    }
}
