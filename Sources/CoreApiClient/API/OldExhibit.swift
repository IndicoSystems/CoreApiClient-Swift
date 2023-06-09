import CoreLocation
import AVFoundation
import UIKit
import CryptoKit
import Contacts

@available(iOS 13.0, *)
class OldExhibit: NSObject {
    
    var cdExhibit: CDExhibit?
    var task: OldTask? { activeAccount?.tasks.first(where: { $0.id == cdExhibit?.task?.id }) }

    var id: String {
        cdExhibit!.id!
    }
    
    var uploadKey: String? {
        get { cdExhibit?.uploadKey }
        set(v) { cdExhibit?.uploadKey = v; cdSaveContext() }
    }

    enum ExhibitType: String { case unknown = "application", photo = "image", video = "video", audio = "audio" }
    var type: ExhibitType { ExhibitType(rawValue: cdExhibit?.type ?? "") ?? .unknown }

    var isRecordingExhibit = false

    var captureStartedAt: Date? { cdExhibit?.captureStartedAt }
    var createdAt: Date? { cdExhibit?.createdAt }
    var uploadedAt: Date? { cdExhibit?.uploadedAt }

    var archived: Bool { cdExhibit?.archived ?? false }
    
    var duration: Int {
        get { Int(cdExhibit!.duration) }
        set(v) { cdExhibit?.duration = Int32(v); cdSaveContext() }
    }
    
    var fileSize: Int {
        get { Int(cdExhibit!.fileSize) }
        set(v) { cdExhibit?.fileSize = Int64(v); cdSaveContext() }
    }

    var events: String {
        get { cdExhibit?.events ?? "" }
        set(v) {
            DispatchQueue.main.async {
                self.cdExhibit?.events = v
                cdSaveContext()
            }
        }
    }
    
    var displayName: String {
        var name = ""
        task?.form?.fields.forEach({
            if $0.exhibits.map({$0.id}).contains(id) {
                name = getTranslation(dict: $0.title)
            }
        })
        return name
    }
    
    var recognizedText: String {
        get { cdExhibit?.recognizedText ?? "" }
        set(v) { cdExhibit?.recognizedText = v; cdSaveContext() }
    }
    
    var isLocal:  Bool { fileMgr.fileExists(atPath: localURL.path) }
    
    let fileExtensions = [ExhibitType.photo:"jpeg", ExhibitType.video:videoFileExt, ExhibitType.audio:"mp4"]
    var localURL:  URL  { homeURL.appendingPathComponent("orig_\(id).\(fileExtensions[type] ?? "")") }

    var locationAccuracy: Double { cdExhibit!.gpsHorizontalAccuracy }
    var location: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: cdExhibit?.gpsLatitude ?? 0, longitude: cdExhibit?.gpsLongitude ?? 0) }
    var place: String? { cdExhibit?.gpsArea2 ?? cdExhibit?.gpsArea1 ?? cdExhibit?.gpsArea3 ?? cdExhibit?.gpsArea4 }
    
    func setCurrentLocation() {
        #warning("Cannot find 'locationProvider, allowsReverseGeocoding, worker' in scope")
//        if let loc = locationProvider.lastLocation {
//            cdExhibit?.gpsLatitude           = loc.coordinate.latitude
//            cdExhibit?.gpsLongitude          = loc.coordinate.longitude
//            cdExhibit?.gpsHorizontalAccuracy = loc.horizontalAccuracy
//            cdExhibit?.gpsVerticalAccuracy   = loc.verticalAccuracy
//            cdExhibit?.gpsAltitude           = loc.altitude
//
//            if allowsReverseGeocoding {
//                worker.add(.lookUpAddress, target: id)
//            } else {
//                worker.add(.setEvent, target: id)
//                NotificationCenter.default.post(name: .didChangeExhibit, object: self)
//            }
//        }
    }

    init(inTask: OldTask, ofType: ExhibitType? = nil, fromCDExhibit: CDExhibit? = nil, ft4Task: FT4Task? = nil, inTaskField: String? = nil) {
        super.init()
        cdExhibit = fromCDExhibit
        
        if let ft4Task = ft4Task {
            cdExhibit = CDExhibit(context: cdContext)
            cdExhibit?.id = ft4Task.id
            if let type = ofType { cdExhibit?.type = type.rawValue }
        } else if cdExhibit==nil {
            cdExhibit = CDExhibit(context: cdContext)
            cdExhibit?.id = UUID().uuidString
            if let type = ofType { cdExhibit?.type = type.rawValue }
            cdExhibit?.captureStartedAt = Date()
            cdSaveContext()
            inTask.changed = cdExhibit!.captureStartedAt!
            #warning("Cannot find 'worker' in scope")
//            worker.add(.submitTask, target: inTask.id)
        }
        
        if inTaskField != nil {
            cdExhibit?.taskFieldId = inTaskField
        }
        inTask.addExhibit(self)
        cdSaveContext()
    }
    
    var metas = [Meta]()

    func addMeta(_ meta: Meta) {
        metas.append(meta)
        cdExhibit?.addToMetas(meta.cdMeta!)
        cdSaveContext()
    }
    
    func deleteMeta(_ meta: Meta) {
        cdContext.delete(meta.cdMeta!)
        cdSaveContext()
        metas.removeAll { $0 === meta}
    }
    func getStoredCheckSum() -> String {
        guard let cdExhibit = cdExhibit else { return "" }
        return cdExhibit.localChecksum ?? ""
    }
    
    var fileHandle: FileHandle?
    
    func createCAFFile() {
        FileManager.default.createFile(atPath: localURL.path+".caf", contents: nil)
        fileHandle = FileHandle(forWritingAtPath: localURL.path+".caf")
        
        var headerData = Data()
        headerData.append(contentsOf: "caff".utf8)                      //mFileType         = "caff"
        headerData.append(contentsOf: toByteArray(UInt16(1)))           //mFileVersion      = 1
        headerData.append(contentsOf: toByteArray(UInt16(0)))           //mFileFlags        = 0
        headerData.append(contentsOf: "desc".utf8)                      //mChunkType        = "desc"
        headerData.append(contentsOf: toByteArray(Int64(32)))           //mChunkSize        = 32
        headerData.append(contentsOf: toByteArray(Float64(sampleRate))) //mSampleRate       = 44100
        headerData.append(contentsOf: "lpcm".utf8)                      //mFormatID         = "lpcm"
        headerData.append(contentsOf: toByteArray(UInt32(0)))           //mFormatFlags      = 0
        headerData.append(contentsOf: toByteArray(UInt32(2)))           //mBytesPerPacket   = 2
        headerData.append(contentsOf: toByteArray(UInt32(1)))           //mFramesPerPacket  = 1
        headerData.append(contentsOf: toByteArray(UInt32(1)))           //mChannelsPerFrame = 1
        headerData.append(contentsOf: toByteArray(UInt32(16)))          //mBitsPerChannel   = 16
        headerData.append(contentsOf: "data".utf8)                      //mChunkType        = "data"
        headerData.append(contentsOf: toByteArray(Int64(-1)))           //mChunkSize        = -1 (Determined by file size)
        headerData.append(contentsOf: toByteArray(UInt32(0)))           //mEditCount        = 0
        
        fileHandle?.write(headerData)
    }
    
    func write(_ data: Data) {
        fileHandle?.write(data)
    }
    
    func closeFile() {
        fileHandle?.closeFile()
    }
    
    func createReport() -> [String:String] {
        guard let cdExhibit = cdExhibit else { return [:] }
        return ["exhibit_id":         "\(cdExhibit.id ?? "nil")",
                "isRecordingExhibit": "\(isRecordingExhibit)",
                "isLocal":            "\(isLocal)",
                "filePath":           "\(localURL.path)",
                "localFileSize":      "\((try? fileMgr.attributesOfItem(atPath: localURL.path))?[.size] as? Int ?? -1)",
                "tmpCAFsize":         "\((try? fileMgr.attributesOfItem(atPath: localURL.path + ".caf"))?[.size] as? Int ?? -1)",
                "tmpMP4size":         "\((try? fileMgr.attributesOfItem(atPath: localURL.path + "."+videoFileExt))?[.size] as? Int ?? -1)",
                "localFileCreated":   "\((try? fileMgr.attributesOfItem(atPath: localURL.path))?[.creationDate] ?? "nil")",
                "events":             "\(events.count)",
                "discarded":          "\(cdExhibit.archived)",
                "captureStartedAt":   "\(cdExhibit.captureStartedAt?.description ?? "nil")",
                "localChecksum":      "\(cdExhibit.localChecksum ?? "nil")",
                "duration":           "\(cdExhibit.duration)",
                "fileSize":           "\(cdExhibit.fileSize)",
                "gpsHorAccuracy":     "\(cdExhibit.gpsHorizontalAccuracy)",
                "gpsLatitude":        "\(cdExhibit.gpsLatitude==0 ? 0 : 1)",
                "gpsLongitude":       "\(cdExhibit.gpsLongitude==0 ? 0 : 1)",
                "gpsCountry":         "\(min(cdExhibit.gpsCountry?.count ?? -1, 1))",
                "type":               "\(cdExhibit.type ?? "nil")",
                "uploadedAt":         "\(cdExhibit.uploadedAt?.description ?? "nil")",
                "taskID":             "\(cdExhibit.task?.id ?? "nil")",
                "upload":             "\(upload==nil ? "nil" : "Offset: \(upload!.offset)")",
                "status":             "\(cdExhibit.status ?? "nil")"]
    }

    func makeTimeline(width: CGFloat, height: CGFloat, includeMarks: Bool, foreground:UIColor, background:UIColor, completion: @escaping (UIImage)->()) {
        DispatchQueue.global(qos: .background).async {
            UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 2)
            defer { UIGraphicsEndImageContext() }
            guard let g = UIGraphicsGetCurrentContext() else { return }
            g.setFillColor(background.cgColor)
            g.fill(CGRect(origin: .zero, size: CGSize(width: width, height: height)))
            g.setStrokeColor(foreground.cgColor)
            g.setLineWidth(2)

            if self.isLocal {
                var points = [Float]()
                
                if self.type == .audio {
                    do{
                        let audioFile = try AVAudioFile(forReading: self.localURL)
                        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: 128) else { return }
                        
                        for i in 0..<Int(width/3) {
                            audioFile.framePosition = audioFile.length / Int64(width) * Int64(i*3)
                            try audioFile.read(into: buffer, frameCount: buffer.frameCapacity)
                            let samples = Array(UnsafeBufferPointer(start: buffer.floatChannelData?.pointee, count: Int(buffer.frameLength)))
                            points.append(sqrt(samples.map{$0*$0}.reduce(0,+) / Float(samples.count)))
                        }
                        let factor = Float(height) / 2 / (points.max() ?? 1) // * 0.95
                        for i in points.indices {
                            let amp = CGFloat(points[i] * factor + 0.5)
                            g.move(to: CGPoint(x: CGFloat(i*3), y: height/2 - amp))
                            g.addLine(to: CGPoint(x: CGFloat(i*3), y: height/2 + amp))
                            g.strokePath()
                        }
                    } catch { return }
                    
                } else if self.type == .video {
                    
                    do{
                        let sw = Date().timeIntervalSince1970

                        let videoFile = AVAsset(url: self.localURL)
                        guard let audioTrack = videoFile.tracks.filter({ $0.mediaType == .audio }).first else { return }

                        let totalDuration = videoFile.duration.seconds

                        var amps = [Float]()
                        
                        for i in 0..<Int(width/3) {
                            var sampleBuffer = Data()
                            let aOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [AVFormatIDKey : kAudioFormatLinearPCM, AVLinearPCMIsFloatKey : true, AVLinearPCMBitDepthKey : 32])
                            let aReader = try AVAssetReader(asset: videoFile)
                            aReader.add(aOutput)
                            let fromTime = totalDuration / Double(width) * Double(i*3)
                            aReader.timeRange = CMTimeRange(start: CMTime(seconds: fromTime, preferredTimescale: 44100), duration: CMTime(seconds: 1, preferredTimescale: 44100))
                            aReader.startReading()

                            while aReader.status == .reading {
                                guard let readSampleBuffer = aOutput.copyNextSampleBuffer(), let readBuffer = CMSampleBufferGetDataBuffer(readSampleBuffer) else { break }

                                var readBufferLength = 0
                                var readBufferPointer: UnsafeMutablePointer<Int8>?
                                CMBlockBufferGetDataPointer(readBuffer, atOffset: 0, lengthAtOffsetOut: &readBufferLength, totalLengthOut: nil, dataPointerOut: &readBufferPointer)
                                sampleBuffer.append(UnsafeBufferPointer(start: readBufferPointer, count: readBufferLength))
                                CMSampleBufferInvalidate(readSampleBuffer)
                            }
                            
                            let i16array = sampleBuffer.withUnsafeBytes {
                                Array($0.bindMemory(to: Float.self)).map(Float.init(floatLiteral:))
                            }
                            amps.append(sqrt( i16array.prefix(128).map{$0*$0}.reduce(0,+) / Float(i16array.count) ))
                        }

                        let factor = Float(height) / 2 / (amps.max() ?? 1) // * 0.95

                        for i in 0..<Int(width/3) {
                            let amp = CGFloat(amps[i] * factor + 0.5)
                            g.move(to: CGPoint(x: CGFloat(i*3)+0.5, y: height/2 - amp))
                            g.addLine(to: CGPoint(x: CGFloat(i*3)+0.5, y: height/2 + amp))
                            g.strokePath()
                        }

                        console("1: \(Int( (Date().timeIntervalSince1970-sw)*1000) )")

                    } catch { print(error); return }
                }
            }
            
            if includeMarks {
                #warning("Cannot find 'colYellow' in scope")
                //g.setStrokeColor(colYellow.cgColor)
                g.setLineWidth(2)
                let rawEvents = self.events.components(separatedBy: ";")
                
                for rE in rawEvents {
                    let f = rE.components(separatedBy: ",")
                    if f.count != 3 { continue }
                    ///
                    /*
                    if let eventType = BlobEventType(rawValue: f[0]) {
                        if eventType == .started {
                            if !first {
                                if let start = Int(f[2]) {
                                    var x = CGFloat(start) / CGFloat(self.duration) / 44.1 * width
                                    if self.type == .video {
                                        x = CGFloat(start) / CGFloat(self.duration/1000*30) * width
                                    }
                                    g.move(to: CGPoint(x: CGFloat(x+1), y: 0))
                                    g.addLine(to: CGPoint(x: CGFloat(x+1), y: height-1))
                                    g.strokePath()
                                }
                            }
                            first = false
                        }
                    }
                    */
                }
            }
            let img = UIGraphicsGetImageFromCurrentImageContext()!
            DispatchQueue.main.async { completion(img) } //Needed thread switch!!!
        }
    }
    
    var amplitudes:[Float] = [0]
    
    func getAmplitudes() {
        DispatchQueue.global(qos: .background).async {
            if self.type == .audio {
                do{
                    let audioFile = try AVAudioFile(forReading: self.localURL)
                    self.amplitudes = Array(repeating: 0, count: Int(audioFile.length)/sampleRate*10)
                    guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: 256) else { return }
                    
                    for i in 0..<self.amplitudes.count {
                        audioFile.framePosition = Int64(i*sampleRate/10)
                        try audioFile.read(into: buffer, frameCount: buffer.frameCapacity)
                        let samples = Array(UnsafeBufferPointer(start: buffer.floatChannelData?.pointee, count: Int(buffer.frameLength)))
                        self.amplitudes[i] = sqrt(samples.map{$0*$0}.reduce(0,+) / Float(samples.count))
                    }
                } catch { print(error); return }
            } else if self.type == .video {
                do{
                    let videoFile = AVAsset(url: self.localURL)
                    let aReader = try AVAssetReader(asset: videoFile)
                    
                    guard let audioTrack = videoFile.tracks.filter({ $0.mediaType == .audio }).first else { return }
                    let aOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [AVFormatIDKey : kAudioFormatLinearPCM])
                    aReader.add(aOutput)
                    aReader.startReading()
                    
                    var sampleBuffer = Data()
                    while aReader.status == .reading {
                        guard let readSampleBuffer = aOutput.copyNextSampleBuffer(), let readBuffer = CMSampleBufferGetDataBuffer(readSampleBuffer) else { break }
                        var readBufferLength = 0
                        var readBufferPointer: UnsafeMutablePointer<Int8>?
                        CMBlockBufferGetDataPointer(readBuffer, atOffset: 0, lengthAtOffsetOut: &readBufferLength, totalLengthOut: nil, dataPointerOut: &readBufferPointer)
                        sampleBuffer.append(UnsafeBufferPointer(start: readBufferPointer, count: readBufferLength))
                        CMSampleBufferInvalidate(readSampleBuffer)
                    }
                    
                    let i16array = sampleBuffer.withUnsafeBytes {
                        Array($0.bindMemory(to: Int16.self)).map(Int16.init(bigEndian:))
                    }
                    self.amplitudes = Array(repeating: 0, count: i16array.count/sampleRate*10)
                    
                    for x in 0..<i16array.count/sampleRate*10 {
                        let piece = Array(i16array[x*sampleRate/10..<min(x*sampleRate/10+sampleRate/10,i16array.count)])
                        let numberToReduce = piece.map{Float($0*$0)/32767/32767}
                        let sum = numberToReduce.reduce(0,+)
                        let number = sum / Float(piece.count)
                        self.amplitudes[x] = sqrt(number)
                    }
                } catch { print(error); return }
            }
        }
    }
    
    // MARK: - Job execution

    var readyForFinalizeExhibit: String? {
        if isRecordingExhibit { return "Exhibit is still recording" }
        if !fileMgr.fileExists(atPath: localURL.path+"."+([.video: videoFileExt, .audio: "caf"][type] ?? "")) { return "Complete" }

        return nil
    }

    func finalizeExhibit(job: CDJob) {
        let tmpExtension = [.video: videoFileExt, .audio: "caf"][type] ?? ""
        if type == .video {
            fileSize = Int((try? fileMgr.attributesOfItem(atPath: localURL.path+"."+tmpExtension))?[.size] as? UInt64 ?? 0)
            if fileSize==0 {
                logft4(level: .tech_support, category: .error, initiator: job.account?.id, action: "finalize_exhibit", subaction: "empty_temp_file", target: id, targetType: "exhibit", details: createReport())
                try? fileMgr.removeItem(atPath: localURL.path+"."+tmpExtension)
                #warning("Cannot find 'worker' in scope")
//                worker.complete(job)
            } else {
                do {
                    try fileMgr.moveItem(at: localURL.appendingPathExtension(tmpExtension), to: localURL)
                    
                    duration = Int(AVURLAsset(url: localURL).duration.seconds * 1000)
                    if duration == 0 {
                        logft4(level: .tech_support, category: .error, initiator: job.account?.id, action: "finalize_exhibit", subaction: "duration_is_0", target: id, targetType: "exhibit", details: createReport())
                    }
                    #warning("Cannot find 'worker, didChangeExhibit' in scope")
//                    worker.add(.uploadExhibit, target: id, account: job.account)
//                    worker.add(.createChecksum, target: id, account: job.account)
//                    worker.add(.verifyExhibit, target: id, account: job.account)
//                    worker.complete(job)
//                    NotificationCenter.default.post(name: .didChangeExhibit, object: self)
                } catch {
                    var exhibitReport = createReport()
                    exhibitReport["error"] = error.localizedDescription
                    logft4(level: .tech_support, category: .error, initiator: job.account?.id, action: "finalize_exhibit", subaction: "rename_temp_file", target: id, targetType: "exhibit", details: exhibitReport)
                    #warning("Cannot find 'worker' in scope")
//                    worker.fail(job, error: "Error finalizing video")
                }
            }
        } else if type == .audio {
            let totAudLen = ((try? fileMgr.attributesOfItem(atPath: localURL.path+".caf"))?[.size] as? UInt64 ?? 0) - 68 //CAF header size
            if totAudLen<=0 {
                logft4(level: .tech_support, category: .error, initiator: job.account?.id, action: "finalize_exhibit", subaction: "delete_empty_audio", target: id, targetType: "exhibit", details: createReport())
                try? fileMgr.removeItem(atPath: localURL.path+".caf")
                #warning("Cannot find 'worker' in scope")
//                worker.complete(job)
                return
            }
            
            duration = Int(totAudLen) / 2 * 1000 / sampleRate
            
            try? fileMgr.removeItem(atPath: localURL.path)
            try? fileMgr.removeItem(atPath: localURL.path + ".mp4")

            let asset = AVAsset.init(url: URL(fileURLWithPath: localURL.path+".caf"))
            let exportSession = AVAssetExportSession.init(asset: asset, presetName: AVAssetExportPresetMediumQuality)
            exportSession?.outputFileType = AVFileType.mp4
            exportSession?.outputURL = URL(fileURLWithPath: localURL.path + ".mp4")
            exportSession?.metadata = asset.metadata

            exportSession?.exportAsynchronously {
                if exportSession?.status == .completed {
                    DispatchQueue.main.async {
                        if UDInt(UserDefaultsKey.appInterrupted)==1 { setUD(UserDefaultsKey.appLaunches, to: 0) }
                        
                        do {
                            self.fileSize = try fileMgr.attributesOfItem(atPath: self.localURL.path+".mp4")[.size] as? Int ?? 0
                            try fileMgr.moveItem(atPath: self.localURL.path+".mp4", toPath: self.localURL.path)
                            
                            if self.duration>0 && self.fileSize>0 {
                                try fileMgr.removeItem(atPath: self.localURL.path+".caf")
                                  
                                  #warning("Cannot find 'worker' in scope")
//                                worker.add(.uploadExhibit, target: self.id, account: job.account)
//                                worker.add(.createChecksum, target: self.id, account: job.account)
//                                worker.add(.verifyExhibit, target: self.id, account: job.account)
//                                worker.complete(job)
//                                NotificationCenter.default.post(name: .didChangeExhibit, object: self)
                            }
                        } catch {
                            var exhibitReport = self.createReport()
                            exhibitReport["error"] = error.localizedDescription
                            logft4(level: .tech_support, category: .error, initiator: job.account?.id, action: "finalize_exhibit", subaction: "rename_temp_file", target: self.id, targetType: "exhibit", details: exhibitReport)
                            #warning("Cannot find 'worker' in scope")
//                            worker.fail(job, error: "Error finalizing audio")
                        }
                    }
                } else if exportSession!.status == .failed {
                    DispatchQueue.main.async {
                        var exhibitReport = self.createReport()
                        exhibitReport["error"] = exportSession?.error?.localizedDescription ?? ""
                        logft4(level: .tech_support, category: .error, initiator: job.account?.id, action: "finalize_exhibit", subaction: "export_audio", target: self.id, targetType: "exhibit", details: exhibitReport)
                        #warning("Cannot find 'worker' in scope")
//                        worker.fail(job, error: "Error finalizing audio")
                    }
                }
            }
        }
    }
    
    var readyForCreateChecksum: String? {
        if !isLocal { return "Complete" }
        return nil
    }

    func createChecksum(job: CDJob) {
        DispatchQueue.global(qos: .background).async {
            #warning("Cannot find 'SHA256' in scope")
//            var hasher = SHA256.init()
//            let stream = InputStream(fileAtPath: self.localURL.path)!
//            stream.open()
//            let bufferSize = 8192
//            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
//            while stream.hasBytesAvailable {
//                let read = stream.read(buffer, maxLength: bufferSize)
//                let bufferPointer = UnsafeRawBufferPointer(start: buffer, count: read)
//                hasher.update(bufferPointer: bufferPointer)
//            }
//            let hash = hasher.finalize().map { String(format: "%02hhx", $0) }.joined()
//            DispatchQueue.main.async {
//                self.cdExhibit?.localChecksum = hash
//                self.cdExhibit?.localChecksumType = "SHA_256"
//                cdSaveContext()
//                worker.add(.updateExhibit, target: self.id, account: job.account)
//                worker.complete(job)
//                logft4(level: .custody_minor, category: .change, initiator: job.account?.id, action: LogAction.verify.rawValue, subaction: "file_hashed", target: self.id, targetType: "exhibit", details: ["type":"sha256", "hash":hash])
//            }
        }
    }
    
    var readyForLookUpAddress: String? {
        if (cdExhibit?.gpsCountry ?? "") != ""                     { return "Complete" }
        if cdExhibit?.gpsLatitude==0 || cdExhibit?.gpsLongitude==0 { return "Complete" }
        if connectionType == .none                                 { return "No network" }
        return nil
    }
    
    let geocoder = CLGeocoder()
    
    func lookUpAddress(job: CDJob) {
        geocoder.reverseGeocodeLocation(CLLocation(latitude: location.latitude, longitude: location.longitude)) { placemark, error in
            if let p = placemark?.first, error == nil {
                self.cdExhibit?.gpsFullAddress   = p.postalAddress==nil ?"":CNPostalAddressFormatter().string(from: p.postalAddress!)
                self.cdExhibit?.gpsStreetAddress = p.name
                self.cdExhibit?.gpsPostalCode    = p.postalCode
                self.cdExhibit?.gpsArea1         = p.subLocality
                self.cdExhibit?.gpsArea2         = p.locality
                self.cdExhibit?.gpsArea3         = p.subAdministrativeArea
                self.cdExhibit?.gpsArea4         = p.administrativeArea
                self.cdExhibit?.gpsCountry       = p.country
                cdSaveContext()
                #warning("Cannot find 'worker' in scope")
//                worker.add(.setEvent, target: self.id, account: job.account)
//                NotificationCenter.default.post(name: .didChangeExhibit, object: self)
//                worker.complete(job)
            } else {
//                if (error as! CLError).code == .network {
//                    worker.postpone(job, because: error!.localizedDescription)
//                } else {
//                    worker.add(.setEvent, target: self.id, account: job.account)
//                    worker.complete(job)
//                }
            }
        }
        Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(lookUpAddressTimeout), userInfo: ["job":job], repeats: false)
    }
    
    @objc private func lookUpAddressTimeout(timer: Timer) {
        if !geocoder.isGeocoding { return }
        if let job = (timer.userInfo as? [String:Any])?["job"] as? CDJob {
            #warning("Cannot find 'worker' in scope")
//            worker.fail(job, error: "Timed out")
        }
        geocoder.cancelGeocode()
    }

    var readyForCreateExhibit: String? {
        #warning("Cannot find 'serverAvailable' in scope")
        //if !serverAvailable { return "Server unavailable" }
        return nil
    }
    
    func createExhibit(job: CDJob) {
        #warning("Cannot find 'worker' in scope")
//        if let taskFieldId = cdExhibit?.taskFieldId {
//            AppState.shared.server.createExhibit(account: job.account, exhibit: self, taskFieldId: taskFieldId) { response in
//                self.cdExhibit!.uploadKey = response.uploadKey
//                worker.complete(job)
//            } failure: { response in
//                worker.postpone(job, because: response.error)
//            }
//        } else {
//            worker.fail(job, error: "Not connected to a taskfield")
//        }
    }

    var readyForSetEvent: String? {
        #warning("Cannot find 'worker' in scope")
//        if !serverAvailable                 { return "Server unavailable" }
//        if worker.status(onJob: .createExhibit, forTarget: id) != .none { return "Exhibit isn't on server yet" }
        return nil
    }
    
    func setEvent(job: CDJob) {
        #warning("Cannot find 'worker' in scope")
//        AppState.shared.server.setEvent(account: job.account, exhibit: self) { response in
//            if response.statusCode >= 200 && response.statusCode < 300 {
//                worker.complete(job)
//            } else {
//                if let body = String(data: response.body, encoding: .utf8) {
//                    worker.fail(job, error: body)
//                }
//            }
//        }
    }
    
    var readyForUpdateExhibit: String? {
        #warning("Cannot find 'worker' in scope")
//        if !serverAvailable                 { return "Server unavailable" }
//        if worker.status(onJob: .createExhibit, forTarget: id) != .none { return "Exhibit isn't on server yet" }
        return nil
    }
    
    func updateExhibit(job: CDJob) {
        #warning("Cannot find 'worker' in scope")
//        AppState.shared.server.updateExhibit(account: job.account, exhibit: self) { response in
//            if response.statusCode >= 200 && response.statusCode < 300 {
//                worker.complete(job)
//            } else {
//                if let body = String(data: response.body, encoding: .utf8) {
//                    worker.fail(job, error: body)
//                }
//            }
//        }
    }
    
    var readyForArchiveExhibit: String? {
        #warning("Cannot find 'worker' in scope")
//        if !serverAvailable                 { return "Server unavailable" }
//        if worker.status(onJob: .createExhibit, forTarget: id) != .none { return "Exhibit isn't on server yet" }
        return nil
    }

    func discardExhibit(job: CDJob) {
        #warning("Cannot find 'worker' in scope")
//        AppState.shared.server.discardExhibit(account: job.account, exhibit: self) { response in
//            worker.complete(job)
//        } failure: { response in
//            worker.fail(job, error: response.error)
//        }
    }
    
    var readyForUploadExhibit: String? {
        #warning("Cannot find 'serverAvailable, settings, worker' in scope")
        if uploadedAt != nil { return "Complete" }
        //if !serverAvailable  { return "Server unavailable" }
        if uploadKey==nil    { return "Exhibit doesn't have an uploadKey" }

//        if connectionType == .cellular && !settings.cellularUploadCurrent {
//            return "Cellular upload limit setting prevents upload"
//        }
//
//        if worker.jobs.filter({ $0.status == Worker.Status.running.rawValue && $0.type == Worker.JobType.uploadExhibit.rawValue}).count >= 3 {
//            return "Max number of parallel uploads reached"
//        }

        return nil
    }
    
    var upload: Upload?
    var uploadProgress:Float = 0

    func uploadExhibit(job: CDJob) {
        if upload == nil {
            upload = FT4Upload(account: job.account, exhibit: self)
            
            upload?.progressBlock = { [unowned self] progress in
                self.uploadProgress = progress
                console("Upload progress: \(String(format: "%.2f%", progress*100)) Exhibit: \(self.id)")
            }
            #warning("Cannot find 'worker' in scope")
//            upload?.resultBlock = { [unowned self] in
//                self.uploadProgress = 1
//                self.cdExhibit!.uploadedAt = Date()
//                worker.complete(job)
//            }
//
//            upload?.failureBlock = { error in
//                worker.fail(job, error: error)
//            }
        }
        upload?.resume()
    }
    
    var readyForVerifyExhibit: String? {
        if cdExhibit!.status == "verified" || cdExhibit!.status == "safe_to_delete" {
            let account = cdExhibit?.task?.account
            logft4(level: .custody_major, category: .change, initiator: account?.id ?? "", action: LogAction.verify.rawValue, subaction: "completed", target: self.id, targetType: "exhibit", details: ["reason":"verified_by_server"])
            return "Complete"
        }
//        if cdExhibit!.status == "safe_to_delete" { return "Complete" }
        #warning("Cannot find 'worker' in scope")
//        if !serverAvailable    { return "Server unavailable" }
        return "Waiting for verification"
//        if worker.status(onJob: .uploadExhibit, forTarget: id) != .none { return "Exhibit not uploaded" }
//        return nil
    }
    
    func verifyExhibit(job: CDJob) {
    }
}
