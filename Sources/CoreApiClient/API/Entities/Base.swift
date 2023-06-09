//
//  File.swift
//  
//
//  Created by Константин Ланин on 07.06.2023.
//

import CoreData

extension Base {
    enum CodingKeys: CodingKey {
            case createdAt,
                 discarded,
                 indexed,
                 updatedAt,
                 verified
        }
    
    func decodeBase(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        self.discarded = try container.decode(Bool.self, forKey: .discarded)
        self.indexed = try container.decode(Bool.self, forKey: .indexed)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        self.verified = try container.decode(Bool.self, forKey: .verified)
    }
    
    func encodeBase(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(discarded, forKey: .discarded)
        try container.encode(indexed, forKey: .indexed)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(verified, forKey: .verified)
    }
}

//public class Base: NSManagedObject, Codable {
//    enum CodingKeys: CodingKey {
//        case createdAt,
//             discarded,
//             indexed,
//             updatedAt,
//             verified
//    }
//
//    public required convenience init(from decoder: Decoder) throws {
//        self.init(context: cdContext)
//
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//
//        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
//        self.discarded = try container.decode(Bool.self, forKey: .discarded)
//        self.indexed = try container.decode(Bool.self, forKey: .indexed)
//        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
//        self.verified = try container.decode(Bool.self, forKey: .verified)
//    }
//
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//
//        try container.encode(createdAt, forKey: .createdAt)
//        try container.encode(discarded, forKey: .discarded)
//        try container.encode(indexed, forKey: .indexed)
//        try container.encode(updatedAt, forKey: .updatedAt)
//        try container.encode(verified, forKey: .verified)
//    }
//}
