import CoreData

public struct UserDefaultsKey {
    static let activeAccount            = "activeAccount"
    static let activeTask               = "activeTask"
    static let host                     = "host"
    static let hostText                 = "hostText"
    static let database                 = "database"
    static let loginMethod              = "loginMethod"
    static let uuid                     = "uuid"
    static let deviceId                 = "deviceId"
    static let deviceToken              = "deviceToken"
    static let mobileManagementMode     = "mobileManagementMode"
    static let lastCullMedia            = "lastCullMedia"
    static let appInterrupted           = "AppInterrupted"
    static let appLaunches              = "AppLaunches"
    static let logIDAutoIncrement       = "logIDAutoIncrement"
    static let uploadNotificationShown  = "UploadNotificationShown"
    static let lastSeenServerVersion    = "lastSeenServerVersion"
    static let lastSeenAppUpdate        = "lastSeenAppUpdate"
    static let orgName                  = "settings.organization.name"
    static let orgLogo                  = "settings.capture.show.custom_logo"
    static let orgHeader                = "settings.capture.show.custom_header"
    static let cellularUpload           = "settings.capture.options.cellularupload"
    static let cellularUploadShow       = "settings.capture.show.cellularupload"
    static let cellularUploadCurrent    = "settings.capture.current.cellularupload"
    static let autoLock                 = "settings.capture.options.autolock"
    static let autoLockShow             = "settings.capture.show.autolock"
    static let autoLockCurrent          = "settings.capture.current.autolock"
    static let retentionHours           = "settings.capture.options.retention_hours"
    static let minimumFreeMB            = "settings.capture.options.minimum_free_mb"
    static let hasTaskTemplates         = "settings.capture.show.task_templates"
    static let hasIncompleteTasks       = "settings.capture.show.incomplete_tasks"
    static let allowsReverseGeocoding   = "settings.capture.options.allow_address_lookup"
    static let playbackSlow             = "settings.capture.playback.slow"
    static let playbackFast             = "settings.capture.playback.fast"
    static let playbackSkipForward      = "settings.capture.playback.skip_forward"
    static let playbackSkipBackward     = "settings.capture.playback.skip_backward"
    static let updateToVersion          = "settings.capture.show.update_to_version"
}

@available(iOS 13.0, *)
var accounts = [OldAccount]()

@available(iOS 13.0, *)
var activeAccount:OldAccount? {
    get { return accounts.first(where: { $0.id == UDStr(UserDefaultsKey.activeAccount) }) }
    set(v) { setUD(UserDefaultsKey.activeAccount, to: v?.id ?? "") }
}

@available(iOS 13.0, *)
var activeTask:OldTask? {
    get { return activeAccount?.tasks.filter{ $0.id==UDStr(UserDefaultsKey.activeTask) }.first }
    set(v) { setUD(UserDefaultsKey.activeTask, to: v?.id ?? "") }
}


@available(iOS 13.0, *)
func loadLocalDB() {
    do {
        let cdAccounts = try moc.fetch(NSFetchRequest<CDAccount>(entityName: "CDAccount"))
        for cdAccount in cdAccounts {
            let account = OldAccount(fromCDAccount: cdAccount)
            let cdTasks = (cdAccount.tasks ?? NSSet()).allObjects as? [CDTask] ?? []
            for cdTask in cdTasks {
                let task = OldTask(inAccount: account, fromCDTask: cdTask)
                let cdExhibits = (cdTask.exhibits ?? NSSet()).allObjects as? [CDExhibit] ?? []
                for cdExhibit in cdExhibits {
                    let exhibit = OldExhibit(inTask: task, fromCDExhibit: cdExhibit)
                    let cdMetas = (cdExhibit.metas ?? NSSet()).allObjects as? [CDMeta] ?? []
                    for cdMeta in cdMetas {
                        _ = Meta(inExhibit: exhibit, fromCDMeta: cdMeta)
                    }
                }
            }
        }
    } catch {
        logft4(level: .tech_coder, category: .error, action: "database", subaction: "load_database", details: ["error":error.localizedDescription])
    }
}

@available(iOS 13.0, *)
func deleteData(entity: String) {
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
    fetchRequest.returnsObjectsAsFaults = false
    do {
        let results = try moc.fetch(fetchRequest)
        for managedObject in results {
            if let managedObjectData: NSManagedObject = managedObject as? NSManagedObject {
                moc.delete(managedObjectData)
            }
        }
    } catch {
        logft4(level: .tech_coder, category: .error, action: "database", subaction: "delete_database", details: ["entity":entity, "error":error.localizedDescription])
    }
}

var cdCalls = 0

@available(iOS 13.0, *)
func cdSaveContext() {
    DispatchQueue.main.async {
        cdCalls += 1
    //    console("cdCalls: \(cdCalls)")
        if !Thread.current.isMainThread {
            for _ in 1...5 { print("####################################################################################################")}
            logft4(level: .tech_coder, category: .error, action: "database", subaction: "cdSaveContext", details: ["error":"CoreData activity on background thread"])
            for _ in 1...5 { print("####################################################################################################")}
            raise(SIGINT)
            return
        }

        if moc.hasChanges { try? moc.save() }
    }
}
