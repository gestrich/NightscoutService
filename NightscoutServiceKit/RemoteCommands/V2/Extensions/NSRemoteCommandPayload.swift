//
//  NSRemoteCommandPayload.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 12/27/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation
import NightscoutKit
import LoopKit

extension NSRemoteCommandPayload {
    
    func toRemoteAction() -> Action {
        switch action {
        case .bolus(let amountInUnits):
            return .bolusEntry(BolusAction(amountInUnits: amountInUnits))
        case .carbs(let amountInGrams, let absorptionTime, let startDate):
            return .carbsEntry(CarbAction(amountInGrams: amountInGrams, absorptionTime: absorptionTime, startDate: startDate))
        case .override(let name, let durationTime, let remoteAddress):
            return .temporaryScheduleOverride(OverrideAction(name: name, durationTime: durationTime, remoteAddress: remoteAddress))
        case .cancelOverride(let remoteAddress):
            return .cancelTemporaryOverride(OverrideCancelAction(remoteAddress: remoteAddress))
        case .autobolus(let active):
            return .autobolus(AutobolusAction(active: active))
        case .closedLoop(let active):
            return .closedLoop(ClosedLoopAction(active: active))
        }
    }
    
    func validate(otpManager: OTPManager) throws {
        let otpValidator = OTPValidator(sentAt: createdDate, otp: otp, otpManager: otpManager)
        try otpValidator.validate()
    }
}

enum RemoteCommandPayloadError: LocalizedError {
    case missingID
    
    var errorDescription: String? {
        switch self {
        case .missingID:
            return String(format: NSLocalizedString("Missing ID", comment: "Remote command error message when command identifier is missing."))
        }
    }
}
