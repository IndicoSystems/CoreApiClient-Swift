//
//  File.swift
//  
//
//  Created by Константин Ланин on 09.06.2023.
//

import CoreData

public enum LogAction: String {
    case capturePhoto = "capture_photo"
    case captureVideo = "capture_video"
    case captureAudio = "capture_audio"
    case captureFile = "capture_file"
    case upload, verify, delete, download
}

public enum LogCategory: String { case info, read, change, error }

public enum LogLevel: Int32 { case users_minor = 2, custody_major = 4, custody_minor = 5,
                                   tech_support = 7, tech_coder = 8, tech_debug = 9 }

public class Log: NSManagedObject, Codable, Identifiable {
    public var actionEnum: LogAction {
        get { return LogAction(rawValue: self.action ?? LogAction.capturePhoto.rawValue) ?? .capturePhoto }
        set { self.action = newValue.rawValue }
    }
    
    public var categoryEnum: LogCategory {
        get { return LogCategory(rawValue: self.category ?? LogCategory.info.rawValue) ?? .info }
        set { self.category = newValue.rawValue }
    }
    
    public var levelEnum: LogLevel {
        get { return LogLevel(rawValue: self.level) ?? .users_minor }
        set { self.level = newValue.rawValue }
    }
    
    enum CodingKeys: CodingKey {
        case action,
             actionId,
             category,
             details,
             id,
             
             initiator,
             inTarget, // inTargetId
             inTargetType,
             level,
             source,
             
             subaction,
             target, // targetId
             targetType,
             time
    }
    
    public required convenience init(from decoder: Decoder) throws {
        self.init(context: moc)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.action = try container.decodeIfPresent(String.self, forKey: .action)
        self.actionId = try container.decodeIfPresent(String.self, forKey: .actionId)
        self.category = try container.decodeIfPresent(String.self, forKey: .category)
        self.details = try container.decodeIfPresent(String.self, forKey: .details)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        
        self.initiator = try container.decodeIfPresent(String.self, forKey: .initiator)
        self.inTargetId = try container.decodeIfPresent(String.self, forKey: .inTarget)
        self.inTargetType = try container.decodeIfPresent(String.self, forKey: .inTargetType)
        self.level = try container.decode(Int32.self, forKey: .level)
        self.source = try container.decodeIfPresent(String.self, forKey: .source)
        
        self.subaction = try container.decodeIfPresent(String.self, forKey: .subaction)
        self.targetId = try container.decodeIfPresent(String.self, forKey: .target)
        self.targetType = try container.decodeIfPresent(String.self, forKey: .targetType)
        self.time = try container.decodeIfPresent(Date.self, forKey: .time)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.action, forKey: .action)
        try container.encode(self.actionId, forKey: .actionId)
        try container.encode(self.category, forKey: .category)
        try container.encode(self.details, forKey: .details)
        try container.encode(self.id, forKey: .id)
        
        try container.encode(self.initiator, forKey: .initiator)
        try container.encode(self.inTargetId, forKey: .inTarget)
        try container.encode(self.inTargetType, forKey: .inTargetType)
        try container.encode(self.level, forKey: .level)
        try container.encode(self.source, forKey: .source)
        
        try container.encode(self.subaction, forKey: .subaction)
        try container.encode(self.targetId, forKey: .target)
        try container.encode(self.targetType, forKey: .targetType)
        try container.encode(self.time, forKey: .time)
    }
}
