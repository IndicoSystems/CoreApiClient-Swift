//
//  CoreApiClient.swift
//
//
//  Created by Константин Ланин on 09.06.2023.
//

import Foundation

public class CoreApiClient {
    public enum ClientError: Error {
        case invalidHost
        case invalidUrl
        case noData
        case invalidJSON
        case noNetwork
    }
    
    public static let shared = CoreApiClient()
    
    // MARK: - Inner properties
    
    private var schema = "https"
    private var host = "host"
    
    private let api = "api"
    private let auth = "auth"
    
    private var apiAddress: URL? {
        get {
            return URL(string: "\(schema)://\(host)/\(api)/")
        }
    }
    private var authAddress: URL? {
        get {
            return URL(string: "\(schema)://\(host)/\(auth)/")
        }
    }
    
    private var showCellularUpload: Bool = false
    private var showAutoLock: Bool = false
    
    // MARK: - Auth
    
    private var isReauthenticating = false
    
    private var isSignedIn = false
    private var needsReauthentication: Bool = false {
        didSet(v) {
            setUD("needsReauthentication", to: v)
        }
    }
    
    var accounts = [Account]()
    var activeAccount:Account? {
        get { return accounts.first(where: { $0.id == UDStr(UserDefaultsKey.activeAccount) }) }
        set(v) { setUD(UserDefaultsKey.activeAccount, to: v?.id ?? "") }
    }
    
    // MARK: - Initialization
    
    public func setHost(host: String) throws {
        if let url = URL(string: host), let scheme = url.scheme, let host = url.host {
            self.schema = scheme
            self.host = host
        }
        else {
            self.schema = ""
            self.host = ""
            
            throw ClientError.invalidHost
        }
    }
    public func initialize(host: String, useCellularDataForUpload useCellularUpload: Bool = false, useAutoLock: Bool = false) throws {
        try self.setHost(host: host)
        
        self.showCellularUpload = useCellularUpload
        self.showAutoLock = useAutoLock
    }
    
    private func authRequest(account: Account?, payload: Data, completion: @escaping (Result<ApiResponse, Error>)->()) {
        var request = URLRequest(url: authAddress!, timeoutInterval: 10)
        request.httpMethod = "POST"
        
        if let accessToken = account?.accessToken {
            request.allHTTPHeaderFields = ["indico-access-token" : accessToken]
        }
        
        request.httpBody = payload
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let err = error as? NSError {
                if err.code == -1009 { completion(.failure(ClientError.noNetwork)) }
                return
            }
            
            guard let data = data else {
                completion(.failure(ClientError.noData))
                return
            }
            
            // check for json not nil
            let validJSON: Bool = (try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)) != nil
            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
            
            if httpStatus >= 200 && httpStatus < 300 {
                if (data.count > 0 && validJSON) || data.count == 0 {
                    let response = ApiResponse(statusCode: httpStatus, body: data)
                    completion(.success(response))
                    return
                }
            }
            
            if !validJSON {
                completion(.failure(ClientError.invalidJSON))
                return
            }
            
            let response = ApiResponse(statusCode: httpStatus, body: data)
            completion(.success(response))
            
        }.resume()
    }
    @available(iOS 13.0, *)
    private func apiRequest(account: Account?, payload: Data, completion: @escaping (Result<ApiResponse, Error>)->()) {
        var request = URLRequest(url: apiAddress!, timeoutInterval: 10)
        request.httpMethod = "POST"
        
        if let accessToken = account?.accessToken {
            request.allHTTPHeaderFields = ["indico-access-token" : accessToken]
        }
        
        request.httpBody = payload
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let err = error as? NSError {
                if err.code == -1009 { completion(.failure(ClientError.noNetwork)) }
                return
            }
            
            guard let data = data else {
                completion(.failure(ClientError.noData))
                return
            }
            
            // check for json not nil
            let validJSON: Bool = (try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)) != nil
            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0

            if httpStatus >= 200 && httpStatus < 300 {
                if (data.count > 0 && validJSON) || data.count == 0 {
                    let response = ApiResponse(statusCode: httpStatus, body: data)
                    completion(.success(response))
                    return
                }
            }
            
            if httpStatus == 401 {
                let authMode = AuthMode(rawValue: UDStr(UserDefaultsKey.loginMethod)) ?? .local
                
                if let unknownToken = String(data: data, encoding: .utf8)?.contains("unknown_token"), unknownToken {
                    self?.reauthenticate(using: authMode)
                }

                if let invalidCredentials = String(data: data, encoding: .utf8)?.contains("invalid_credentials"), invalidCredentials {
                    self?.reauthenticate(using: authMode)
                }
            }
            
            if !validJSON {
                completion(.failure(ClientError.invalidJSON))
                return
            }
            
            let response = ApiResponse(statusCode: httpStatus, body: data)
            completion(.success(response))
            
        }.resume()
    }
    
}

// MARK: - Authentication

@available(iOS 13.0, *)
extension CoreApiClient {
    private func reauthenticate(using authMode: AuthMode) {
        if isReauthenticating { return }
        isReauthenticating = true
        
        let username = (try? Keychain.standard.entry(forKey: "com.indicosys.evidence.username")) ?? ""
        let password = (try? Keychain.standard.entry(forKey: "com.indicosys.evidence.password")) ?? ""
        
        switch authMode {
        case .local:
            signIn(useActiveDirectory: false, username: username, password: password) { [weak self] account in
                self?.isReauthenticating = false
            } failure: { [weak self] error in
                print(error.error)
                
                self?.isReauthenticating = false
                
                AppState.shared.needsReauthentication = true
                AppState.shared.isSignedIn = false
            }
        case .ad:
            // sign in ad
            break
        case .azure:
            // sign in azure
            break
        case .anonymousReq:
            signInWithBid { [weak self] account in
                self?.isReauthenticating = false
            } failure: { [weak self] error in
                print(error.error)
                
                self?.isReauthenticating = false
                
                AppState.shared.needsReauthentication = true
                AppState.shared.isSignedIn = false
            }
        case .anonymous:
            break
        }
    }
    
    func signInToAAD(username: String, prompt: String?, completion: @escaping (Result<URL, Error>) -> ()) {
        let input = AzureSignInInput(username: username, prompt: prompt)
        let payload: Data = try! Coder.encode(input)
        
        authRequest(account: nil, payload: payload) { result in
            switch result {
            case .success(let response):
                let urlJson = try! JSONSerialization.jsonObject(with: response.body, options: .fragmentsAllowed) as! [String: String]
                let urlString = urlJson["azure_ad_url"] ?? ""
                let url = URL(string: urlString)!
                
                completion(.success(url))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func signInWithBid(completion: @escaping (Account)->(), failure: @escaping (ApiError) -> ()) {
        let input = AnonymousSignInInput()
        let payload = try! Coder.encode(input)
        
        authRequest(account: nil, payload: payload) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let response):
                let urlJson = try! JSONSerialization.jsonObject(with: response.body, options: .fragmentsAllowed) as! [String: String]
                let urlString = urlJson["azure_ad_url"] ?? ""
                let url = URL(string: urlString)!
                
                self.getURL(from: url) { account in
                    completion(account)
                } failure: { error in
                    let error = ApiError(error: error.localizedDescription)
                    failure(error)
                }
            case .failure(let error):
                let error = ApiError(error: error.localizedDescription)
                failure(error)
            }
        }
    }
    
    func signInToMDM(username: String, completion: @escaping (Account)->(), failure: @escaping (ApiError) -> ()) {
        let input = MDMSignInInput(username: username)
        let payload = try! Coder.encode(input)
        
        authRequest(account: nil, payload: payload) { result in
            switch result {
            case .success(let response):
                switch response.statusCode {
                case 0, 400..<600:
                    if let error: ApiError = try? Coder.decode(response.body) {
                        failure(error)
                    }
                    return
                default:
                    let account: Account = try! Coder.decode(response.body)
                    
                    self.setAccount(from: account)
                    self.needsReauthentication = false
                    self.isSignedIn = true
                    
                    do {
                        try Keychain.standard.set(entry: username, forKey: "com.indicosys.evidence.username")
                    } catch {
                        print(error.localizedDescription)
                    }
                    
                    completion(account)
                    #warning("Cannot find 'worker' in scope")
//                    worker.resetJobs(hard: true)
                }
            case .failure(let err):
                let error = ApiError(error: err.localizedDescription)
                failure(error)
            }
        }
    }
    
    func signIn(useActiveDirectory: Bool, username: String, password: String, completion: @escaping (Account)->(), failure: @escaping (ApiError) -> ()) {
        var payload: Data
        
        if useActiveDirectory {
            payload = try! Coder.encode(ADSignInInput(username: username, password: password))
        } else {
            payload = try! Coder.encode(SignInInput(username: username, password: password))
        }
        
        authRequest(account: nil, payload: payload) { result in
            switch result {
            case .success(let response):
                switch response.statusCode {
                case 0, 400..<600:
                    if let error: ApiError = try? Coder.decode(response.body) {
                        failure(error)
                    }
                    return
                default:
                    let account: Account = try! Coder.decode(response.body)
                    
                    self.setAccount(from: account)
                    self.needsReauthentication = false
                    self.isSignedIn = true
                    
                    do {
                        try Keychain.standard.set(entry: username, forKey: "com.indicosys.evidence.username")
                        try Keychain.standard.set(entry: password, forKey: "com.indicosys.evidence.password")
                    } catch {
                        print(error.localizedDescription)
                    }
                    
                    completion(account)
                    #warning("Cannot find 'worker' in scope")
//                    worker.resetJobs(hard: true)
                }
            case .failure(let err):
                let error = ApiError(error: err.localizedDescription)
                failure(error)
            }
        }
    }
    
    func signOut(completion: @escaping () -> ()) {
        let input = SignOutInput()
        let payload = try! Coder.encode(input)
        
        authRequest(account: activeAccount, payload: payload) { _ in
            completion()
        }
    }
    
    func verifyToken(token: String, completion: @escaping (Account) -> (), failure: @escaping (ApiError) -> ()) {
        guard connectionType != .none else { return }
        
        let payload = try! Coder.encode(VerifyTokenInput(token: token))
        
        authRequest(account: activeAccount, payload: payload) { [weak self] result in
            guard let self = self else { return }
            
            #warning("How can 'self' be nil?")
            
            switch result {
            case .success(let response):
                switch response.statusCode {
                case 401:
                    do {
                        let error: ApiError = try Coder.decode(response.body)
                        failure(error)
                    } catch {
                        print("Could not decode error: \(error.localizedDescription)")
                    }
                case 200:
                    do {
                        let account: Account = try Coder.decode(response.body)
                        completion(account)
                    } catch {
                        print("Could not decode error: \(error.localizedDescription)")
                    }
                default:
                    break
                }
            case .failure(let error):
                let error = ApiError(error: error.localizedDescription)
                failure(error)
            }
        }
    }
    
    /// For sign in with Bid
    private func getURL(from url: URL, completion: @escaping (Account) -> (), failure: @escaping (Error) -> ()) {
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                failure(error)
                return
            }
            
            if let data = data {
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as! [String : String]
                    
                    let urlString = json["azure_ad_url"]!
                    let url = URL(string: urlString)!
                    
                    var request = URLRequest(url: url)
                    request.setValue("AppleWebKit/20.5.0", forHTTPHeaderField: "User-Agent")
                    request.setValue(nil, forHTTPHeaderField: "Accept")
                    
                    self.getAccount(withRequest: request) { account in
                        completion(account)
                    } failure: { error in
                        failure(error)
                    }

                    
                } catch {
                    failure(error)
                    return
                }
            }
        }.resume()
    }
    
    /// For get Url
    private func getAccount(withRequest request: URLRequest, completion: @escaping (Account) -> (), failure: @escaping (Error) -> ()) {
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            
            guard let self = self else { return }
            if let error = error {
                logft4(level: .tech_support, category: .info, initiator: activeAccount?.id, action: "bid_test", subaction: "tried_logging_in_failed", details: ["error": error.localizedDescription])
                failure(error)
                return
            }

            if let data = data {
                logft4(level: .tech_support, category: .info, initiator: activeAccount?.id, action: "bid_test", subaction: "tried_logging_in_start", details: ["data": String(data: data, encoding: .utf8)!])

                do {
                    let account: Account = try Coder.decode(data)
                    self.setAccount(from: account)
                    
                    self.needsReauthentication = false
                    self.isSignedIn = true
                    
                    completion(account)
                } catch {
                    logft4(level: .tech_support, category: .info, initiator: activeAccount?.id, action: "bid_test", subaction: "tried_logging_in_failed", details: ["error": error.localizedDescription])
                    failure(error)
                }
            }
        }.resume()
    }
    
    /// For get account
    private func setAccount(from account: Account) {
        if activeAccount == nil {
            activeAccount = account
        } else {
            activeAccount!.accessToken = account.accessToken
            
            #warning("how does it work?")
        }
    }
}

// MARK: - Fetch requests

@available(iOS 13.0, *)
extension CoreApiClient {
    func getInfo(completion: @escaping (Result<ServerInfo, Error>) -> ()) {
        guard let url = URL(string: "\(self.apiAddress?.absoluteString ?? "")info/") else {
            completion(.failure(ClientError.invalidUrl))
            return
        }
        
        let request = URLRequest(url: url, timeoutInterval: 10)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let err = error as? NSError {
                if err.code == -1003 {
                    completion(.failure(ClientError.invalidUrl))
                } else if err.code == -1009 {
                    completion(.failure(ClientError.noNetwork))
                } else {
                    completion(.failure(ClientError.invalidHost))
                }
            }
            
            if let data = data {
                do {
                    let serverInfo: ServerInfo = try Coder.decode(data)
                    
                    Settings.setSettings(settings: serverInfo.settings)
                    
                    #warning("local variables used instead of settings")
                    Settings.setIfNotSet(current: UserDefaultsKey.cellularUploadCurrent, show: UserDefaultsKey.cellularUploadShow, defaultTo: UserDefaultsKey.cellularUpload)
                    Settings.setIfNotSet(current: UserDefaultsKey.autoLockCurrent, show: UserDefaultsKey.autoLockShow, defaultTo: UserDefaultsKey.autoLock)
                
                    completion(.success(serverInfo))
                } catch {
                    let err = error as NSError
                    if err.code == 4864 {
                        completion(.failure(ClientError.invalidJSON))
                    }
                }
            }
        }.resume()
    }
    
    func getTasks(input: GetTasksInput, completion: @escaping ([Task]) -> (), failure: @escaping (ApiError) -> ()) {
        let payload = try! Coder.encode(input)
        
        apiRequest(account: activeAccount, payload: payload) { result in
            switch result {
            case .success(let response):
                switch response.statusCode {
                case 200..<300:
                    setUD(UserDefaultsKey.database, to: String(data: response.body, encoding: .utf8))
                    
                    do {
                        let tasks: [Task] = try Coder.decode(response.body)
                        completion(tasks)
                    } catch {
                        let error = ApiError(error: error.localizedDescription)
                        failure(error)
                    }
                default:
                    if let error: ApiError = try? Coder.decode(response.body) {
                        failure(error)
                    }
                }
            case .failure(let error):
                let error = ApiError(error: error.localizedDescription)
                failure(error)
            }
        }
    }
    
    func createExhibit(account: Account?, exhibit: Exhibit, taskFieldId: String, completion: @escaping (CreateExhibitResponse)->(), failure: @escaping (ApiError)->()) {
        let input = CreateExhibitInput(exhibitId: exhibit.id!,
                                       taskfieldId: taskFieldId,
                                       duration: Int(exhibit.duration),
                                       fileSize: Int(exhibit.fileSize),
                                       //mediaType: exhibit.type.rawValue + "/" + (exhibit.fileExtensions[exhibit.type] ?? ""),
                                       mediaType: exhibit.mediaType! + "/" + (fileExtensions[ExhibitType(rawValue: exhibit.mediaType ?? "") ?? ExhibitType.unknown] ?? ""),
                                       //startedAt: exhibit.startedAt,
                                       startedAt: exhibit.startedAt!.ft4TimeStamp,
                                       deviceId: UDStr(UserDefaultsKey.deviceId))
        
        #warning("media type: - is it correct")
        #warning("startedAt not a Date")
        
        let payload = try! Coder.encode(input)
        
        apiRequest(account: account, payload: payload) { result in
            switch result {
            case .success(let response):
                
                if response.statusCode >= 200 && response.statusCode < 300 {
                    if let response: CreateExhibitResponse = try? Coder.decode(response.body) {
                        completion(response)
                    } else {
                        let error: ApiError = try! Coder.decode(response.body)
                        failure(error)
                    }
                } else {
                    if let response: ApiError = try? Coder.decode(response.body) {
                        failure(response)
                    }
                }
                
            case .failure(let error):
                let error = ApiError(error: error.localizedDescription)
                failure(error)
            }
        }
    }
    
    func setEvent(account: Account?, exhibit: Exhibit, completion: @escaping (ApiResponse)->()) {
        // TODO: - Needs checksum and location
        
        let entityData: [String : String?]
        
        if let location = exhibit.location {
            entityData = ["latitude": String(location.latitude),
                          "longitude": String(location.longitude),
                          "street_address": location.streetAddress,
                          "postal_code": location.postalCode,
                          "city": location.place,
                          "region": location.region,
                          "country": location.country,
                          "altitude": String(location.altitude),
                          "hor_accuracy": String(location.horizontalAccuracy),
                          "vert_accuracy": String(location.verticalAccuracy)]
            #warning("is 'place' a correct value for 'city'")
        }
        else {
            entityData = [:]
        }
        
        let input = SetEventInput(eventId: UUID().uuidString,
                                  exhibitId: exhibit.id ?? "",
                                  type: "location",
                                  subtype: "start",
                                  source: "machine",
                                  fromTime: 0,
                                  toTime: 0,
                                  text: nil,
                                  language: nil,
                                  confidence: nil,
                                  entity: "location",
                                  entityId: UUID().uuidString,
                                  entityData: entityData
        )
        
        let payload = try! Coder.encode(input)
        
        apiRequest(account: account, payload: payload) { result in
            switch result {
            case .success(let response):
                completion(response)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
    
    func updateExhibit(account: Account?, exhibit: Exhibit, completion: @escaping (ApiResponse)->()) {
        // TODO: - Needs checksum and location
        
        let input = UpdateExhibitInput(exhibitId: exhibit.id!,
                                       checksum: exhibit.clientChecksum,
                                       duration: Int(exhibit.duration),
                                       fileSize: Int(exhibit.fileSize),
                                       startedAt: exhibit.startedAt!.ft4TimeStamp)
        
        let payload = try! Coder.encode(input)
        
        apiRequest(account: account, payload: payload) { result in
            switch result {
            case .success(let response):
                completion(response)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
    
    func discardExhibit(account: Account?, exhibit: Exhibit, completion: @escaping (Int) -> (), failure: @escaping (ApiError)->()) {
        let json: [String: String?] = ["action" : "discard_exhibit", "exhibit_id" : exhibit.id]
        let data = try! JSONSerialization.data(withJSONObject: json, options: .fragmentsAllowed)
        
        apiRequest(account: account, payload: data) { result in
            switch result {
            case .success(let response):
                if response.statusCode >= 200 && response.statusCode < 300 {
                    completion(response.statusCode)
                } else {
                    if let response: ApiError = try? Coder.decode(response.body) {
                        failure(response)
                    }
                }
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
    
    func getExhibitStatus(exhibits: [Exhibit], completion: @escaping (ApiResponse)->()) {
        let ids = exhibits.map({$0.id})
        let json: [String: Any] = ["action" : "get_exhibit_status", "exhibit_ids" : ids]
        let data = try! JSONSerialization.data(withJSONObject: json, options: .fragmentsAllowed)
        
        apiRequest(account: activeAccount, payload: data) { result in
            switch result {
            case .success(let response):
                completion(response)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
    
    func submitTask(account: Account?, task: Task, completion: @escaping (ApiResponse)->(), failure: @escaping (ApiError) -> ()) {
        #warning("removing exhibits from task might be an issue for consistent store")
        //let form = task.form!.withoutExhibits()
        
        do {
            let json: [String: Any] = ["action" : "submit_task", "task" : task]
            let payload = try JSONSerialization.data(withJSONObject: json, options: .fragmentsAllowed)
            
            apiRequest(account: account, payload: payload) { result in
                switch result {
                case .success(let response):
                    if response.statusCode >= 200 && response.statusCode < 300 {
                        completion(response)
                    } else {
                        if let response = try? JSONDecoder().decode(ApiError.self, from: response.body) {
                            failure(response)
                        }
                    }
                case .failure(let error):
                    let error = ApiError(error: error.localizedDescription)
                    failure(error)
                    //print(error.localizedDescription)
                }
            }
        } catch {
            let error = ApiError(error: error.localizedDescription)
            failure(error)
            //print(error.localizedDescription)
        }
    }
    
    func registerDevice(deviceToken: String? = nil) {
        guard let activeAccount = activeAccount else { return }
        guard let deviceToken = deviceToken else { return }
        
        var input = RegisterDeviceInput(identifier: deviceToken)
        let payload = try! Coder.encode(input)
        
        apiRequest(account: activeAccount, payload: payload) { _ in }
        
        #warning("Why is it not checked for some result?")
    }
    
    func getNotification(withId id: String, completion: @escaping (ApiResponse)->(), failure: @escaping (ApiError)->()) {
        let input = GetNotificationInput(notificationId: id)
        let payload = try! Coder.encode(input)
        
        apiRequest(account: activeAccount, payload: payload) { result in
            switch result {
            case .success(let response):
                if response.statusCode >= 200 && response.statusCode < 300 {
                    completion(response)
                    return
                }
                
                if let response: ApiError = try? Coder.decode(response.body) {
                    failure(response)
                }
            case .failure(let error):
                failure(ApiError(error: error.localizedDescription))
            }
        }
    }
}
