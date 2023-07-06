import CoreData

let maxLogSize = 5000
var isSubmitting = false

//enum LogCategory:String { case info, read, change, error }
//
//enum LogLevel:Int { case users_minor=2, custody_major=4, custody_minor=5, tech_support=7, tech_coder=8, tech_debug=9 }
//
//enum LogAction: String {
//    case capturePhoto = "capture_photo"
//    case captureVideo = "capture_video"
//    case captureAudio = "capture_audio"
//    case captureFile = "capture_file"
//    case upload, verify, delete, download
//}

@available(iOS 13.0, *)
func logft4(level: LogLevel, category: LogCategory, initiator: String? = activeAccount?.id, action: String, subaction: String? = nil, target: String? = nil, targetType: String? = nil, inTarget: String? = nil, inTargetType: String? = nil, details: [String:String]? = nil) {
    console("Log (\(level.rawValue) - \(category.rawValue)): \(action) - \(subaction ?? "")")
    
    let details = logCommon().merging(details ?? [:]) { (current, _) in current }
    
    let logInput = LogInput(time: Date().ft4TimeStamp, source: "capture_ios", category: category.rawValue, level: level.rawValue, initiator: initiator, action: action, subaction: subaction, target: target, targetType: targetType, inTarget: inTarget, inTargetType: inTargetType, details: details)
    
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let body = try! encoder.encode(logInput)
    
    DispatchQueue.main.async {
        let nextID = UDInt(UserDefaultsKey.logIDAutoIncrement) + 1
        setUD(UserDefaultsKey.logIDAutoIncrement, to: nextID)
        let log = CDLog(context: moc)
        log.id = Int32(nextID)
        log.body = String(data: body, encoding: .utf8)
        
        let fetchReq = NSFetchRequest<CDLog>(entityName: "Log")
        fetchReq.predicate = NSPredicate(format: "id <= \(nextID-maxLogSize)")
        (try? moc.fetch(fetchReq))?.forEach { moc.delete($0) }
        cdSaveContext()
        //print("Log size: \((try? cdContext.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: "Log"))) ?? 0)")
    }
}

@available(iOS 13.0, *)
func logSubmit() {
    guard connectionType != .none, !isSubmitting, !UDStr(UserDefaultsKey.host).isEmpty else { return }
    
    let url = URL(string: "\(FT4Client.shared.host)")!.appendingPathComponent("log/")
    
    isSubmitting = true
    
    let fetchReq = NSFetchRequest<CDLog>(entityName: "Log")
    fetchReq.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
    fetchReq.predicate = NSPredicate(format: "isSynced == 0")
    fetchReq.fetchLimit = 50
    guard let logs = try? moc.fetch(fetchReq), !logs.isEmpty else { isSubmitting = false; return }
    
    let body = "[" + logs.compactMap({$0.body}).joined(separator: ",") + "]"
    
    var request = URLRequest(url: url)
    request.allHTTPHeaderFields = ["indico-log-key":"8NTPnrHqvAUz"]
    request.httpMethod = "POST"
    request.httpBody = body.data(using: .utf8)
    
    URLSession.shared.dataTask(with: request) { (data, response, error) in
        defer {
            isSubmitting = false
        }
        
        guard let response = response as? HTTPURLResponse else { return }
        
        //Todo: What to do if we don't get 204?
        if response.statusCode > 399 {
            return
        }
        
        if error == nil {
            DispatchQueue.main.async {
                logs.forEach{ $0.isSynced = true }
                cdSaveContext()
            }
        }
    }.resume()
}

#warning("Cannot find 'settings' in scope")
func logCommon() -> [String:String] {
    [
        "app_version": "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "?") (\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? "?"))",
//        "device_model": settings.getDeviceModel(),
//        "device_info": settings.getDeviceInfo()
    ]
}

func createLogfile() -> URL? {
    guard let log = try? moc.fetch(NSFetchRequest<CDLog>(entityName: "Log")).sorted(by: { $0.id > $1.id }) else { return nil }
    let string = "[" + log.compactMap({$0.body}).joined(separator: ",") + "]"
    let data = string.data(using: .utf8)
    let fileURL = cacheURL.appendingPathComponent("log.json")
    fileMgr.createFile(atPath: fileURL.path, contents: data)
    return fileURL
}
