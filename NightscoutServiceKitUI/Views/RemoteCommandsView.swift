//
//  RemoteCommandsView.swift
//  NightscoutServiceKitUI
//
//  Created by Bill Gestrich on 12/24/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit

struct RemoteCommandsView: View {
    
    @ObservedObject var viewModel: RemoteCommandsViewModel
    
    var body: some View {
        
        VStack(alignment: .center) {
            ForEach(viewModel.remoteCommands.map({$0.toViewModel()})) { command in
                HStack {
                    Text(command.title)
                    Text(command.detail)
                    Text(command.state)
                }
            }
        }.onAppear( perform: {
            Task {
                try await viewModel.updateCommands()
            }
        })
    }
}

extension RemoteCommand {
    func toViewModel() -> RemoteCommandViewModel {

        //TODO: Add creation date and delivery date when available
        let title: String
        let detail: String
        switch action {
        case .carbsEntry(let carbAction):
            title = "Carbs"
            detail = "\(carbAction.amountInGrams)g"
        case .bolusEntry(let bolusAction):
            title = "Bolus"
            detail = "\(bolusAction.amountInUnits)u"
        case .cancelTemporaryOverride:
            title = "Cancel Override"
            detail = ""
        case .temporaryScheduleOverride(let overrideAction):
            title = "Override"
            detail = "\(overrideAction.name)"
        case .closedLoop(let closedLoopAction):
            title = "Closed Loop"
            detail = closedLoopAction.active ? "Activate" : "Deactivate"
        case .autobolus(let autobolusAction):
            title = "Autobolus"
            detail = autobolusAction.active ? "Activate" : "Deactivate"
        }
        return RemoteCommandViewModel(title: title, detail: detail, state: status.state.rawValue)
    }
}
struct RemoteCommandViewModel: Identifiable {
    var id: UUID = UUID()
    let title: String
    let detail: String
    let state: String
}
