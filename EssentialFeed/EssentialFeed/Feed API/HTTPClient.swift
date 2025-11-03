//
//  HTTPClient.swift
//  EssentialFeed
//
//  Created by Razee Hussein-Jamal on 2025-10-21.
//

import Foundation

public protocol HTTPClient {
    func get(from url: URL) async throws -> (Data, HTTPURLResponse)
}
