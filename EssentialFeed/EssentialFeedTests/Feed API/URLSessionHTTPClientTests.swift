//
//  URLSessionHTTPClientTests.swift
//  EssentialFeedTests
//
//  Created by Razee Hussein-Jamal on 2025-11-04.
//

import Testing
import EssentialFeed
import Foundation

@Suite(.serialized)
class URLSessionHTTPClientTests {

    @Test
    func test_init_doesNotPerformGetRequest() async throws {
        URLProtocolStub.reset()

        defer { URLProtocolStub.reset() }

        var verifyLeaks: (() async -> Void) = {}

        do {
            let(_, v) = makeSUT()
            verifyLeaks = v
            #expect(URLProtocolStub.receivedRequests().isEmpty)
        }
        await verifyLeaks()
    }

    @Test
    func test_getFromURL_performsGETRequestWithURL() async throws {
        URLProtocolStub.reset()

        defer { URLProtocolStub.reset() }

        let url = anyURL()
        URLProtocolStub.stub(data: anyData(), response: anyValidHTTPResponse())

        var verifyLeaks: (() async -> Void) = {}

        do {
            let (sut, v) = makeSUT()
            verifyLeaks = v
            _ = try await sut.get(from: url)

            let request = try #require(URLProtocolStub.receivedRequests().first)
            #expect(request.url == url)
            #expect(request.httpMethod == "GET")
        }
        await verifyLeaks()
    }

    @Test
    func test_getFromURL_failsOnRequestError() async throws {
        URLProtocolStub.reset()

        defer { URLProtocolStub.reset() }

        let url = anyURL()
        let expectedError = NSError(domain: "any error", code: 1)
        URLProtocolStub.stub(data: nil, response: nil, error: expectedError)

        var verifyLeaks: (() async -> Void) = {}

        do {
            let (sut, v) = makeSUT()
            verifyLeaks = v

            let _ = try await sut.get(from: url)
            Issue.record("Expected to throw \(expectedError), but succeeded instead.")
        } catch {
            let error = error as NSError
            #expect(error.domain == expectedError.domain)
            #expect(error.code == expectedError.code)
        }
        await verifyLeaks()
    }

    // MARK: - Helpers

    final class URLProtocolStub: URLProtocol {
        struct Stub {
            let data: Data?
            let response: URLResponse?
            let error: Error?
        }

        private static var stub: Stub?
        private static var requests: [URLRequest] = []
        private static let lock = NSLock()

        // Single stub for “the next request(s)”
        static func stub(data: Data? = nil, response: URLResponse? = nil, error: Error? = nil) {
            lock.lock(); defer { lock.unlock() }
            stub = Stub(data: data, response: response, error: error)
        }

        static func reset() {
            lock.lock(); defer { lock.unlock() }
            stub = nil
            requests = []
        }

        static func receivedRequests() -> [URLRequest] {
            lock.lock(); defer { lock.unlock() }
            return requests
        }

        override class func canInit(with request: URLRequest) -> Bool { true }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            Self.lock.lock()
            Self.requests.append(request)
            Self.lock.unlock()

            guard let stub = Self.stub else {
                // Fail loudly if you forgot to stub — no silent network calls.
                client?.urlProtocol(self, didFailWithError: NSError(domain: "Missing stub", code: 0))
                client?.urlProtocolDidFinishLoading(self)
                return
            }

            if let response = stub.response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data = stub.data {
                client?.urlProtocol(self, didLoad: data)
            }
            if let error = stub.error {
                client?.urlProtocol(self, didFailWithError: error)
            }

            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }

    // MARK: - Helpers

    private func makeSUT(
        fileID: String = #fileID,
        filePath: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) -> (
        sut: URLSessionHTTPClient,
        verifyLeaks: () async -> Void
    ) {
        let sut = URLSessionHTTPClient(session: makeStubbedSession())
        let sourceLocation = SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column)

        let verifySUT = trackForMemoryLeaks(sut, sourceLocation: sourceLocation)

        let verifyLeaks = {
            await verifySUT()
        }

        return (sut, verifyLeaks)
    }

    private func makeStubbedSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: config)
    }
}

