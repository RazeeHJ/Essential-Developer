//
//  URLSessionHTTPClient.swift
//  EssentialFeed
//
//  Created by Razee Hussein-Jamal on 2025-11-04.
//

import Foundation

public protocol URLSessionProtocol {
    func dataTask(with url: URL) async throws -> (Data, URLResponse)
}

public class URLSessionHTTPClient {
    private let session: URLSessionProtocol

    public init(session: URLSessionProtocol) {
        self.session = session
    }

    public func get(from url: URL) async throws {
        try await session.dataTask(with: url)
    }
}
