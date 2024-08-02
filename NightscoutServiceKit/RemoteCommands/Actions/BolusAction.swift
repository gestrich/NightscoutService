//
//  BolusAction.swift
//  LoopKit
//
//  Created by Bill Gestrich on 12/25/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation

public struct BolusAction: Codable {
    
    public let amountInUnits: Double
    public let userCreatedDate: Date
    
    public init(amountInUnits: Double, userCreatedDate: Date) {
        self.amountInUnits = amountInUnits
        self.userCreatedDate = userCreatedDate
    }
}
