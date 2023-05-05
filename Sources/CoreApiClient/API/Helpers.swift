//
//  File.swift
//  
//
//  Created by Константин Ланин on 05.05.2023.
//

import Foundation

typealias Translation = [String: String]

func UDInt(_ name: String) -> Int { return UserDefaults.standard.integer(forKey: name) }
func UDStr(_ name: String) -> String { return UserDefaults.standard.string(forKey: name) ?? "" }
func UDBool(_ name: String) -> Bool { return UserDefaults.standard.bool(forKey: name) }

func toByteArray<T>(_ value: T) -> [UInt8] {
    var value = value
    return withUnsafeBytes(of: &value) { Array($0).reversed() }
}

let sampleRate = 44100
var videoFileExt = "mp4"

let fileMgr = FileManager.default
