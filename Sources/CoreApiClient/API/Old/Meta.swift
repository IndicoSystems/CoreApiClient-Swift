import CoreData
import UIKit

enum MetaType: String {
    case unknown
    case favorite
    case bookmark
    case oval
    case blur
    case rotate
    case transcript
    case face
}

enum MetaCensorType: String {
    case none = "none"
    case imageBlur = "blur"
    case imagePixelate = "pixelate"
    case imageBar = "bar"
    case audioBeep = "beep"
    case audioDistort = "distort"
}

enum MetaShape: String {
    case none
    case point
    case line
    case rectangle
    case oval
    case arrow
}

@available(iOS 13.0, *)
class Meta {
    var cdMeta: CDMeta?

    var tags = [String]()
    
    func addTag(_ tag: String) {
        tags.append(tag)
        cdMeta!.tags = tags.joined(separator: ",")
        cdSaveContext()
    }

    func addTags(_ newTags: [String]) {
        for tag in newTags { tags.append(tag) }
        cdMeta!.tags = tags.joined(separator: ",")
        cdSaveContext()
    }

    func removeTag(_ tag: String) {
        tags.removeAll(where: { $0 == tag })
        cdMeta!.tags = tags.joined(separator: ",")
        cdSaveContext()
    }
    
    func hasTag(_ tag: String) -> Bool {
        return tags.contains(tag)
    }
    
    var title: String {
        get { return cdMeta!.title ?? "" }
        set(v) { cdMeta!.title = v; cdSaveContext() }
    }
    
    var details: String {
        get { return cdMeta!.details ?? "" }
        set(v) { cdMeta!.details = v; cdSaveContext() }
    }
    
    var content: String {
        get { return cdMeta!.content ?? "" }
        set(v) { cdMeta!.content = v; cdSaveContext() }
    }
    
    var type: MetaType {
        get { return MetaType(rawValue: cdMeta!.type ?? "") ?? .unknown }
        set(v) { cdMeta!.type = v.rawValue; cdSaveContext() }
    }
    
    var censor: MetaCensorType {
        get { return MetaCensorType(rawValue: cdMeta!.censor ?? "") ?? .none }
        set(v) { cdMeta!.censor = v.rawValue; cdSaveContext() }
    }
    
    var shape: MetaShape {
        get { return MetaShape(rawValue: cdMeta!.shape ?? "") ?? .none }
        set(v) { cdMeta!.shape = v.rawValue; cdSaveContext() }
    }
    
    var fromTime: Double {
        get { return cdMeta!.fromTime }
        set(v) { cdMeta!.fromTime = v; cdSaveContext() }
    }
    
    var toTime: Double {
        get { return cdMeta!.toTime }
        set(v) { cdMeta!.toTime = v; cdSaveContext() }
    }
    
    var center: CGPoint {
        get { return CGPoint(x: CGFloat(cdMeta!.centerX), y: CGFloat(cdMeta!.centerY)) }
        set(v) { cdMeta!.centerX = Float(v.x); cdMeta!.centerY = Float(v.y); cdSaveContext() }
    }
    
    var size: CGSize {
        get { return CGSize(width: CGFloat(cdMeta!.width), height: CGFloat(cdMeta!.height)) }
        set(v) { cdMeta!.width = Float(v.width); cdMeta!.height = Float(v.height); cdSaveContext() }
    }

    var rect: CGRect {
        get { return CGRect(x: CGFloat(cdMeta!.centerX-cdMeta!.width/2), y: CGFloat(cdMeta!.centerY-cdMeta!.height/2), width: CGFloat(cdMeta!.width), height: CGFloat(cdMeta!.height)) }
        set(v) {
            cdMeta!.centerX = Float(v.origin.x + v.width/2)
            cdMeta!.centerY = Float(v.origin.y + v.height/2)
            cdMeta!.width =   Float(v.width)
            cdMeta!.height =  Float(v.height)
        }
    }
    
    var angle: Float {
        get { return cdMeta!.angle }
        set(v) { cdMeta!.angle = v; cdSaveContext() }
    }
    
    var relevance: Float {
        get { return cdMeta!.relevance }
        set(v) { cdMeta!.relevance = v; cdSaveContext() }
    }
    
    var confidence: Float {
        get { return cdMeta!.confidence }
        set(v) { cdMeta!.confidence = v; cdSaveContext() }
    }
    
    init(inExhibit: OldExhibit, fromCDMeta: CDMeta? = nil) {
        cdMeta = fromCDMeta
        if cdMeta==nil {
            cdMeta = CDMeta(context: cdContext)
        }
        
        if fromCDMeta != nil {
            for tag in cdMeta!.tags?.split(separator: ",") ?? [] { tags.append("\(tag)") }
        }
        inExhibit.addMeta(self)
        cdSaveContext()
    }
}
