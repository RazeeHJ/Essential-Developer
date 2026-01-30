//
//  URLSessionHTTPClient.swift
//  EssentialFeed
//
//  Created by Razee Hussein-Jamal on 2025-11-04.
//

import Foundation

public class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public struct UnExpectedValuesRepresentation: Error {}

    public func get(from url: URL) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UnExpectedValuesRepresentation()
        }

        return (data, httpResponse)
    }
}
