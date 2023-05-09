import Foundation

enum AuthMode: String {
    case local
    case ad
    case azure = "azure_ad"
    case anonymousReq = "azure_ad_anonymous_req"
    case anonymous = "azure_ad_anonymous"
}

@available(iOS 13.0, *)
class FT4Client {
    
    enum CloudClientError: LocalizedError {
        case invalidUrl
        case noData
        case invalidJSON
        case noNetwork
        case invalidHost
        
        #warning("Cannot find 'Loc' in scope")
//        var errorDescription: String? {
//            switch self {
//            case .invalidUrl:
//                return Loc.auth.noHostFound
//            case .noData:
//                return NSLocalizedString("No data in API response", comment: "")
//            case .invalidJSON:
//                return Loc.auth.invalidHost
//            case .invalidHost:
//                return Loc.auth.invalidHost
//            case .noNetwork:
//                return Loc.auth.noNetworkLogin
//            }
//        }
    }
    
    enum HTTPMethod: String {
        case post = "POST"
    }
    
    enum Endpoint: String {
        case api = "api/"
        case auth = "auth/"
    }
    
    static let shared = FT4Client()
    
    var host: String {
        let udString = UDStr(UserDefaultsKey.host)
        if udString.contains("https://") {
            return udString
        } else {
            return "https://" + udString
        }
    }
    
    var loginMethods: [String]!
    
    var listener: URLSessionDataTask? = nil
    private var session: URLSession! = nil
    
    private lazy var jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .ft4
        return decoder
    }()
    
    private lazy var jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .ft4
        return encoder
    }()
    
    var isReauthenticating = false
    
    private func apiRequest(account: CDAccount?, endpoint: Endpoint, payload: Data, completion: @escaping (Result<FT4Response, Error>)->()) {
        
        guard let url = URL(string: "\(host)/") else {
            completion(.failure(CloudClientError.invalidUrl))
            return
        }
        
        var request = URLRequest(url: url.appendingPathComponent(endpoint.rawValue))
        request.httpMethod = HTTPMethod.post.rawValue
        request.timeoutInterval = 10
        
        if let token = account?.token {
            request.allHTTPHeaderFields = ["indico-access-token" : token]
        }
        
        request.httpBody = payload
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let err = error as? NSError {
                if err.code == -1009 { completion(.failure(CloudClientError.noNetwork)) }
                return
            }
            
            guard let data = data else {
                completion(.failure(CloudClientError.noData))
                return
            }
            
            var validJSON = false
            var httpStatus = 0
            
            if let _ = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) {
                validJSON = true
            }
            
            if let response = response as? HTTPURLResponse {
                httpStatus = response.statusCode
            }
            
            if httpStatus >= 200 && httpStatus < 300 {
                if (data.count > 0 && validJSON) || data.count == 0 {
                    let ft4Response = FT4Response(statusCode: httpStatus, body: data)
                    completion(.success(ft4Response))
                    return
                }
            }
            
            if httpStatus == 401 && endpoint == .api {
                
                let authMode = AuthMode(rawValue: UDStr(UserDefaultsKey.loginMethod)) ?? .local
                
                if let unknownToken = String(data: data, encoding: .utf8)?.contains("unknown_token"), unknownToken {
                    self?.reauthenticate(using: authMode)
                }
                
                if let invalidCredentials = String(data: data, encoding: .utf8)?.contains("invalid_credentials"), invalidCredentials {
                    self?.reauthenticate(using: authMode)
                }
            }
            
            if !validJSON {
                completion(.failure(CloudClientError.invalidJSON))
                return
            }
            
            let ft4Response = FT4Response(statusCode: httpStatus, body: data)
            completion(.success(ft4Response))
            
        }.resume()
    }
    
    var firstGetTasks = true
}

@available(iOS 13.0, *)
extension FT4Client: Server {
    
    func getInfo(urlString: String, completion: @escaping (Result<ServerInfo, Error>) -> ()) {
        
        var completeUrl = urlString
        
        if !urlString.contains("https://") {
            completeUrl = "https://" + urlString
        }
        
        guard let url = URL(string: "\(completeUrl)/info/") else {
            completion(.failure(CloudClientError.invalidUrl))
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let err = error as? NSError {
                if err.code == -1003 {
                    completion(.failure(CloudClientError.invalidUrl))
                } else if err.code == -1009 {
                    completion(.failure(CloudClientError.noNetwork))
                } else {
                    completion(.failure(CloudClientError.invalidHost))
                }
            }
            
            if let data = data {
                do {
                    let jsonDecoder = JSONDecoder()
                    jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
                    let serverInfo = try jsonDecoder.decode(ServerInfo.self, from: data)
                    
                    serverInfo.settings.forEach { (key: String, value: String?) in
                        
                        if value != nil {
                            setUD("settings.\(key)", to: value)
                        }
                    }
                    
                    #warning("Cannot find 'settings' in scope")
//                    if UserDefaults.standard.object(forKey: UserDefaultsKey.cellularUploadCurrent) == nil || !settings.cellularUploadShow {
//                        let valueToSet = UDStr(UserDefaultsKey.cellularUpload)
//                        setUD(UserDefaultsKey.cellularUploadCurrent, to: valueToSet)
//                    }
//
//                    if UserDefaults.standard.object(forKey: UserDefaultsKey.autoLockCurrent) == nil || !settings.autoLockShow {
//                        let valueToSet = UDStr(UserDefaultsKey.autoLock)
//                        setUD(UserDefaultsKey.autoLockCurrent, to: valueToSet)
//                    }
                
                    completion(.success(serverInfo))
                } catch {
                    let err = error as NSError
                    if err.code == 4864 {
                        completion(.failure(CloudClientError.invalidJSON))
                    }
                }
            }
        }.resume()
    }
    
    func signInToAAD(username: String, prompt: String?, completion: @escaping (Result<URL, Error>) -> ()) {
        let input = AzureSignInInput(username: username, prompt: prompt)
        let payload = try! jsonEncoder.encode(input)
        
        apiRequest(account: nil, endpoint: .auth, payload: payload) { result in
            switch result {
            case .success(let ft4Response):
                let urlJson = try! JSONSerialization.jsonObject(with: ft4Response.body, options: .fragmentsAllowed) as! [String: String]
                let urlString = urlJson["azure_ad_url"] ?? ""
                let url = URL(string: urlString)!
                completion(.success(url))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func signInWithBid(completion: @escaping (FT4Account)->(), failure: @escaping (FT4Error) -> ()) {
        let input = AnonymousSignInInput()
        let payload = try! jsonEncoder.encode(input)
        
        apiRequest(account: nil, endpoint: .auth, payload: payload) { [weak self] result in
            
            guard let self = self else { return }
            switch result {
            case .success(let ft4Response):
                let urlJson = try! JSONSerialization.jsonObject(with: ft4Response.body, options: .fragmentsAllowed) as! [String: String]
                let urlString = urlJson["azure_ad_url"] ?? ""
                let url = URL(string: urlString)!
                
                self.getURL(from: url) { account in
                    completion(account)
                } failure: { error in
                    let ft4Error = FT4Error(error: error.localizedDescription)
                    failure(ft4Error)
                }
            case .failure(let error):
                let ft4Error = FT4Error(error: error.localizedDescription)
                failure(ft4Error)
            }
        }
    }
    
    private func getURL(from url: URL, completion: @escaping (FT4Account) -> (), failure: @escaping (Error) -> ()) {
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
    
    private func getAccount(withRequest request: URLRequest, completion: @escaping (FT4Account) -> (), failure: @escaping (Error) -> ()) {
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
                    let ft4Account = try self.jsonDecoder.decode(FT4Account.self, from: data)
                    self.setAccount(from: ft4Account)
                    
                    AppState.shared.needsReauthentication = false
                    AppState.shared.isSignedIn = true
                    
                    completion(ft4Account)
                } catch {
                    logft4(level: .tech_support, category: .info, initiator: activeAccount?.id, action: "bid_test", subaction: "tried_logging_in_failed", details: ["error": error.localizedDescription])
                    failure(error)
                }
            }
        }.resume()
    }
    
    func signInToMDM(username: String, completion: @escaping (FT4Account)->(), failure: @escaping (FT4Error) -> ()) {
        
        let input = MDMSignInInput(username: username)
        let payload = try! jsonEncoder.encode(input)
        
        apiRequest(account: nil, endpoint: .auth, payload: payload) { result in
            switch result {
            case .success(let ft4Response):
                switch ft4Response.statusCode {
                case 0, 400..<600:
                    if let error = try? self.jsonDecoder.decode(FT4Error.self, from: ft4Response.body) {
                        failure(error)
                    }
                    return
                default:
                    let account = try! self.jsonDecoder.decode(FT4Account.self, from: ft4Response.body)
                    
                    self.setAccount(from: account)
                    
                    AppState.shared.needsReauthentication = false
                    AppState.shared.isSignedIn = true
                    
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
                let error = FT4Error(error: err.localizedDescription)
                failure(error)
            }
        }
    }
    
    func signIn(useActiveDirectory: Bool, username: String, password: String, completion: @escaping (FT4Account)->(), failure: @escaping (FT4Error) -> ()) {
        
        let adInput = ADSignInInput(username: username, password: password)
        let input = SignInInput(username: username, password: password)
        
        var payload: Data
        
        if useActiveDirectory {
            payload = try! jsonEncoder.encode(adInput)
        } else {
            payload = try! jsonEncoder.encode(input)
        }
        
        apiRequest(account: nil, endpoint: .auth, payload: payload) { result in
            switch result {
            case .success(let ft4Response):
                switch ft4Response.statusCode {
                case 0, 400..<600:
                    if let error = try? self.jsonDecoder.decode(FT4Error.self, from: ft4Response.body) {
                        failure(error)
                    }
                    return
                default:
                    let account = try! self.jsonDecoder.decode(FT4Account.self, from: ft4Response.body)
                    
                    self.setAccount(from: account)
                    
                    AppState.shared.needsReauthentication = false
                    AppState.shared.isSignedIn = true
                    
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
                let error = FT4Error(error: err.localizedDescription)
                failure(error)
            }
        }
    }
    
    func setAccount(from account: FT4Account) {
        if activeAccount == nil {
            let acc = Account()
            acc.token = account.accessToken
            acc.cdAccount!.id = account.id
            acc.fullName = account.fullName
            acc.userName  = account.username
            
            activeAccount = acc
            
            AppState.shared.account = account
        } else {
            activeAccount!.token = account.accessToken
        }
    }
    
    func signOut(completion: @escaping () -> ()) {
        
        let input = SignOutInput()
        let payload = try! jsonEncoder.encode(input)
        
        apiRequest(account: activeAccount?.cdAccount, endpoint: .auth, payload: payload) { _ in
            completion()
        }
    }
    
    func verifyToken(token: String, completion: @escaping (FT4Account) -> (), failure: @escaping (FT4Error) -> ()) {
        
        guard connectionType != .none else { return }
        
        let payload = try! jsonEncoder.encode(VerifyTokenInput(token: token))
        
        apiRequest(account: activeAccount?.cdAccount, endpoint: .auth, payload: payload) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let ft4Response):
                switch ft4Response.statusCode {
                case 401:
                    do {
                        let ft4Error = try self.jsonDecoder.decode(FT4Error.self, from: ft4Response.body)
                        failure(ft4Error)
                    } catch {
                        print("Could not decode error: \(error.localizedDescription)")
                    }
                case 200:
                    do {
                        let ft4Account = try self.jsonDecoder.decode(FT4Account.self, from: ft4Response.body)
                        completion(ft4Account)
                    } catch {
                        print("Could not decode error: \(error.localizedDescription)")
                    }
                default:
                    break
                }
            case .failure(let error):
                let ft4Error = FT4Error(error: error.localizedDescription)
                failure(ft4Error)
                
            }
        }
    }
    
    func getTasks(input: GetTasksInput, completion: @escaping ([FT4Task]) -> (), failure: @escaping (FT4Error) -> ()) {
        let payload = try! jsonEncoder.encode(input)
        
        apiRequest(account: activeAccount?.cdAccount, endpoint: .api, payload: payload) { result in
            switch result {
            case .success(let ft4Response):
                switch ft4Response.statusCode {
                case 200..<300:
                    setUD(UserDefaultsKey.database, to: String(data: ft4Response.body, encoding: .utf8))
                    
                    do {
                        let tasks = try self.jsonDecoder.decode([FT4Task].self, from: ft4Response.body)
                        completion(tasks)
                    } catch {
                        let ft4Error = FT4Error(error: error.localizedDescription)
                        failure(ft4Error)
                    }
                default:
                    if let error = try? self.jsonDecoder.decode(FT4Error.self, from: ft4Response.body) {
                        failure(error)
                    }
                }
            case .failure(let error):
                let ft4Error = FT4Error(error: error.localizedDescription)
                failure(ft4Error)
                
            }
        }
    }
    
    func createExhibit(account: CDAccount?, exhibit: Exhibit, taskFieldId: String, completion: @escaping (CreateExhibitResponse)->(), failure: @escaping (FT4Error)->()) {
        
        let input = CreateExhibitInput(exhibitId: exhibit.id,
                                       taskfieldId: taskFieldId,
                                       duration: exhibit.duration,
                                       fileSize: exhibit.fileSize,
                                       mediaType: exhibit.type.rawValue + "/" + (exhibit.fileExtensions[exhibit.type] ?? ""),
                                       startedAt: exhibit.captureStartedAt!.ft4TimeStamp,
                                       deviceId: UDStr(UserDefaultsKey.deviceId))
        
        let payload = try! jsonEncoder.encode(input)
        
        apiRequest(account: account, endpoint: .api, payload: payload) { result in
            switch result {
            case .success(let ft4Response):
                
                if ft4Response.statusCode >= 200 && ft4Response.statusCode < 300 {
                    if let response = try? JSONDecoder().decode(CreateExhibitResponse.self, from: ft4Response.body) {
                        completion(response)
                    } else {
                        let error = try! JSONDecoder().decode(FT4Error.self, from: ft4Response.body)
                        failure(error)
                    }
                } else {
                    if let response = try? JSONDecoder().decode(FT4Error.self, from: ft4Response.body) {
                        failure(response)
                    }
                }
                
            case .failure(let error):
                let ft4Error = FT4Error(error: error.localizedDescription)
                failure(ft4Error)
            }
        }
    }
    
    func setEvent(account: CDAccount?, exhibit: Exhibit, completion: @escaping (FT4Response)->()) {
        // TODO: - Needs checksum and location
        
        let latitude = exhibit.cdExhibit?.gpsLatitude
        let longitude = exhibit.cdExhibit?.gpsLongitude
        
        
        let input = SetEventInput(eventId: UUID().uuidString, exhibitId: exhibit.id, type: "location", subtype: "start", source: "machine", fromTime: 0, toTime: 0, text: nil, language: nil, confidence: nil, entity: "location", entityId: UUID().uuidString, entityData: ["latitude" : latitude == nil ? nil : String(latitude!), "longitude" : longitude == nil ? nil : String(longitude!), "street_address" : exhibit.cdExhibit?.gpsStreetAddress, "postal_code" : exhibit.cdExhibit?.gpsPostalCode, "city" : exhibit.place, "region" : exhibit.cdExhibit?.gpsArea3 ?? exhibit.cdExhibit?.gpsArea4, "country" : exhibit.cdExhibit?.gpsCountry, "altitude" : String(exhibit.cdExhibit!.gpsAltitude), "hor_accuracy" : String(exhibit.cdExhibit!.gpsHorizontalAccuracy), "vert_accuracy" : String(exhibit.cdExhibit!.gpsVerticalAccuracy)])
        
        let payload = try! jsonEncoder.encode(input)
        
        apiRequest(account: account, endpoint: .api, payload: payload) { result in
            switch result {
            case .success(let ft4Response):
                completion(ft4Response)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
    
    func updateExhibit(account: CDAccount?, exhibit: Exhibit, completion: @escaping (FT4Response)->()) {
        // TODO: - Needs checksum and location
        
        let input = UpdateExhibitInput(exhibitId: exhibit.id,
                                       checksum: exhibit.getStoredCheckSum(),
                                       duration: exhibit.duration,
                                       fileSize: exhibit.fileSize,
                                       startedAt: exhibit.captureStartedAt!.ft4TimeStamp)
        
        let payload = try! jsonEncoder.encode(input)
        
        apiRequest(account: account, endpoint: .api, payload: payload) { result in
            switch result {
            case .success(let ft4Response):
                completion(ft4Response)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
    
    func discardExhibit(account: CDAccount?, exhibit: Exhibit, completion: @escaping (Int) -> (), failure: @escaping (FT4Error)->()) {
        
        let json: [String: Any] = ["action" : "discard_exhibit", "exhibit_id" : exhibit.id]
        let data = try! JSONSerialization.data(withJSONObject: json, options: .fragmentsAllowed)
        
        apiRequest(account: account, endpoint: .api, payload: data) { result in
            switch result {
            case .success(let ft4Response):
                if ft4Response.statusCode >= 200 && ft4Response.statusCode < 300 {
                    completion(ft4Response.statusCode)
                } else {
                    if let response = try? JSONDecoder().decode(FT4Error.self, from: ft4Response.body) {
                        failure(response)
                    }
                }
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
    
    func getExhibitStatus(exhibits: [Exhibit], completion: @escaping (FT4Response)->()) {
        
        let ids = exhibits.map({$0.id})
        
        let json:[String: Any] = ["action" : "get_exhibit_status", "exhibit_ids" : ids]
        
        let data = try! JSONSerialization.data(withJSONObject: json, options: .fragmentsAllowed)
        
        apiRequest(account: activeAccount?.cdAccount, endpoint: .api, payload: data) { result in
            switch result {
            case .success(let ft4Response):
                completion(ft4Response)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
    
    func submitTask(account: CDAccount?, task: Task, completion: @escaping (FT4Response)->(), failure: @escaping (FT4Error) -> ()) {
        
        let form = task.form!.withoutExhibits()
        
        do {
            let input = SubmitTaskInput(task: form)
            let payload = try self.jsonEncoder.encode(input)
            
            apiRequest(account: account, endpoint: .api, payload: payload) { result in
                switch result {
                case .success(let ft4Response):
                    if ft4Response.statusCode >= 200 && ft4Response.statusCode < 300 {
                        completion(ft4Response)
                    } else {
                        if let response = try? JSONDecoder().decode(FT4Error.self, from: ft4Response.body) {
                            failure(response)
                        }
                    }
                case .failure(let error):
                    let ft4Error = FT4Error(error: error.localizedDescription)
                    failure(ft4Error)
                    print(error.localizedDescription)
                }
            }
        } catch {
            let ft4Error = FT4Error(error: error.localizedDescription)
            failure(ft4Error)
            print(error.localizedDescription)
        }
    }
    
    func reauthenticate(using authMode: AuthMode) {
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
    
    func registerDevice(deviceToken: String? = nil) {
        
        guard let activeAccount = activeAccount else { return }
        
        var input = RegisterDeviceInput()
        if let deviceToken = deviceToken {
            input.identifier = deviceToken
        }
        let payload = try! self.jsonEncoder.encode(input)
        
        apiRequest(account: activeAccount.cdAccount, endpoint: .api, payload: payload) { _ in }
    }
    
    func getNotification(withId id: String, completion: @escaping (FT4Response)->(), failure: @escaping (FT4Error)->()) {
        
        let input = GetNotificationInput(notificationId: id)
        
        let payload = try! jsonEncoder.encode(input)
        apiRequest(account: activeAccount?.cdAccount, endpoint: .api, payload: payload) { result in
            switch result {
            case .success(let ft4Response):
                if ft4Response.statusCode >= 200 && ft4Response.statusCode < 300 {
                    completion(ft4Response)
                    return
                }
                
                if let response = try? JSONDecoder().decode(FT4Error.self, from: ft4Response.body) {
                    failure(response)
                }
            case .failure(let error):
                failure(FT4Error(error: error.localizedDescription))
            }
        }
    }
}
