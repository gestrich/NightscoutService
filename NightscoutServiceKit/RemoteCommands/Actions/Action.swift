//
//  Action.swift
//  LoopKit
//
//  Created by Bill Gestrich on 12/25/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation

public enum Action: Codable {
    case temporaryScheduleOverride(OverrideAction)
    case cancelTemporaryOverride(OverrideCancelAction)
    case bolusEntry(BolusAction)
    case carbsEntry(CarbAction)
    case closedLoop(ClosedLoopAction)
    case autobolus(AutobolusAction)
    
    public var description: String {
        return "\(actionName) \(actionParameterDescription)"
    }
    
    var actionName: String {
        switch self {
        case .carbsEntry:
            return LocalizedString("Carb Entry", comment: "The remote action name for Carb Entry")
        case .bolusEntry:
            return LocalizedString("Bolus Entry", comment: "The remote action name for Bolus Entry")
        case .cancelTemporaryOverride:
            return LocalizedString("Cancel Override", comment: "The remote action name for Cancel Override")
        case .temporaryScheduleOverride:
            return LocalizedString("Override", comment: "The remote action name for Override")
        case .closedLoop:
            return LocalizedString("Closed Loop Update", comment: "The remote action name for activating/deactivating closed loop")
        case .autobolus:
            return LocalizedString("Autobolus Update", comment: "The remote action name for activating/deactivating autobolus")
        }
    }
    
    var actionParameterDescription: String {
        switch self {
        case .carbsEntry(let carbAction):
            let amountFormatted = Self.numberFormatter.string(from: carbAction.amountInGrams as NSNumber) ?? ""
            return "\(amountFormatted)" + " " + carbGramAbbreviation
        case .bolusEntry(let bolusAction):
            let amountFormatted = Self.numberFormatter.string(from: bolusAction.amountInUnits as NSNumber) ?? ""
            return "\(amountFormatted)" + " " + bolusUnitAbbreviation
        case .cancelTemporaryOverride:
            return ""
        case .temporaryScheduleOverride(let overrideAction):
            return overrideAction.name
        case .autobolus(let autobolusAction):
            return autobolusAction.active ? remoteCommandActiveStateName : remoteCommandInactiveStateName
        case .closedLoop(let closedLoopAction):
            return closedLoopAction.active ? remoteCommandActiveStateName : remoteCommandInactiveStateName
        }
    }
    
    private var remoteCommandActiveStateName: String {
        return LocalizedString("Active", comment: "Remote command status when is Active")
    }
    
    private var remoteCommandInactiveStateName: String {
        return LocalizedString("Inactive", comment: "Remote command status when is Inactive")
    }
    
    var carbGramAbbreviation: String {
        LocalizedString("g", comment: "The remote action abbreviation for gram units")
    }
    
    var bolusUnitAbbreviation: String {
        LocalizedString("U", comment: "The remote action abbreviation for bolus units")
    }
    
    static var numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}
