//
//  File.swift
//  
//
//  Created by Константин Ланин on 05.05.2023.
//

import Foundation
import UIKit

typealias Translation = [String: String]

enum ConnectionType {
    case none
    case cellular
    case wifi
    case wiredEthernet
}

var connectionType = ConnectionType.none

func console(_ t: Any?) {
    print(t ?? "null")
}

func UDInt(_ name: String) -> Int { return UserDefaults.standard.integer(forKey: name) }
func UDStr(_ name: String) -> String { return UserDefaults.standard.string(forKey: name) ?? "" }
func UDBool(_ name: String) -> Bool { return UserDefaults.standard.bool(forKey: name) }

func setUD(_ name: String, to: Any?) { UserDefaults.standard.set(to, forKey: name) }

var currentLanguage:String = "en"

func formatDate(_ date: Date, dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
    let dF = DateFormatter()
    dF.dateStyle = dateStyle
    dF.timeStyle = timeStyle
    let l = Locale.preferredLanguages[0].starts(with: "\(currentLanguage)-") ? Locale.preferredLanguages[0] : currentLanguage
    dF.locale = Locale(identifier: l)
    return dF.string(from: date)
}

func toByteArray<T>(_ value: T) -> [UInt8] {
    var value = value
    return withUnsafeBytes(of: &value) { Array($0).reversed() }
}

let sampleRate = 44100
var videoFileExt = "mp4"

let fileMgr = FileManager.default

let homeURL = fileMgr.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("files")
let cacheURL = fileMgr.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("files")
var freeSpace: Int { return Int((try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?.volumeAvailableCapacityForImportantUsage ?? 0) }
#warning("Cannot find 'Settings' in scope")
//var safeSpace: Int { return max(0,freeSpace - Settings.shared.minimumFreeMB) }

func getTranslation(dict: Translation?) -> String {
    guard let dict=dict else { return "" }

    let current = dict[Locale.preferredLanguages[0].components(separatedBy: "-")[0]] ?? ""
    return current != "" ? current : dict.first(where: { $1 != "" })?.value ?? ""
}

func getDeviceModel() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    let identifier = machineMirror.children.reduce("") { identifier, element in
        guard let value = element.value as? Int8, value != 0 else { return identifier }
        return identifier + String(UnicodeScalar(UInt8(value)))
    }
    
    if let url = Bundle.main.url(forResource: "DeviceList", withExtension: "plist"),
       let data = try? Data(contentsOf: url),
       let dictionary = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String:String],
       let device = dictionary[identifier] {
        return device
    }
    
    return UIDevice.current.model
    
}


func getDeviceInfo() -> String {
    var space:Int64 = 0
    do {
        let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
        space = (systemAttributes[.systemSize] as? NSNumber)?.int64Value ?? 0
    } catch { }
    
    let deviceName = "\(Int(ceil(Double(space)/1_000_000_000))) GB, iOS \(ProcessInfo.processInfo.operatingSystemVersionString.replacingOccurrences(of: "Version ", with: "").replacingOccurrences(of: "Build ", with: ""))"
    
    return deviceName
}
