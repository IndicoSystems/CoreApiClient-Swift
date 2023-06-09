//
//  File.swift
//  
//
//  Created by Константин Ланин on 08.06.2023.
//

import Foundation

public class Coder {
    public static let shared = Coder()
    
    private lazy var jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .ft4
        return decoder
    }()

    private lazy var jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .ft4
        return encoder
    }()
    
    
    // MARK: - decode optional
    public static func decodeOpt<T: Codable>(_ data: Data, printResult: Bool = false) -> T? {
        var result: T? = nil
        
        do {
            result = try shared.jsonDecoder.decode(T.self, from: data)
            
            if printResult { print(result!) }
        } catch let DecodingError.dataCorrupted(context) {
            print("🛑", context)
        } catch let DecodingError.keyNotFound(key, context) {
            print("🛑", "Key '\(key)' not found:", context.debugDescription)
            print("⚠️", "codingPath:", context.codingPath)
        } catch let DecodingError.valueNotFound(value, context) {
            print("🛑", "Value '\(value)' not found:", context.debugDescription)
            print("⚠️", "codingPath:", context.codingPath)
        } catch let DecodingError.typeMismatch(type, context)  {
            print("🛑", "Type '\(type)' mismatch:", context.debugDescription)
            print("⚠️", "codingPath:", context.codingPath)
        } catch {
            print("🛑", "error: ", error)
        }
        
        return result
    }
    
    // MARK: - decode
    public static func decode<T: Codable>(_ data: Data, printResult: Bool = false) throws -> T {
        do {
            let result: T = try shared.jsonDecoder.decode(T.self, from: data)
            
            if printResult { print(result) }
            
            return result
        } catch let DecodingError.dataCorrupted(context) {
            print("🛑", context)
            throw DecodingError.dataCorrupted(context)
        } catch let DecodingError.keyNotFound(key, context) {
            print("🛑", "Key '\(key)' not found:", context.debugDescription)
            print("⚡️", "codingPath:", context.codingPath)
            throw DecodingError.keyNotFound(key, context)
        } catch let DecodingError.valueNotFound(value, context) {
            print("🛑", "Value '\(value)' not found:", context.debugDescription)
            print("⚡️", "codingPath:", context.codingPath)
            throw DecodingError.valueNotFound(value, context)
        } catch let DecodingError.typeMismatch(type, context)  {
            print("🛑", "Type '\(type)' mismatch:", context.debugDescription)
            print("⚡️", "codingPath:", context.codingPath)
            throw DecodingError.typeMismatch(type, context)
        } catch {
            print("🛑", "error: ", error)
            throw error
        }
    }
    
    public static func decode<T: Codable>(_ str: String, printResult: Bool = false) throws -> T {
        return try decode(Data(), printResult: printResult)
    }
    
    // MARK: - encode
    public static func encode<T: Codable>(_ data: T, printResult: Bool = false) throws -> String? {
        let data: Data = try encode(data)
        let str = String(data: data, encoding: .utf8)
        
        if printResult {
            print("request input: " + (str ?? "nil"))
        }
        
        return str
    }
    public static func encode<T: Codable>(_ data: T) throws -> Data {
        return try shared.jsonEncoder.encode(data)
    }
}
