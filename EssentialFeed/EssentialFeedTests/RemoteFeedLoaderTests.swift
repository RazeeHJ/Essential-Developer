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

    }

    class HTTPClient {
        var requestedURL: URL?
    }

    @Test
    func test_init_doesNotRequestDataFromURL()  {
        let client = HTTPClient()
        let _ = RemoteFeedLoader()

        XCTAssertNil(client.requestedURL)
    }

}
