//
//  URLSessionHTTPClient.swift
//  EssentialFeed
//
//  Created by Razee Hussein-Jamal on 2025-11-04.
//

import Foundation

public protocol HTTPSession {
    func dataTask(with url: URL) async throws -> (Data, URLResponse)
}

public class URLSessionHTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func get(from url: URL) async throws -> (Data, URLResponse) {
        let (data, response) = try await session.data(from: url)
        return (data, response)
    }
}
