//
//  File.swift
//  
//
//  Created by Константин Ланин on 09.06.2023.
//

import CoreData

public class Access: NSManagedObject, Codable {
    public var you: Bool {
        get {
            return whoId == "current user ID"
        }
    }
    
    enum CodingKeys: CodingKey {
        case grantedAt,
             permission,
             what, // Is it the task relation?
             whoId,
             whoName
    }
    
    public required convenience init(from decoder: Decoder) throws {
        self.init(context: cdContext)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.grantedAt = try container.decodeIfPresent(Date.self, forKey: .grantedAt)
        self.permission = try container.decodeIfPresent(String.self, forKey: .permission)
        self.what = try container.decodeIfPresent(String.self, forKey: .what)
        self.whoId = try container.decodeIfPresent(String.self, forKey: .whoId)
        self.whoName = try container.decodeIfPresent(String.self, forKey: .whoName)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.grantedAt, forKey: .grantedAt)
        try container.encode(self.permission, forKey: .permission)
        try container.encode(self.what, forKey: .what)
        try container.encode(self.whoId, forKey: .whoId)
        try container.encode(self.whoName, forKey: .whoName)
    }
}
