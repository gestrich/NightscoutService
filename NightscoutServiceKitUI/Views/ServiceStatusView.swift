//
//  ServiceStatus.swift
//  NightscoutServiceKitUI
//
//  Created by Pete Schwamb on 9/30/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKitUI
import NightscoutServiceKit

struct ServiceStatusView: View, HorizontalSizeClassOverride {
    @Environment(\.dismissAction) private var dismiss

    @ObservedObject var viewModel: ServiceStatusViewModel
    @ObservedObject var otpViewModel: OTPViewModel
    @State private var selectedItem: String?
    var body: some View {
        VStack {
            Text("Nightscout")
                .font(.largeTitle)
                .fontWeight(.semibold)
            Image(frameworkImage: "nightscout", decorative: true)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 150, height: 150)
            
            List {
                Section() {
                    HStack {
                        Text("URL")
                        Spacer()
                        Text(viewModel.urlString)
                    }
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(String(describing: viewModel.status))
                    }
                    NavigationLink(destination: OTPSelectionView(otpViewModel: otpViewModel), tag: "otp-view", selection: $selectedItem) {
                        HStack {
                            Text("One-Time Password")
                            Spacer()
                            Text(otpViewModel.otpCode)
                        }
                    }
                }
                Section("Remote Commands") {
                    ForEach(viewModel.remoteCommands, id: \.id){ command in
                        VStack(alignment: .leading) {
                            HStack {
                                Text(command.actionName)
                                Spacer()
                                Text(command.createdDateDescription)
                            }
                            Text(command.details)
                            Text(command.statusMessage)
                                .foregroundStyle(command.isError ? .red : .primary)
                            
                        }
                    }
                    Button("Remove History") {
                        viewModel.deleteNotificationHistory()
                    }
                }
            }
            
            Button(action: {
                viewModel.didLogout?()
            } ) {
                Text("Logout").padding(.top, 20)
            }
        }
        .navigationBarTitle("")
        .navigationBarItems(trailing: dismissButton)
    }
    
    private var dismissButton: some View {
        Button(action: dismiss) {
            Text("Done").bold()
        }
    }
}
