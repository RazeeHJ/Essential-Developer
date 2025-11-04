//
//  URLSessionHTTPClientTests.swift
//  EssentialFeedTests
//
//  Created by Razee Hussein-Jamal on 2025-11-04.
//

import Testing
import EssentialFeed
import Foundation

class URLSessionHTTPClientTests {

    @Test
    func test_init_doesNotPerformGetRequest() async throws {
        let session = URLSessionSpy()
        #expect(session.receivedURLs.isEmpty)
    }
    
    @Test
    func test_getFromURL_createdDataTaskWithURL() async throws {
        let url = anyURL()
        let session = URLSessionSpy()
        let sut = URLSessionHTTPClient(session: session)

        try await sut.get(from: url)

        #expect(session.receivedURLs == [url])
    }

    // MARK: - Helpers

    private class URLSessionSpy: URLSessionProtocol {
        private let result: (Data, URLResponse) = (Data(), URLResponse())
        var receivedURLs = [URL]()

        func dataTask(with url: URL) async throws -> (Data, URLResponse) {
            receivedURLs.append(url)
            return result
        }
    }
}
