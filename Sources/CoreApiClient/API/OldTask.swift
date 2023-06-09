import CoreLocation

@available(iOS 13.0, *)
class OldTask {
    init(inAccount: OldAccount, withForm: FT4Task? = nil, fromCDTask: CDTask? = nil) {
        cdTask = fromCDTask
        if cdTask==nil {
            cdTask = CDTask(context: cdContext)
            cdTask?.id = withForm?.id
            cdTask?.created = Date()
            cdTask?.changed = cdTask?.created
            cdTask?.userSubmitted = nil
            cdSaveContext()
            form = withForm
        }
        inAccount.addTask(self)
    }
    
    var cdTask: CDTask?
    
    static func newTask(fromTemplate: FT4Task?) -> FT4Task? {
        guard var task = fromTemplate else { return nil }
        task.templateId = task.id
        task.id = UUID().uuidString
        for i in task.fields.indices {
            task.fields[i].id = UUID().uuidString
        }
        if task.entity != nil {
            task.entityId = UUID().uuidString
        }
        
        task.access = []
        
        return task
    }
    
    var changed: Date {
        get { cdTask?.changed ?? created }
        set(v) { cdTask?.changed = v; cdSaveContext() }
    }
    
    var created: Date { cdTask?.created ?? Date(timeIntervalSince1970: 0) }
    
    var form: FT4Task? {
        get {
            guard let data = cdTask?.form?.data(using: .utf8) else { return nil }
            return (try? JSONDecoder().decode(FT4Task.self, from: data))
        }
        set(v) {
            guard let jsonData = try? JSONEncoder().encode(v) else { return }
            cdTask?.form = String(data: jsonData, encoding: .utf8) ?? ""
            cdSaveContext()
        }
    }
    
    var id: String {
        get {
            return cdTask?.id ?? ""
        }
        set(v) {
            cdTask?.id = v
            cdSaveContext()
        }
    }
    
    var templateName: String {
        cdTask?.name ?? ""
    }
    
    var displayName: String {
        if form?.title == nil || getTranslation(dict: form?.title).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return formatDate(created, dateStyle: .medium, timeStyle: .short)
        } else {
            return getTranslation(dict: form?.title)
        }
    }
    
    var countPhoto: Int { exhibits.filter({$0.type == .photo && !$0.archived}).count }
    var countVideo: Int { exhibits.filter({$0.type == .video && !$0.archived}).count }
    var countAudio: Int { exhibits.filter({$0.type == .audio && !$0.archived}).count }
    
    var exhibits = [OldExhibit]()
    
    static var suggestedTemplates: [FT4Task] {
        guard let activeAccount = activeAccount else { return [FT4Task]() }
        
        let templates = activeAccount.tasks.compactMap({$0.form}).filter({$0.template && $0.type != "undefined"})
        let sortedTemplates = templates.sorted(by: {getTranslation(dict: $0.name) < getTranslation(dict: $1.name)})
        
        return sortedTemplates.filter { task in
            if let access = task.access {
                return access.contains(where: {$0.you && $0.permission == "created" || $0.permission == "assigned"})
            } else {
                return false
            }
        }
    }
    
    static var otherTemplates: [FT4Task] {
        guard let activeAccount = activeAccount else { return [FT4Task]() }
        
        let templates = activeAccount.tasks.compactMap({$0.form}).filter({$0.template && $0.type != "undefined"})
        let sortedTemplates = templates.sorted(by: {getTranslation(dict: $0.name) < getTranslation(dict: $1.name)})
        
        return sortedTemplates.filter { task in
            if let access = task.access {
                return !(access.contains(where: {$0.you && $0.permission == "created" || $0.permission == "assigned"}))
            }
            return true
        }
    }
    
    static var tasksAssignedToMe: [OldTask] {
        guard let activeAccount = activeAccount else { return [OldTask]() }
        
        let filteredTasks = activeAccount.tasks.filter({$0.form?.template == false})
        
        return filteredTasks.filter { task in
            guard let form = task.form else { return false }
            
            if let access = form.access {
                return access.contains(where: {$0.permission == "assigned" && $0.you})
            }
            return false
        }.sorted(by: {$0.changed > $1.changed})
    }
    
    static var myTasks: [OldTask] {
        guard let activeAccount = activeAccount else { return [OldTask]() }
        
        let filteredTasks = activeAccount.tasks.filter({$0.form?.template == false})
        
        return filteredTasks.filter { task in
            guard let form = task.form else { return false }
            
            if let access = form.access {
                return access.contains(where: {$0.permission == "created" && $0.you}) && !access.contains(where: {$0.permission == "assigned"})
            }
            return true
        }.sorted(by: {$0.changed > $1.changed})
    }
    
    static var tasksDelegatedByMe: [OldTask] {
        guard let activeAccount = activeAccount else { return [OldTask]() }
        
        let filteredTasks = activeAccount.tasks.filter({$0.form?.template == false})
        
        return filteredTasks.filter { task in
            guard let form = task.form else { return false }
            
            if let access = form.access {
                return access.contains(where: {$0.permission == "created" && $0.you}) && access.contains(where: {$0.permission == "assigned"})
            }
            return false
        }.sorted(by: {$0.changed > $1.changed})
    }

    func addExhibit(_ exhibit: OldExhibit) {
        exhibits.append(exhibit)
        if let cdExhibit=exhibit.cdExhibit {
            cdTask?.addToExhibits(cdExhibit)
            cdSaveContext()
        }
    }
    
    func deleteExhibit(_ exhibit: OldExhibit, reason: String) {
        if exhibit.isLocal {
            try? fileMgr.removeItem(at: exhibit.localURL)
            
            let account = exhibit.cdExhibit?.task?.account
            
            logft4(level: .custody_major, category: .change, initiator: account?.id ?? "", action: LogAction.delete.rawValue, subaction: "completed", target: exhibit.id, targetType: "exhibit", details: ["reason":reason])
        }
        cdContext.delete(exhibit.cdExhibit!)
        cdSaveContext()
        exhibits.removeAll { $0 === exhibit}
    }

    func createReport() -> [String:String] {
        guard let cdTask = cdTask else { return [:] }
        return ["id":            "\(cdTask.id ?? "nil")",
                "exhibitCount":  "\(cdTask.exhibits?.count ?? -1)",
                "changed":       "\(cdTask.changed?.description ?? "nil")",
                "userSubmitted": "\(cdTask.userSubmitted?.description ?? "nil")",
                "created":       "\(cdTask.created?.description ?? "nil")"]
    }
    
    var readyForSubmitTask: String? {
        #warning("Cannot find 'serverAvailable, worker' in scope")
        //if !serverAvailable { return "Server unavailable" }
        return nil
    }
    
    func submitTask(job: CDJob) {
        var complete = cdTask?.userSubmitted != nil
        #warning("Cannot find 'hasIncompleteTasks, worker' in scope")
//        if !hasIncompleteTasks {
//            form?.completed = true
//            complete = true
//        }
//
//        AppState.shared.server.submitTask(account: job.account, task: self) { ft4Response in
//            if ft4Response.statusCode == 200 {
//                DispatchQueue.main.async {
//                    if complete {
//                        self.cdTask?.formSubmitted = Date()
//                        cdSaveContext()
//                    }
//                    worker.completeJobs(ofType: .submitTask, forTarget: self.id)
//                    NotificationCenter.default.post(name: .doGetTasks, object: nil)
//                }
//            } else {
//                print(ft4Response.statusCode)
//                worker.fail(job, error: String(ft4Response.statusCode))
//            }
//        } failure: { ft4Error in
//            worker.fail(job, error: ft4Error.error)
//        }
    }
}

@available(iOS 13.0, *)
extension OldTask: Hashable {
    static func == (lhs: OldTask, rhs: OldTask) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(exhibits)
    }
}
