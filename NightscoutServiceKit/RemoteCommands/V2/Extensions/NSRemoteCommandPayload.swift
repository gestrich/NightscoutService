//
//  NSRemotePayloadV2.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 12/27/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation
import NightscoutKit
import LoopKit

extension NSRemoteCommandPayload {
    
    func toNSRemoteCommand(commandSource: RemoteCommandSourceV2, otpManager: OTPManager) throws -> NightscoutRemoteCommand {
        
        guard let id = _id else {
            throw RemoteCommandPayloadError.missingID
        }
        
        let otpValidator = OTPValidator(sentAt: nil, otp: otp, otpManager: otpManager)
        return NightscoutRemoteCommand(id: id,
                               action: toRemoteAction(),
                               status: status.toStatus(),
                               validators: [otpValidator],
                               commandSource: commandSource)
    }
    
    public func toRemoteAction() -> Action {
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
}

extension NSRemoteCommandStatus {
    func toStatus() -> RemoteCommandStatus {
        return RemoteCommandStatus(state: state.toState(), message: message)
    }
}

extension NSRemoteCommandStatus.NSRemoteComandState {
    func toState() -> RemoteCommandStatus.RemoteComandState {
        switch self {
        case .Pending:
            return RemoteCommandStatus.RemoteComandState.Pending
        case .InProgress:
            return RemoteCommandStatus.RemoteComandState.InProgress
        case .Success:
            return RemoteCommandStatus.RemoteComandState.Success
        case .Error:
            return RemoteCommandStatus.RemoteComandState.Error
        }
    }
}

enum RemoteCommandPayloadError: LocalizedError {
    case missingID
    
    var errorDescription: String? {
        switch self {
        case .missingID:
            return "Missing ID"
        }
    }
}
