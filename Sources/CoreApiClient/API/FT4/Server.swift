//
//  File.swift
//  
//
//  Created by Константин Ланин on 05.05.2023.
//

import Foundation

protocol Server {
    func getInfo(urlString: String, completion: @escaping (Result<ServerInfo, Error>) -> ())
    func signIn(useActiveDirectory: Bool, username: String, password: String, completion: @escaping (FT4Account)->(), failure: @escaping (FT4Error) -> ())
    func signInToAAD(username: String, prompt: String?, completion: @escaping (Result<URL, Error>) -> ())
    func signOut(completion: @escaping () -> ())
    func signInToMDM(username: String, completion: @escaping (FT4Account)->(), failure: @escaping (FT4Error) -> ())
    func signInWithBid(completion: @escaping (FT4Account)->(), failure: @escaping (FT4Error) -> ())
    func verifyToken(token: String, completion: @escaping (FT4Account) -> (), failure: @escaping (FT4Error) -> ())
    func getTasks(input: GetTasksInput, completion: @escaping ([FT4Task]) -> (), failure: @escaping (FT4Error) -> ())
    func createExhibit(account: CDAccount?, exhibit: Exhibit, taskFieldId: String, completion: @escaping (CreateExhibitResponse)->(), failure: @escaping (FT4Error)->())
    func updateExhibit(account: CDAccount?, exhibit: Exhibit, completion: @escaping (FT4Response)->())
    func discardExhibit(account: CDAccount?, exhibit: Exhibit, completion: @escaping (Int) -> (), failure: @escaping (FT4Error)->())
    func submitTask(account: CDAccount?, task: Task, completion: @escaping (FT4Response)->(), failure: @escaping (FT4Error)->())
    func getExhibitStatus(exhibits: [Exhibit], completion: @escaping (FT4Response)->())
    func setEvent(account: CDAccount?, exhibit: Exhibit, completion: @escaping (FT4Response)->())
    func reauthenticate(using authMode: AuthMode)
    func registerDevice(deviceToken: String?)
    func getNotification(withId id: String, completion: @escaping (FT4Response)->(), failure: @escaping (FT4Error)->())
}

//extension Server {
//    func getInfo(from host: String, completion: @escaping (Result<ServerInfo, Error>) -> ()) {
//        let url = URL(string: "https://\(host)/info/")!
//        URLSession.shared.dataTask(with: url) { data, response, error in
//            if let err = error {
//                completion(.failure(err))
//            }
//
//            if let data = data {
//                do {
//                    let jsonDecoder = JSONDecoder()
//                    jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
//                    let serverInfo = try jsonDecoder.decode(ServerInfo.self, from: data)
//                    completion(.success(serverInfo))
//                } catch {
//                    completion(.failure(error))
//                }
//            }
//        }.resume()
//    }
//}
