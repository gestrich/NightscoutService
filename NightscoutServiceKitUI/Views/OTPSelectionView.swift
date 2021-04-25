//
//  OTPSelectionViewControllerSwiftUI.swift
//  NightscoutServiceKitUI
//
//  Created by Bill Gestrich on 4/11/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import SwiftUI
import NightscoutServiceKit

struct OTPSelectionView: View {
    var otpManager = OTPManager()
    @State private var image: Image?
    @State private var otpCode: String = ""
    @State private var otpCodeDate: String = ""
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack {
            Text(otpCode).bold()
            image?
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(.all)
            Text(otpCodeDate).bold()
        }
        .onAppear() {
            loadImage()
        }.navigationBarItems(trailing: refreshButton)
        .onReceive(timer, perform: { input in
            otpCode = otpManager.otp()
            otpCodeDate = otpManager.created
        })
    }
    
    func loadImage() {
        image = OTPSelectionView.generateQRCode(from: OTPManager().otpURL)!
    }
    
    private var refreshButton: some View {
        Button(action: /*@START_MENU_TOKEN@*/{}/*@END_MENU_TOKEN@*/, label: {
            Image(systemName: "arrow.clockwise")
        })
    }
    
    static func generateQRCode(from string: String) -> Image? {
        
        //Get data and apply CIFilter
        let data = string.data(using: String.Encoding.ascii)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            assert(false, "Could not create CIFilter")
            return nil
        }
        filter.setValue(data, forKey: "inputMessage")
        let transform = CGAffineTransform(scaleX: 6, y: 6)
        guard let output = filter.outputImage?.transformed(by: transform) else {
            assert(false, "Could not transform with CIFilter")
            return nil
        }
        
        //Convert to CGImage
        let context = CIContext()
        guard let cgimg = context.createCGImage(output, from: output.extent) else {
            assert(false, "Could not create CGImage")
            return nil
        }
        
        //Convert to UIImage
        let uiImage = UIImage(cgImage: cgimg)
        
        //Convert to Swift Image
        return Image(uiImage: uiImage)
        
    }
}

struct OTPSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        OTPSelectionView()
    }
}
