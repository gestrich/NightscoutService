//
//  SULoopBoolSetting.swift
//  
//
//  Created by Bill Gestrich on 10/16/21.
//

import Foundation

public struct SULoopBoolSetting: Equatable {
    
    public let settingKey: String
    public let settingValue: Bool
    
    public init(settingKey: String, settingValue: Bool){
        self.settingKey = settingKey
        self.settingValue = settingValue
    }
    
    public static func == (lhs: SULoopBoolSetting, rhs: SULoopBoolSetting) -> Bool {
        return lhs.settingKey == rhs.settingKey && lhs.settingValue == rhs.settingValue
    }
}

public extension SULoopBoolSetting {

    init?(remoteKey: String) {
        //"Setting:keyName:true"
        let parts = remoteKey.split(separator: ":")
        
        guard parts.count == 3 else {
            return nil
        }
        
        guard parts[0] == "Setting" else {
            return nil
        }
    
        self.settingKey = String(parts[1])
        
        guard let settingValue = Bool(String(parts[2])) else {
            return nil
        }
        
        self.settingValue = settingValue
        
    }
    
    func remoteKey() -> String {
        return ["Setting", self.settingKey, (settingValue ? "true" : "false")].joined(separator: ":")
    }
}

