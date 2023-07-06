//
//  Account.swift
//  
//
//  Created by Константин Ланин on 09.06.2023.
//

import CoreData

public class Account: Base, Codable {
    enum CodingKeys: CodingKey {
        case accessToken,
             id,
             name,
             privileges,
             username
    }
    
    public var privilegesArray: [String] {
        get {
            return privileges?.split(separator: ",").map { String($0) } ?? []
        }
        set {
            privileges = newValue.joined(separator: ",")
        }
    }
    
    public required convenience init(from decoder: Decoder) throws {
        self.init(context: moc)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.privilegesArray = try container.decodeIfPresent([String].self, forKey: .privileges) ?? []
        self.username = try container.decodeIfPresent(String.self, forKey: .username)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.accessToken, forKey: .accessToken)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.privilegesArray, forKey: .privileges)
        try container.encode(self.username, forKey: .username)
    }
}
