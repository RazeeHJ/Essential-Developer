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
        private let url: URL

        init(url: URL, client: HTTPClient) {
            self.url = url
            self.client = client
        }

        func load() {
            client.get(from: url)
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
        let url = URL(string: "https://a-url.com")!
        let _ = RemoteFeedLoader(url: url, client: client)

        XCTAssertNil(client.requestedURL)
    }

    @Test
    func test_load_requestDataFromURL() {
        let client = HTTPClientSpy()
        let url = URL(string: "https://a-given-url.com")!
        let sut = RemoteFeedLoader(url: url, client: client)

        sut.load()

        XCTAssertEqual(client.requestedURL, url)
    }

}
