//
//  RemoteFeedLoader.swift
//  EssentialFeed
//
//  Created by Razee Hussein-Jamal on 2025-09-19.
//

import Foundation

public final class RemoteFeedLoader: FeedLoader {
    private let url: URL
    private let client: HTTPClient

    public enum Error: Swift.Error {
        case connectivity
        case invalidData
    }

    public init(url: URL, client: HTTPClient) {
        self.url = url
        self.client = client
    }
    
    public func load() async throws -> [FeedItem] {
        guard let (data, response) = try? await client.get(from: url) else {
            throw Error.connectivity
        }
        return try FeedItemsMapper.map(data, response)
    }
}



