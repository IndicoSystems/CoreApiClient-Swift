import Foundation

@available(iOS 13.0, *)
class Upload: NSObject {
    var progressBlock: ((Float) -> ())?
    var resultBlock: (() -> ())?
    var failureBlock: ((String) -> ())?
    
    let exhibit: Exhibit
    let account: CDAccount?
    
    var offset = -1
    
    init(account: CDAccount?, exhibit: Exhibit) {
        self.account = account
        self.exhibit = exhibit
    }
    
    func cancel() {
    }
    
    func resume() {
    }
}

@available(iOS 13.0, *)
class FT4Upload: Upload, URLSessionTaskDelegate, URLSessionDataDelegate {
    let pre = "Indico-Upload-"
    var uploadSession: URLSession?
    var uploadTask: URLSessionDataTask?
    var lastProgressTime:Double = 0
    
    
    override init(account: CDAccount?, exhibit: Exhibit) {
        super.init(account: account, exhibit: exhibit)
        
        uploadSession = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
//        uploadSession?.configuration.shouldUseExtendedBackgroundIdleMode = true
    }
    
    override func cancel() {
        uploadTask?.cancel()
        uploadTask = nil
    }
    
    override func resume() {
        if (uploadTask != nil) { return }
        do {
            guard let url = URL(string: FT4Client.shared.host) else {
                logft4(level: .tech_coder, category: .info, initiator: account?.id ?? "", action: LogAction.upload.rawValue, subaction: "invalid_url", target: exhibit.id, targetType: "exhibit", details: ["error":"Could not create URL object from \(FT4Client.shared.host)"])
                return
            }
            var req = URLRequest(url: url.appendingPathComponent("upload/"))
            req.httpMethod = "POST"
            
            var chunk = Data()
            if (offset >= 0) {
                let fileHandle = try FileHandle(forReadingFrom: exhibit.localURL)
                try fileHandle.seek(toOffset: UInt64(offset))
                chunk = fileHandle.readData(ofLength: 8 * 1024 * 1024)
            }
            req.allHTTPHeaderFields = [
                pre+"Id"         : exhibit.id,
                pre+"Key"        : exhibit.uploadKey ?? "",
                pre+"Chunk-Size" : "\(chunk.count)",
                pre+"Offset"     : "\(offset)"
            ]
            if offset+chunk.count >= exhibit.fileSize { req.setValue("true", forHTTPHeaderField: pre+"Final") }
            
            uploadTask = uploadSession?.uploadTask(with: req, from: chunk)
            
            logft4(level: .tech_debug, category: .info, action: "upload", subaction: "upload_info", details: [
                "originalURL": uploadTask?.originalRequest?.url?.absoluteString ?? "",
                "currentURL": uploadTask?.currentRequest?.url?.absoluteString ?? "",
                "body_size" : "\(uploadTask?.countOfBytesExpectedToSend ?? -1)",
                "headers_sent" : "\(req.allHTTPHeaderFields ?? [:])"
            ])
            
            uploadTask?.resume()
            
            if offset < 0 {
                logft4(level: .tech_coder, category: .info, initiator: account?.id ?? "", action: LogAction.upload.rawValue, subaction: "requested_status", target: exhibit.id, targetType: "exhibit", details: nil)
            } else {
                logft4(level: .tech_coder, category: .read, initiator: account?.id ?? "", action: LogAction.upload.rawValue, subaction: "chunk_sent", target: exhibit.id, targetType: "exhibit", details: ["length":String(chunk.count), "from":String(offset)])
            }
        } catch {
            failureBlock?(error.localizedDescription)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil { failureBlock?(error!.localizedDescription) }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        uploadTask = nil
        var error = ""
        if let httpResponse = response as? HTTPURLResponse {
            if let offsetHeader = httpResponse.value(forHTTPHeaderField: pre+"Received") {
                offset = Int(offsetHeader) ?? -1
                
                if Date().timeIntervalSince1970 - lastProgressTime > 5 {
                    lastProgressTime = Date().timeIntervalSince1970
                }
                if offset>=0 { progressBlock?(Float(offset) / Float(exhibit.fileSize)) }
                
                if httpResponse.value(forHTTPHeaderField: pre+"Status") == "complete" {
                    if offset == exhibit.fileSize {
                        logft4(level: .custody_major, category: .change, initiator: account?.id ?? "", action: LogAction.upload.rawValue, subaction: "completed", target: exhibit.id, targetType: "exhibit", details: nil)
                        completionHandler(.allow)
                        resultBlock?()
                    } else {
                        error = "Upload completed with invalid upload offset: \(offset)"
                        logft4(level: .custody_major, category: .error, initiator: account?.id ?? "", action: LogAction.upload.rawValue, subaction: "completed", target: exhibit.id, targetType: "exhibit", details: ["error":error])
                    }
                } else if (0...exhibit.fileSize).contains(offset) {
                        completionHandler(.allow)
                        resume()
                } else { error = "Invalid upload offset: \(offset)" }
            } else { error = "Upload HTTP error \(httpResponse.statusCode)" }
        } else { error = "Unknown response" }
        
        if error.isEmpty { return }
        logft4(level: .tech_support, category: .error, initiator: account?.id ?? "", action: LogAction.upload.rawValue, subaction: "receive_response", target: exhibit.id, targetType: "exhibit", details: ["error":error])
        completionHandler(.cancel)
        failureBlock?(error)
    }
}
