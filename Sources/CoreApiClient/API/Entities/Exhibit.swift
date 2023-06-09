//
//  File.swift
//  
//
//  Created by Константин Ланин on 08.06.2023.
//

import CoreData

public class Exhibit: Base, Codable {
    enum CodingKeys: CodingKey {
        case clientChecksum,
             duration,
             fileName,
             fileSize,
             
             id,
             mediaType,
             startedAt,
             thumbnail,
             uploadKey
    }
    
    public required convenience init(from decoder: Decoder) throws {
        self.init(context: cdContext)
        
        try self.decodeBase(from: decoder)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.clientChecksum = try container.decodeIfPresent(String.self, forKey: .clientChecksum)
        self.duration = try container.decode(Int32.self, forKey: .duration)
        self.fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        self.fileSize = try container.decode(Int64.self, forKey: .fileSize)

        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.mediaType = try container.decodeIfPresent(String.self, forKey: .mediaType)
        self.startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        self.thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
        self.uploadKey = try container.decodeIfPresent(String.self, forKey: .uploadKey)
    }
    
    public func encode(to encoder: Encoder) throws {
        try self.encodeBase(to: encoder)
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.clientChecksum, forKey: .clientChecksum)
        try container.encode(self.duration, forKey: .duration)
        try container.encode(self.fileName, forKey: .fileName)
        try container.encode(self.fileSize, forKey: .fileSize)
        
        try container.encode(self.id, forKey: .id)
        try container.encode(self.mediaType, forKey: .mediaType)
        try container.encode(self.startedAt, forKey: .startedAt)
        try container.encode(self.thumbnail, forKey: .thumbnail)
        try container.encode(self.uploadKey, forKey: .uploadKey)
    }
}
