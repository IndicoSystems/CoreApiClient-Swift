//
//  File.swift
//  
//
//  Created by Константин Ланин on 07.06.2023.
//

import CoreData

public class Task: Base, Codable {
    enum CodingKeys: CodingKey {
        case completed,
             description,
             entity,
             entityId,
             
             hidden,
             id,
             name,
             retention,
             
             template,
             templateId, //*
             title,
             titleTemplate,
             type
    }
    
    public var templateId: String?
    
    public required convenience init(from decoder: Decoder) throws {
        self.init(context: cdContext)
        
        try self.decodeBase(from: decoder)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.completed = try container.decode(Bool.self, forKey: .completed)
        self.description_ = try container.decodeIfPresent(String.self, forKey: .description)
        self.entity_ = try container.decodeIfPresent(String.self, forKey: .entity)
        self.entityId = try container.decodeIfPresent(String.self, forKey: .entityId)

        self.hidden = try container.decode(Bool.self, forKey: .hidden)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.retention = try container.decodeIfPresent(String.self, forKey: .retention)
        
        self.template = try container.decode(Bool.self, forKey: .template)
        self.templateId = try container.decodeIfPresent(String.self, forKey: .templateId)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.titleTemplate = try container.decodeIfPresent(String.self, forKey: .titleTemplate)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
    }
    
    public func encode(to encoder: Encoder) throws {
        try self.encodeBase(to: encoder)
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.completed, forKey: .completed)
        try container.encode(self.description_, forKey: .description)
        try container.encode(self.entity_, forKey: .entity)
        try container.encode(self.entityId, forKey: .entityId)
        
        try container.encode(self.hidden, forKey: .hidden)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.retention, forKey: .retention)
        
        try container.encode(self.template, forKey: .template)
        try container.encode(self.templateId, forKey: .templateId)
        try container.encode(self.title, forKey: .title)
        try container.encode(self.titleTemplate, forKey: .titleTemplate)
        try container.encode(self.type, forKey: .type)
    }
}
