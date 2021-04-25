//
//  OTPSelectionViewController.swift
//  Loop
//
//  Created by Jose Paredes on 3/26/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//
import Foundation
import UIKit
import NightscoutServiceKit

let ViewDismissTime: Double = 120
let AlertDismissTime = 10

class OTPSelectionViewController: UIViewController {

    var otpManager: OTPManager?
    
    //Subviews
    private var currentOTPLabelView: UILabel!
    private var createdLabelView: UILabel!
    private var qrCodeView: UIImageView!
    
    private var timer: Timer?
    private var dismissTimer: Timer?
    private var start: Double!

    init(otpManager: OTPManager) {
        self.otpManager = otpManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: String.Encoding.ascii)
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 6, y: 6)
            if let output = filter.outputImage?.transformed(by: transform) {
                return UIImage(ciImage: output)
            }
        }
        return nil
    }
    private func updateQRCode() {
        
        guard let otpManager = otpManager else {
            return
        }

        //QR View
        qrCodeView.image = generateQRCode(from: otpManager.otpURL)
        
        //Code Label View
        currentOTPLabelView!.text = "\(otpManager.otp())"
        
        //OTP Created Date View
        createdLabelView.text = "\(otpManager.created)"
        
        //let headerView = tableView.tableHeaderView!

    }
    override func viewDidLoad() {
        
        self.navigationItem.backButtonTitle = "Nightscout"
//        self.navigationItem.rightBarButtonItem =
//        UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refreshQR(_:)))

        self.title = "Secret Key"
        
        //Subviews
        addQRCodeLabel()
        addCurrentOPTLabelView()
        addCreatedLabelView()
        
        layoutViews()
        
        updateQRCode()

        //theView.backgroundColor = .secondarySystemBackground
        
        super.viewDidLoad()

    }
    
    private func addCurrentOPTLabelView() {
        currentOTPLabelView = UILabel(frame: CGRect(x: 0, y: 0, width: 0, height: 50))
        currentOTPLabelView!.text = "xxxxxx"
        currentOTPLabelView!.font = UIFont.boldSystemFont(ofSize: 24)
        currentOTPLabelView!.textAlignment = .center
        view.addSubview(currentOTPLabelView!)
    }
    
    private func addQRCodeLabel() {
        qrCodeView = UIImageView()
        qrCodeView!.contentMode = .scaleAspectFit
        view.addSubview(qrCodeView!)
    }
    
    private func addCreatedLabelView(){
        createdLabelView = UILabel(frame: CGRect(x: 0, y: 0, width: 0, height: 50))
        createdLabelView!.text = "xxxxxx"
        createdLabelView!.font = UIFont.boldSystemFont(ofSize: 24)
        createdLabelView!.textAlignment = .center
        view.addSubview(createdLabelView!)
    }
    
    private func layoutViews(){
        
        let labelVerticalSpace: CGFloat = 15.0
        currentOTPLabelView.translatesAutoresizingMaskIntoConstraints = false
        currentOTPLabelView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        currentOTPLabelView.bottomAnchor.constraint(equalTo: qrCodeView.topAnchor, constant: -labelVerticalSpace).isActive = true
        
        let qrCodeViewSideSpace: CGFloat = 15.0
        qrCodeView.translatesAutoresizingMaskIntoConstraints = false
        qrCodeView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: qrCodeViewSideSpace).isActive = true
        qrCodeView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        qrCodeView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -qrCodeViewSideSpace).isActive = true
        
        createdLabelView.translatesAutoresizingMaskIntoConstraints = false
        createdLabelView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        createdLabelView.topAnchor.constraint(equalTo: qrCodeView.bottomAnchor, constant: labelVerticalSpace).isActive = true
    }
    
    @objc private func refreshQR(_ sender: UIBarButtonItem) {
        let refreshAlert = UIAlertController(title: "Refresh Secret Key", message: "This action will invalidate the current key. Are you sure you want to refresh? ", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default ) {_ in
            self.otpManager!.refreshOTPToken()
            self.updateQRCode()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .default ) {_ in
        }

        refreshAlert.addAction(okAction)
        refreshAlert.addAction(cancelAction)

        // disable views dismiss timer
        self.dismissTimer?.invalidate()

        // show alert
        present(refreshAlert, animated: true, completion: nil)

        // dismiss after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + DispatchTimeInterval.seconds(AlertDismissTime) ) {
           refreshAlert.dismiss(animated: true, completion: nil)

           // restart view's dismiss timer for what remains of the 120 seconds
           let now = Double(DispatchTime.now().uptimeNanoseconds)/1000000000
           let remaining = ViewDismissTime - (now - self.start)

           // invalidate previous view dismiss timer
           self.dismissTimer?.invalidate()

           // set new view dismiss timer
           self.dismissTimer = Timer.scheduledTimer(timeInterval: remaining, target: self, selector: #selector(self.dismissView), userInfo:nil, repeats: false )

        }
    }
    @objc private func dismissView(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    override func viewDidAppear(_ animated: Bool) {
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
           // current otp
           let otp = self.otpManager!.otp()
           self.currentOTPLabelView!.text = "\(otp)"
        }

        // allow this view to be displayed for only 120 seconds
        self.dismissTimer = Timer.scheduledTimer(timeInterval: ViewDismissTime, target: self, selector: #selector(dismissView), userInfo:nil, repeats: false )

        // keep tract of view view appearing
        self.start = Double(DispatchTime.now().uptimeNanoseconds) / 1000000000

        super.viewDidAppear(animated)
    }
    override func viewWillDisappear(_ animated: Bool) {
        timer?.invalidate()
        dismissTimer?.invalidate()
        super.viewWillDisappear(animated)
    }
}
