//
//  Settings.swift
//  
//
//  Created by Константин Ланин on 15.06.2023.
//

import Foundation


// MARK: - Server info

struct ServerInfo: Codable {
    let type: String?
    let loginMethods: [String]
    let settings: [String: String?]
    let version: ServerVersion?
}

struct ServerVersion: Codable {
    let major: Int
    let minor: Int
    
    func asString() -> String {
        String(format: "%03d.%03d", major, minor)
    }
}

public enum ExhibitType: String { case unknown = "application", photo = "image", video = "video", audio = "audio" }
let fileExtensions = [ExhibitType.photo: "jpeg", ExhibitType.video: videoFileExt, ExhibitType.audio: "mp4"]

public class Settings {
    public static let shared = Settings()
    
    static let stringToBoolMap = ["1": true, "0": false]
    
    public static func UDInt(_ name: String) -> Int { return UserDefaults.standard.integer(forKey: name) }
    public static func UDStr(_ name: String) -> String { return UserDefaults.standard.string(forKey: name) ?? "" }
    public static func UDBool(_ name: String) -> Bool { return UserDefaults.standard.bool(forKey: name) }
    
    public static func setUD(_ name: String, to: Any?) { UserDefaults.standard.set(to, forKey: name) }
    
    public static func setSettings(settings: [String: String?]) {
        settings.forEach { (key: String, value: String?) in
            if value != nil {
                setUD("settings.\(key)", to: value)
            }
        }
    }
    
    public static func setIfNotSet(current: String, show: String, defaultTo: String) {
        //if UserDefaults.standard.object(forKey: UserDefaultsKey.cellularUploadCurrent) == nil || !settings.cellularUploadShow {
        //    let valueToSet = UDStr(UserDefaultsKey.cellularUpload)
        //    setUD(UserDefaultsKey.cellularUploadCurrent, to: valueToSet)
        //}
        
        if !UDBool(current) || !UDBool(show) {
            setUD(UserDefaultsKey.cellularUploadCurrent, to: UDBool(defaultTo))
        }
    }
}
