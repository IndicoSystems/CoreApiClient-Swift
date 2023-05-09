import UIKit
import CoreData

@available(iOS 13.0, *)
class Account {
    var cdAccount: CDAccount?
    var tasks = [Task]()
    var id: String { return cdAccount!.id! }
    
    var token: String? {
        get { return cdAccount?.token }
        set(v) { cdAccount?.token = v; cdSaveContext() }
    }
    
    var userName: String {
        get { return cdAccount?.userName ?? "" }
        set(v) { cdAccount?.userName = v; cdSaveContext() }
    }
    
    var fullName: String? {
        get { return cdAccount?.fullName }
        set(v) { cdAccount?.fullName = v; cdSaveContext() }
    }
    
    func addTask(_ task: Task) {
        tasks.append(task)
        cdAccount?.addToTasks(task.cdTask!)
        cdSaveContext()
    }
    
    init(fromCDAccount: CDAccount? = nil) {
        cdAccount = fromCDAccount
        if cdAccount==nil {
            cdAccount = CDAccount(context: cdContext)
            cdAccount?.id = UUID().uuidString
            DispatchQueue.main.async {
                cdSaveContext()
            }
        }
        accounts.append(self)
    }
    
    func deleteTask(_ task: Task) {
        #warning("Cannot find 'worker' in scope")
//        task.exhibits.forEach { exhibit in
//            if !worker.jobs(forIDs: [exhibit.id]).isEmpty { return }
//        }
//
//        if !worker.jobs(forIDs: [task.id]).isEmpty { return }
        
        task.exhibits.forEach { exhibit in
            task.deleteExhibit(exhibit, reason: "Task has been removed")
        }
        
        cdContext.delete(task.cdTask!)
        cdSaveContext()
        tasks.removeAll { $0 === task }
    }
    
    func deleteExhibitsWithNoMedia() {
        #warning("Cannot find 'isRecording || capturingPhoto' in scope")
        //if isRecording || capturingPhoto { return }
        for task in tasks {
            task.exhibits.filter{$0.uploadedAt==nil && !$0.isLocal && !fileMgr.fileExists(atPath: $0.localURL.path+".caf") && !fileMgr.fileExists(atPath: $0.localURL.path+"."+videoFileExt)}.forEach {
                task.deleteExhibit($0, reason: "")
                
                let account = task.cdTask?.account
                
                logft4(level: .tech_support, category: .change, initiator: account?.id ?? "", action: "maintenance", subaction: "delete_exhibit_with_no_file", target: $0.id, targetType: "exhibit", details: $0.createReport())
            }
        }
    }
    
    func cullMedia() {
        
        deleteExhibitsPastRetention()
        
        #warning("Cannot find 'safeSpace' in scope")
        //while safeSpace == 0 {
        while true {
            if let exhibitToDelete = (accounts.flatMap({$0.tasks}).flatMap{ $0.exhibits }.filter{ $0.cdExhibit!.status == "safe_to_delete" && $0.isLocal }).sorted(by: { $0.captureStartedAt! < $1.captureStartedAt! }).first {
                try? fileMgr.removeItem(at: exhibitToDelete.localURL)
                if exhibitToDelete.isLocal { break }
                
                let account = exhibitToDelete.cdExhibit?.task?.account
                
                logft4(level: .tech_support, category: .change, initiator: account?.id ?? "", action: "maintenance", subaction: "cull_exhibit_file", target: exhibitToDelete.id, targetType: "exhibit", details: exhibitToDelete.createReport())
            } else { break }
        }
    }
    
    private func deleteExhibitsPastRetention() {
        guard let activeAccount = activeAccount else { return }
        #warning("Cannot find 'Settings' in scope")
        let retentionDays = 24 * 30 //Settings.shared.retentionHours
        let retentionSeconds = retentionDays * 60 * 60
        
        let completedTasks = activeAccount.tasks.filter({ $0.cdTask?.userSubmitted != nil })
        
        #warning("'advanced(by:)' is only available in iOS 13.0 or newer")
        let cullableTasks = completedTasks.filter({
            if #available(iOS 13.0, *) {
                return Date() > $0.cdTask!.userSubmitted!.advanced(by: TimeInterval(retentionSeconds))
            } else {
                return Date() > $0.cdTask!.userSubmitted! + TimeInterval(retentionSeconds)
            }
        })
        
        let exhibitsToBeDeleted = cullableTasks
            .flatMap({$0.exhibits})
            .filter({ $0.cdExhibit?.status == "safe_to_delete" &&  $0.isLocal } )
        
        exhibitsToBeDeleted.forEach({
            try? fileMgr.removeItem(at: $0.localURL)
        })
    }
    
    func getExhibitStatus() {
        #warning("Cannot find 'serverAvailable' in scope")
        //guard serverAvailable else { return }
        
        let allExhibits = accounts.flatMap({$0.tasks}).flatMap{ $0.exhibits }.filter{ $0.cdExhibit!.status != "safe_to_delete" && $0.isLocal }
        
        if allExhibits.isEmpty { return }
        #warning("Cannot find 'AppState' in scope")
//        AppState.shared.server.getExhibitStatus(exhibits: allExhibits) { response in
//            let dict = try! JSONSerialization.jsonObject(with: response.body, options: .allowFragments) as! [String : String]
//
//            let exhibits = exhibitsFromIDs(Array(dict.keys))
//
//            DispatchQueue.main.async {
//
//                for exhibit in exhibits {
//                    exhibit.cdExhibit!.status = dict[exhibit.id]!
//                }
//                cdSaveContext()
//            }
//        }
    }
    
    func doMaintenance() {
        let lastCullMedia = UDInt(UserDefaultsKey.lastCullMedia)
        let now = Int(Date().timeIntervalSince1970)
        if now > lastCullMedia + 60 {
            cullMedia()
            setUD(UserDefaultsKey.lastCullMedia, to: now)
        }
        
        #warning("Cannot find 'syncLoopClk, setIconBadge, nextJobTime, worker' in scope")
//        if syncLoopClk % 20 == 2 { deleteExhibitsWithNoMedia() }
//        if syncLoopClk % 20 == 8 { setIconBadge() }
//
//        if syncLoopClk >= nextJobTime {
//            nextJobTime = syncLoopClk + 10
//            worker.nextJob()
//        }
//
//        if syncLoopClk % 25 == 15 {
//            getExhibitStatus()
//        }
    }
}
