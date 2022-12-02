//
//  OTPManagerTestCase.swift
//  NightscoutServiceKitTests
//
//  Created by Bill Gestrich on 8/13/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import NightscoutServiceKit
@testable import OneTimePassword

class OTPManagerTestCase: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testGetLastPasswords_ProvidesLatestOTPs() throws {
        
        //Arrange
        let sequenceData = getTestSequence()
        let mockStore = MockSecretStore(testSequence: sequenceData)
        let manager = OTPManager(secretStore: mockStore, nowDateSource: {sequenceData.endDate})
        
        //Act
        let lastPasswords = manager.getLastPasswordsAscending(count: sequenceData.otpAscendingPasswords.count)
        
        //Assert
        let expectedLatestPasswords = sequenceData.otpAscendingPasswords
        XCTAssertEqual(lastPasswords, expectedLatestPasswords)
    }
    
    func testCurrentPassword_ProvidesCurrentOTP() throws {
        
        //Arrange
        let sequenceData = getTestSequence()
        let mockStore = MockSecretStore(testSequence: sequenceData)
        let manager = OTPManager(secretStore: mockStore, nowDateSource: {sequenceData.endDate})
        
        //Act
        let currentPassword = sequenceData.otpAscendingPasswords.last!
        
        //Assert
        let expectedCurrentPassword = manager.currentPassword()!
        XCTAssertEqual(currentPassword, expectedCurrentPassword)
    }

    func testValidateOTP_WhenOldestAcceptedPasswordUsed_Succeeds() throws {
        
        //Arrange
        let maxOTPsToAccept = 2
        let sequenceData = getTestSequence(count: maxOTPsToAccept)
        let mockStore = MockSecretStore(testSequence: sequenceData)
        let manager = OTPManager(secretStore: mockStore, nowDateSource: {sequenceData.endDate}, maxOTPsToAccept: maxOTPsToAccept)
        let oldestPassword = sequenceData.otpAscendingPasswords.first!
        
        //Act + Assert
        XCTAssertNoThrow(try manager.validateOTP(otpToValidate: oldestPassword))
    }
    
    func testValidateOTP_WhenExpiredPasswordUsed_Throws() throws {
        
        //Arrange
        let maxOTPsToAccept = 2
        let sequenceData = getTestSequence(count: maxOTPsToAccept + 1) // Request 1 more than we accept so we get an expired one to test
        let mockStore = MockSecretStore(testSequence: sequenceData)
        let manager = OTPManager(secretStore:  mockStore, nowDateSource: {sequenceData.endDate})
        let expiredPassword = sequenceData.otpAscendingPasswords.first!
        
        //Act + Assert
        XCTAssertThrowsError(try manager.validateOTP(otpToValidate: expiredPassword))
    }
    
    func testValidateOTP_WhenPasswordReused_Throws() throws {
        
        //Arrange
        let sequenceData = getTestSequence()
        let mockStore = MockSecretStore(testSequence: sequenceData)
        let mockDateSource = MockDateSource()
        let manager = OTPManager(secretStore: mockStore, nowDateSource: {mockDateSource.currentDate})
        let password = sequenceData.otpAscendingPasswords.last!
        mockDateSource.currentDate = sequenceData.endDate
        try manager.validateOTP(otpToValidate: password)
        
        //Act + Assert
        XCTAssertThrowsError(try manager.validateOTP(otpToValidate: password))
    }
    
    func testValidateOTP_WhenOTPInsertionFails_Throws() throws {
        
        //Arrange
        let sequenceData = getTestSequence()
        let mockStore = MockSecretStore(testSequence: sequenceData)
        mockStore.simulateFailedPasswordInsertion = true
        let manager = OTPManager(secretStore: mockStore, nowDateSource: {sequenceData.endDate})
        let password = sequenceData.otpAscendingPasswords.last!
        
        //Act + Assert
        XCTAssertThrowsError(try manager.validateOTP(otpToValidate: password))
    }
    
    func getTestSequence(count: Int? = nil) -> OTPTestSequence {
        
        /*
         To get sequence of OTP codes from an independent source for these tests:
         
         1. Go to https://cryptotools.net/otp
         2. Paste the test secretKey below to site
         3. Capture the Epoch time from site
         4. Capture 4 consecutive codes
         5. Update the startDate below
         6. Update otps below
         
         */
        
        let startDate = Date(timeIntervalSince1970: 1670001615)
        var otps = ["306469", "649742", "881201", "086432"]
        
        if let count = count {
            otps = Array(otps[0..<count])
        }
        
        return OTPTestSequence(secretKey: "2IOF4MG5QSAKMIYD6QJKOBZFH2QV2CYG", tokenName: "Test Key", startDate: startDate, otpAscendingPasswords: otps)
    }
}

struct OTPTestSequence {
    let secretKey: String
    let tokenName: String
    let startDate: Date
    var endDate: Date { startDate.addingTimeInterval(TimeInterval(otpAscendingPasswords.count - 1) * OTPManager.defaultTokenPeriod)}
    let otpAscendingPasswords: [String]
}

class MockSecretStore: OTPSecretStore {

    var secretKey: String?
    var keyName: String?
    var recentlyAcceptedPasswords = [String]()
    var simulateFailedPasswordInsertion: Bool = false
    
    init(secretKey: String?, keyCreated: String?){
        self.secretKey = secretKey
        self.keyName = keyCreated
    }
    
    convenience init(testSequence: OTPTestSequence){
        self.init(secretKey: testSequence.secretKey, keyCreated: testSequence.tokenName)
    }
    
    func setTokenSecretKey(_ key: String?) throws {
        secretKey = key
    }
    
    func tokenSecretKey() -> String? {
        return secretKey
    }
    
    func tokenSecretKeyName() -> String? {
        return keyName
    }
    
    func setTokenSecretKeyName(_ name: String?) throws {
        keyName = name
    }
    
    func recentAcceptedPasswords() -> [String] {
        return recentlyAcceptedPasswords
    }
    
    func setRecentAcceptedPasswords(_ passwords: [String]) throws {
        if self.simulateFailedPasswordInsertion {
            throw MockSecretStoreError.passwordInsertion
        }
        self.recentlyAcceptedPasswords = passwords
    }
    
    enum MockSecretStoreError: Error {
        case passwordInsertion
    }
}

class MockDateSource {
    
    var currentDate: Date
    
    init(currentDate: Date = Date()){
        self.currentDate = currentDate
    }
}
