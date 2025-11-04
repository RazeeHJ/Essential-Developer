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
        let session = URLSessionSpy(result: .success(anyValidResponse()))
        #expect(session.receivedURLs.isEmpty)
    }
    
    @Test
    func test_getFromURL_createdDataTaskWithURL() async throws {
        let url = anyURL()
        let session = URLSessionSpy(result: .success(anyValidResponse()))
        let sut = URLSessionHTTPClient(session: session)

        let _ = try await sut.get(from: url)

        #expect(session.receivedURLs == [url])
    }

    @Test
    func test_getFromURL_failsOnRequestError() async throws {
        let url = anyURL()
        let expectedError = NSError(domain: "any error", code: 1)
        let session = URLSessionSpy(result: .failure(expectedError))

        do {
            let result = try await session.dataTask(with: url)
        } catch {
            let error = error as NSError
            #expect(error == expectedError)
        }
    }

    // MARK: - Helpers

    private class URLSessionSpy: URLSessionProtocol {
        private let result: Result<(Data, URLResponse), Error>
        var receivedURLs = [URL]()

        init(
            result: Result<(Data, URLResponse), Error>,
            receivedURLs: [URL] = [URL]()
        ) {
            self.result = result
            self.receivedURLs = receivedURLs
        }

        func dataTask(with url: URL) async throws -> (Data, URLResponse) {
            receivedURLs.append(url)
            return try result.get()
        }
    }
}
