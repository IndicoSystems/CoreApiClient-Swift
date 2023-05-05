//
//  File.swift
//  
//
//  Created by Константин Ланин on 05.05.2023.
//

import Foundation

extension Formatter {
    static let ft4TimeWithFractionalSeconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SZ"
        return formatter
    }()
    
    static let ft4Time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter
    }()
}

extension JSONDecoder.DateDecodingStrategy {
    static let ft4 = custom {
        let container = try $0.singleValueContainer()
        let string = try container.decode(String.self)
        if let date = Formatter.ft4TimeWithFractionalSeconds.date(from: string) ?? Formatter.ft4Time.date(from: string) {
            return date
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
    }
}

extension JSONEncoder.DateEncodingStrategy {
    static let ft4 = custom {
        var container = $1.singleValueContainer()
        try container.encode(Formatter.ft4TimeWithFractionalSeconds.string(from: $0))
    }
}

extension Date {
    var ft4TimeStamp: String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        return formatter.string(from: self)
    }
}
