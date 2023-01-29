//
//  RemoteCommandsViewModel.swift
//  NightscoutServiceKitUI
//
//  Created by Bill Gestrich on 12/24/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation
import Combine
import LoopKit
import RileyLinkKit

class RemoteCommandsViewModel: ObservableObject {
    
    weak var delegate: RemoteCommandsViewModelDelegate?
    @Published var remoteCommands: [RemoteCommand] = []
    
    init(delegate: RemoteCommandsViewModelDelegate){
        self.delegate = delegate
        Task {
            try await updateCommands()
        }
    }
    
    @MainActor func updateCommands() async throws {
        guard let delegate else {return}
        remoteCommands = try await delegate.fetchRemoteCommands()
    }

}

protocol RemoteCommandsViewModelDelegate: AnyObject {
    func fetchRemoteCommands() async throws -> [RemoteCommand]
}
