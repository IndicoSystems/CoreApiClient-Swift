//
//  File.swift
//  
//
//  Created by Константин Ланин on 05.05.2023.
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

// MARK: - Task

struct FT4Task: Codable {
    var id: String
    var templateId: String?
    var access: [OldAccess]?
    var template: Bool
    var completed: Bool
    let hidden: Bool
    let retention: String?
    let entity: String?
    var entityId: String?
    let name: Translation
    let description: Translation?
    let projectId: String?
    let projectName: String?
    let createdAt: Date
    let updatedAt: Date
    let title: Translation?
    let titleTemplate: Translation?
    let type: String?
    let taskThumbnail: String?
    let exhibitCounts: ExhibitCounts
    var fields: [FT4TaskField]
    
    func withoutExhibits() -> FT4Task {
        
        var taskFields = [FT4TaskField]()
        
        for field in fields {
            let taskField = FT4TaskField(id: field.id, entityField: field.entityField, title: field.title, placeholder: field.placeholder, description: field.description, required: field.required, type: field.type, min: field.min, max: field.max, sequence: field.sequence, features: field.features, answer: field.answer, exhibits: [], options: field.options)
            taskFields.append(taskField)
        }
        
        let task = FT4Task(id: id, templateId: templateId, template: template, completed: completed, hidden: hidden, retention: retention, entity: entity, entityId: entityId, name: name, description: description, projectId: projectId, projectName: projectName, createdAt: createdAt, updatedAt: updatedAt, title: title, titleTemplate: titleTemplate, type: type, taskThumbnail: taskThumbnail, exhibitCounts: exhibitCounts, fields: taskFields)
        
        return task
    }
}

struct OldAccess: Codable {
    let grantedAt: String
    let whoId: String?
    let whoName: String?
    let whoType: String?
    let permission: String
    let you: Bool
}

struct ExhibitCounts: Codable {
    let image: Int
    let video: Int
    let audio: Int
}

enum TaskEntity: String, Codable {
    case person
}

struct GetTasksInput: Encodable {
    let action = "get_tasks"
    let template: Bool?
    let completed: Bool?
    let hidden = false
    let includeFields = true
    let discarded = false
    let limit: Int?
    let accesses: [String]?
}

enum GetTaskInclude: String, Encodable {
    case none, answers, full
}

struct SubmitTaskInput: FT4Input {
    let action = "submit_task"
    let task: FT4Task
}

struct RegisterDeviceInput: FT4Input {
    let action = "register_user_device"
    let deviceId = UDStr(UserDefaultsKey.deviceId)
    let type = "capture_ios"
    let model = getDeviceModel()
    let description = getDeviceInfo()
    let locale = Locale.preferredLanguages.first
    var identifier: String = UDStr(UserDefaultsKey.deviceToken)
    let appVersion = "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "-")"
}

struct GetNotificationInput: FT4Input {
    let action = "get_notification"
    let notificationId: String
}

// MARK: - TaskField

struct FT4TaskField: Codable {
    var id: String
    let entityField: String?
    let title: Translation?
    let placeholder: Translation?
    let description: Translation?
    let required: Bool
    let type: TaskFieldType
    let min: Int?
    let max: Int?
    let sequence: Int?
    let features: [String]
    var answer: String?
    var exhibits: [FT4Exhibit]
    var options: [ChoiceOption]?
}

//enum TaskFieldType: String, Codable {
//    case text, number, file, time, choice, layout, subtask
//}

//class ChoiceOption: Codable {
//    let title: Translation?
//    let value: String
//    var answer: Bool
//    
//    
//}

// MARK: - Exhibit

struct FT4Exhibit: Codable {
    let id: String
    var duration: Int?
    var fileSize: Int?
    var mediaType: String?
    var discarded: Bool
    var startedAt: Date?
    var thumbnail: String?
    var createdAt: Date
    var updatedAt: Date
}

struct CreateExhibitInput: FT4Input {
    let action = "create_exhibit"
    let exhibitId: String
    let taskfieldId: String
    var duration: Int?
    var fileSize: Int?
    var mediaType: String?
    var startedAt: String?
    var deviceId: String?
    
    enum CodingKeys: String, CodingKey {
        case action
        case exhibitId = "exhibit_id"
        case taskfieldId = "taskfield_id"
        case duration
        case fileSize = "file_size"
        case mediaType = "media_type"
        case startedAt = "started_at"
        case deviceId = "device_id"
    }
}

struct SetEventInput: FT4Input {
    let action = "set_event"
    let eventId: String
    let exhibitId: String
    let type: String
    let subtype: String
    let source: String
    let fromTime: Double?
    let toTime: Double?
    let text: String?
    let language: String?
    let confidence: Double?
    let entity: String?
    let entityId: String?
    let entityData: [String: String?]?
}

struct UpdateExhibitInput: FT4Input {
    let action = "update_exhibit"
    let exhibitId: String
    let checksum: String?
    var duration: Int?
    var fileSize: Int?
    var mediaType: String?
    var startedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case action
        case exhibitId = "exhibit_id"
        case checksum
        case duration
        case fileSize = "file_size"
        case mediaType = "media_type"
        case startedAt = "started_at"
    }
}

struct CreateExhibitResponse: Codable {
    let uploadKey: String?
    
    enum CodingKeys: String, CodingKey {
        case uploadKey = "upload_key"
    }
}

// MARK: - Account

struct FT4Account: Codable {
    let id: String
    let accessToken: String
    let username: String
    let fullName: String
    let privileges: [String]
}

// MARK: - Errors

struct FT4Error: Decodable {
    let error: String
}

// MARK: - Auth

struct SignInInput: FT4Input {
    let action = "sign_in"
    let username: String
    let password: String
    let client = "capture_ios"
    let deviceId = UDStr(UserDefaultsKey.deviceId)
}

struct ADSignInInput: FT4Input {
    let action = "ad_authorize"
    let username: String
    let password: String
    let client = "capture_ios"
    let deviceId = UDStr(UserDefaultsKey.deviceId)
}

struct MDMSignInInput: FT4Input {
    let action = "sign_in_by_mdm"
    let username: String
    let client = "capture_ios"
    let deviceId = UDStr(UserDefaultsKey.deviceId)
}

struct AzureSignInInput: FT4Input {
    let action = "aad_auth"
    let username: String
    let redirectUri = "com.indicosys.evidence-capture://uri.receiver/redirect"
    let prompt: String?
    let client = "capture_ios"
    let deviceId = UDStr(UserDefaultsKey.deviceId)
}

struct AnonymousSignInInput: FT4Input {
    let action = "aad_auth_anonymous"
    let redirectUri = "com.indicosys.evidence-capture://uri.receiver/redirect"
    let client = "capture_ios"
    let deviceId = UDStr(UserDefaultsKey.deviceId)
}

struct SignOutInput: FT4Input {
    let action = "sign_out"
}

struct VerifyTokenInput: FT4Input {
    let action = "verify_token"
    let token: String
}

// MARK: - Log

struct LogInput: Encodable {
    let time, source: String
    let category: String
    let level: Int32
    let initiator, action: String?
    let subaction, target, targetType, inTarget: String?
    let inTargetType: String?
    let details: [String: String]?
}
