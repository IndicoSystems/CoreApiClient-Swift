//
//  File.swift
//  
//
//  Created by Константин Ланин on 09.06.2023.
//

import CoreData

public class Job: NSManagedObject, Codable {
    enum CodingKeys: CodingKey {
        case error,
             id,
             status,
             
             targetId,
             targetType,
             time,
             type
    }
    
    public required convenience init(from decoder: Decoder) throws {
        self.init(context: moc)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.error = try container.decodeIfPresent(String.self, forKey: .error)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.status = try container.decodeIfPresent(String.self, forKey: .status)
        
        self.targetId = try container.decodeIfPresent(String.self, forKey: .targetId)
        self.targetType = try container.decodeIfPresent(String.self, forKey: .targetId)
        self.time = try container.decodeIfPresent(Date.self, forKey: .time)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.error, forKey: .error)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.status, forKey: .status)
        
        try container.encode(self.targetId, forKey: .targetId)
        try container.encode(self.targetType, forKey: .targetType)
        try container.encode(self.time, forKey: .time)
        try container.encode(self.type, forKey: .type)
    }
}


public class TestEntity: NSManagedObject, Codable, Identifiable {
    enum CodingKeys: CodingKey {
        case name
    }
    
    public required convenience init(from decoder: Decoder) throws {
        self.init(context: moc)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.name, forKey: .name)
    }
}
