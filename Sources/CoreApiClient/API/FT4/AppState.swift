import Foundation

class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var isSignedIn = false
    var needsReauthentication: Bool = false {
        didSet(v) {
            setUD("needsReauthentication", to: v)
        }
    }
    @Published var account: FT4Account!
    @Published var server: Server!
    
    private init() {
        server = FT4Client.shared
    }
}
