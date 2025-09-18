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
            HTTPClient.shared.requestedURL = URL(string: "https://a-url.com")
        }
    }

    class HTTPClient {
        static var shared = HTTPClient()

        private init() {}

        var requestedURL: URL?
    }

    @Test
    func test_init_doesNotRequestDataFromURL()  {
        let client = HTTPClient.shared
        let _ = RemoteFeedLoader()

        XCTAssertNil(client.requestedURL)
    }

    @Test
    func test_load_requestDataFromURL() {
        let client = HTTPClient.shared
        let sut = RemoteFeedLoader()

        sut.load()

        XCTAssertNotNil(client.requestedURL)
    }

}
