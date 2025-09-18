//
//  RemoteFeedLoaderTests.swift
//  EssentialFeedTests
//
//  Created by Razee Hussein-Jamal on 2025-09-18.
//

import Testing
import XCTest

struct RemoteFeedLoaderTests {

    class RemoteFeedLoader {
        private let client: HTTPClient

        init(client: HTTPClient) {
            self.client = client
        }

        func load() {
            client.get(from: URL(string: "https://a-url.com")!)
        }
    }

    protocol HTTPClient {
        func get(from url: URL)
    }

    class HTTPClientSpy: HTTPClient {
        var requestedURL: URL?

        func get(from url: URL) {
            requestedURL = url
        }
    }

    @Test
    func test_init_doesNotRequestDataFromURL()  {
        let client = HTTPClientSpy()
        let _ = RemoteFeedLoader(client: client)

        XCTAssertNil(client.requestedURL)
    }

    @Test
    func test_load_requestDataFromURL() {
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader(client: client)

        sut.load()

        XCTAssertNotNil(client.requestedURL)
    }

}
