//
//  NightscoutRemoteCommand.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 2/25/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

class NightscoutRemoteCommand: RemoteCommand {
    
    //RemoteCommand
    let id: String
    let action: Action
    private(set) var status: RemoteCommandStatus
    private let validators: [RemoteCommandValidation]
    
    private let commandSource: RemoteCommandSource
    
    init(id: String,
         action: Action,
         status: RemoteCommandStatus,
         validators: [RemoteCommandValidation],
         commandSource: RemoteCommandSource)
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
    
    func validate() throws {
        for validator in validators {
            try validator.validate()
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
