//
//  File.swift
//  
//
//  Created by Константин Ланин on 07.06.2023.
//

import CoreData

enum TaskFieldType: String, Codable {
    case text, number, file, time, choice, layout, subtask
}

public class ChoiceOption: Codable {
    let title: String?
    let value: String
    var answer: Bool
}

public class TaskField: Base, Codable {
    
    private var featuresArr: [String]? = nil
    public var featuresArray: [String] {
        get {
            if featuresArr == nil {
                featuresArr = features?.split(separator: ",").map { String($0) } ?? []
            }
            
            return featuresArr ?? []
        }
        set(value) {
            features = value.joined(separator: ",")
            featuresArr = value
        }
    }
    
    private var optionsArr: [ChoiceOption]? = nil
    public var optionsArray: [ChoiceOption] {
        get {
            if optionsArr == nil {
                optionsArr = try? Coder.decode(options ?? "")
            }
            
            return optionsArr ?? []
        }
        set(value) {
            options = try? Coder.encode(value)
            optionsArr = value
        }
    }
    
    // MARK: - Coding
    
    enum CodingKeys: CodingKey {
        case answer,
             description,
             entityField,
             features,
             
             id,
             max,
             min,
             options,
             
             placeholder,
             required,
             sequence,
             title,
             type
    }

    public required convenience init(from decoder: Decoder) throws {
        self.init(context: cdContext)
        
        try self.decodeBase(from: decoder)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.answer = try container.decodeIfPresent(String.self, forKey: .answer)
        self.description_ = try container.decodeIfPresent(String.self, forKey: .description)
        self.entityField = try container.decodeIfPresent(String.self, forKey: .entityField)
        self.features = try container.decodeIfPresent(String.self, forKey: .features)
        
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.max = try container.decode(Double.self, forKey: .max)
        self.min = try container.decode(Double.self, forKey: .min)
        self.options = try container.decodeIfPresent(String.self, forKey: .options)
        
        self.placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder)
        self.required = try container.decode(Bool.self, forKey: .required)
        self.sequence = try container.decode(Int32.self, forKey: .sequence)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.type = try container.decodeIfPresent(TaskFieldType.self, forKey: .type)
    }

    public func encode(to encoder: Encoder) throws {
        try self.encodeBase(to: encoder)
        
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.answer, forKey: .answer)
        try container.encode(self.description_, forKey: .description)
        try container.encode(self.entityField, forKey: .entityField)
        try container.encode(self.features, forKey: .features)
        
        try container.encode(self.id, forKey: .id)
        try container.encode(self.max, forKey: .max)
        try container.encode(self.min, forKey: .min)
        try container.encode(self.options, forKey: .options)
        
        try container.encode(self.placeholder, forKey: .placeholder)
        try container.encode(self.required, forKey: .required)
        try container.encode(self.sequence, forKey: .sequence)
        try container.encode(self.title, forKey: .title)
        try container.encode(self.type, forKey: .type)
        
    }
}
