//
//  File.swift
//  
//
//  Created by Константин Ланин on 19.06.2023.
//

import Foundation

public struct ApiResponse: Decodable {
    let statusCode: Int
    let body: Data
}

public struct ApiError: Decodable {
    let error: String
}
