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
        func load() {
            HTTPClient.shared.get(from: URL(string: "https://a-url.com")!)
        }
    }

    class HTTPClient {
        static var shared = HTTPClient()

        func get(from url: URL) {}
    }

    class HTTPClientSpy: HTTPClient {
        var requestedURL: URL?

        override func get(from url: URL) {
            requestedURL = url
        }
    }

    @Test
    func test_init_doesNotRequestDataFromURL()  {
        let client = HTTPClientSpy()
        let _ = RemoteFeedLoader()

        XCTAssertNil(client.requestedURL)
    }

    @Test
    func test_load_requestDataFromURL() {
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader()

        sut.load()

        XCTAssertNotNil(client.requestedURL)
    }

}
