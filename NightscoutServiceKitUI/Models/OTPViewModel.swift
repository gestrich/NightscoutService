//
//  OTPViewModel.swift
//  NightscoutServiceKitUI
//
//  Created by Bill Gestrich on 5/2/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import NightscoutServiceKit
import LoopKit
import SwiftUI


class OTPViewModel: ObservableObject {
    
    @Published var otpCode: String = ""
    @Published var created: String = ""
    @Published var qrImage: Image?
    private var otpURL: String = "" {
        didSet {
            if oldValue != otpURL {
                qrImage = createQRImage(otpURL: otpURL)
            }
        }
    }
    
    private var timer: Timer? = nil
    private var otpManager: OTPManager

    init(otpManager: OTPManager) {
        self.otpManager = otpManager
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.refresh()
        }
        refresh()
    }
    
    func refresh() {
        self.otpCode = otpManager.otp()
        self.created = otpManager.created
        self.otpURL = otpManager.otpURL //Setter will update QR image
    }
    
    func resetSecretKey() {
        otpManager.resetSecretKey()
        refresh()
    }
    
    func createQRImage(otpURL: String) -> Image? {
        
        //Get data and apply CIFilter
        let data = otpURL.data(using: String.Encoding.ascii)
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
