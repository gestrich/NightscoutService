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
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: ServiceStatusViewModel //Can OTP be part of this and update view dynamically when changes?
    
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
                Section {
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
                    NavigationLink(destination: OTPSelectionView()) {
                        HStack {
                            Text("One-Time Password")
                            Spacer()
                            Text(OTPManager().otp())
                        }
                    }
                }
            }
            
            Button(action: {
                viewModel.didLogout?()
            } ) {
                Text("Logout").padding(.top, 20)
            }
        }
        .padding([.leading, .trailing])
        .navigationBarTitle("")
        .navigationBarItems(trailing: dismissButton)
    }
    
    private var dismissButton: some View {
        Button(action: dismiss) {
            Text("Done").bold()
        }
    }
    
    private var refreshButton: some View {
        Button(action: /*@START_MENU_TOKEN@*/{}/*@END_MENU_TOKEN@*/, label: {
            Image(systemName: "arrow.clockwise")
        })
    }
    
    struct OTPView: UIViewControllerRepresentable {
        func makeUIViewController(context: UIViewControllerRepresentableContext<OTPView>) -> OTPSelectionViewController {
            OTPSelectionViewController(otpManager: OTPManager())
        }

        func updateUIViewController(_ uiViewController: OTPSelectionViewController, context: UIViewControllerRepresentableContext<OTPView>) {
            print("here")
        }
    }

}
