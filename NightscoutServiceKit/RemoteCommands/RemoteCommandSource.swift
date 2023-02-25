//
//  RemoteCommandSource.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 2/25/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import LoopKit

protocol RemoteCommandSource {
    func supportsPushNotification(_ notification: [String: AnyObject]) -> Bool
    func commandFromPushNotification(_ notification: [String: AnyObject]) async throws -> RemoteCommand
    func fetchRemoteCommands() async throws -> [RemoteCommand]
    func fetchPendingRemoteCommands() async throws -> [RemoteCommand]
    func updateRemoteCommandStatus(command: RemoteCommand, status: RemoteCommandStatus) async throws
}
