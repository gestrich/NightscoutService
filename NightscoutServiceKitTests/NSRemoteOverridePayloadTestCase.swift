//
//  NSRemoteOverridePayloadTestCase.swift
//  NightscoutServiceKitTests
//
//  Created by Bill Gestrich on 1/14/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
@testable import NightscoutServiceKit

class NSRemoteOverridePayloadTestCase: XCTestCase {
    
    override func setUpWithError() throws {
    }
    
    override func tearDownWithError() throws {
    }
    
    
    //MARK: Carb Entry Command

    func testParseCarbEntryNotification_ValidPayload_Succeeds() throws {
        
        //Arrange
        let expectedStartDateString = "2022-08-14T03:08:00.000Z"
        let expectedCarbsInGrams = 15.0
        let expectedStartDate = dateFormatter().date(from: expectedStartDateString)!
        let expectedSentAtDateString = "2022-08-14T02:08:00.000Z"
        let expectedSentAtDate = dateFormatter().date(from: expectedSentAtDateString)!
        let expectedAbsorptionTimeInHours = 3.0
        let otp = "12345"
        let notification: [String: Any] = [
            "carbs-entry":expectedCarbsInGrams,
            "absorption-time": expectedAbsorptionTimeInHours,
            "otp": otp,
            "start-time": expectedStartDateString,
            "sent-at": expectedSentAtDateString,
            "remote-address": "9876-5432"
        ]
        
        //Act
        let payload = try NSRemoteCarbPayload(dictionary: notification)
        
        //Assert
        XCTAssertEqual(payload.startDate, expectedStartDate)
        XCTAssertEqual(payload.sentAt, expectedSentAtDate)
        XCTAssertEqual(payload.absorptionInHours, expectedAbsorptionTimeInHours)
        XCTAssertEqual(payload.amount, expectedCarbsInGrams)
    }

    //MARK: Utils

    func dateFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions =  [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    
}

