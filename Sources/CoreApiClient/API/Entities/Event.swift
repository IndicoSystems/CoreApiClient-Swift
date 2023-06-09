//
//  Event.swift
//  
//
//  Created by Константин Ланин on 09.06.2023.
//

import CoreData

public class Event: Base, Codable {
    
    public var entityData: [String: String?]? {
        get {
            return .init()
        }
    }
    
    enum CodingKeys: CodingKey {
        case confidence,
             entity,
             entityId,
             fromTime,
             eventId, // id
             
             language,
             source,
             subtype,
             text,
             toTime,
             type
    }
    
    public required convenience init(from decoder: Decoder) throws {
        self.init(context: cdContext)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.confidence = try container.decode(Double.self, forKey: .confidence)
        self.entity_ = try container.decodeIfPresent(String.self, forKey: .entity)
        self.entityId = try container.decodeIfPresent(String.self, forKey: .entityId)
        self.fromTime = try container.decode(Double.self, forKey: .fromTime)
        self.id = try container.decodeIfPresent(String.self, forKey: .eventId)
        
        self.language = try container.decodeIfPresent(String.self, forKey: .language)
        self.source = try container.decodeIfPresent(String.self, forKey: .source)
        self.subtype = try container.decodeIfPresent(String.self, forKey: .subtype)
        self.text = try container.decodeIfPresent(String.self, forKey: .text)
        self.toTime = try container.decode(Double.self, forKey: .toTime)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.confidence, forKey: .confidence)
        try container.encode(self.entity_, forKey: .entity)
        try container.encode(self.entityId, forKey: .entityId)
        try container.encode(self.fromTime, forKey: .fromTime)
        try container.encode(self.id, forKey: .eventId)
        
        try container.encode(self.language, forKey: .language)
        try container.encode(self.source, forKey: .source)
        try container.encode(self.subtype, forKey: .subtype)
        try container.encode(self.text, forKey: .text)
        try container.encode(self.toTime, forKey: .toTime)
        try container.encode(self.type, forKey: .type)
    }
}
