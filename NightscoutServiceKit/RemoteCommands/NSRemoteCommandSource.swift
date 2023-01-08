//
//  NSRemoteCommandSource.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 12/24/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

public protocol NSRemoteCommandSource {
    func supportsPushNotification(_ notification: [String: AnyObject]) -> Bool
    func commandFromPushNotification(_ notification: [String: AnyObject]) async throws -> RemoteCommand
    func fetchRemoteCommands() async throws -> [RemoteCommand]
    func fetchPendingRemoteCommands() async throws -> [RemoteCommand]
    func updateRemoteCommandStatus(command: RemoteCommand, status: RemoteCommandStatus) async throws
}
