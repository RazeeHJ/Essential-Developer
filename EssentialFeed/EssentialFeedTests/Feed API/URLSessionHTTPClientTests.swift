//
//  URLSessionHTTPClientTests.swift
//  EssentialFeedTests
//
//  Created by Razee Hussein-Jamal on 2025-11-04.
//

import Testing
import EssentialFeed
import Foundation

@testable import EssentialFeed
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
        let expectedError = NSError(domain: "any error", code: 1)
        await resultErrorFor(data: nil, response: nil, error: expectedError, onFailure: { error in
            #expect(true)
            let error = error as NSError
            #expect(error.domain == expectedError.domain)
            #expect(error.code == expectedError.code)
        })
    }

    @Test
    func test_getFromURL_failsOnAllInvalidRepresentationCases() async throws {
        let anyURL = anyURL()
        let anyData = anyData()
        let anyError = anyNSError()
        let urlResponse = nonHTTPURLResponse()
        let anyHTTPURLResponse = anyHTTPURLResponse()

        await resultErrorFor(data: nil, response: nil, error: nil, onFailure: { error in
            #expect(true)
        })

        await resultErrorFor(data: nil, response: urlResponse, error: nil, onFailure: { error in
            #expect(true)
        })

        await resultErrorFor(data: anyData, response: nil, error: nil, onFailure: { error in
            #expect(true)
        })

        await resultErrorFor(data: anyData, response: nil, error: anyError, onFailure: { error in
            #expect(true)
        })

        await resultErrorFor(data: nil, response: urlResponse, error: anyError, onFailure: { error in
            #expect(true)
        })

        await resultErrorFor(data: nil, response: anyHTTPURLResponse, error: anyError, onFailure: { error in
            #expect(true)
        })

        await resultErrorFor(data: anyData, response: anyHTTPURLResponse, error: anyError, onFailure: { error in
            #expect(true)
        })
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
            let stub = Self.stub
            Self.requests.append(request)
            Self.lock.unlock()

            // If no stub configured at all -> fail loudly
            guard let stub else {
                client?.urlProtocol(self, didFailWithError: NSError(domain: "Missing stub", code: 0))
                client?.urlProtocolDidFinishLoading(self)
                return
            }

            // Prefer error if provided
            if let error = stub.error {
                client?.urlProtocol(self, didFailWithError: error)
                client?.urlProtocolDidFinishLoading(self)
                return
            }

            // All nil -> invalid (already handled in your version, keep it)
            if stub.data == nil, stub.response == nil, stub.error == nil {
                client?.urlProtocol(self, didFailWithError: URLSessionHTTPClient.UnExpectedValuesRepresentation())
                client?.urlProtocolDidFinishLoading(self)
                return
            }

            // Data without response is invalid in practice for URLSession.data(for:)
            if stub.data != nil, stub.response == nil {
                client?.urlProtocol(self, didFailWithError: URLSessionHTTPClient.UnExpectedValuesRepresentation())
                client?.urlProtocolDidFinishLoading(self)
                return
            }

            // Normal path: response (if any), then data (if any)
            if let response = stub.response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data = stub.data {
                client?.urlProtocol(self, didLoad: data)
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

    private func resultErrorFor(data: Data?, response: URLResponse?, error: Error?, fileID: String = #fileID, filePath: String = #filePath, line: Int = #line, column: Int = #column, onFailure: (Error) -> Void) async {

        URLProtocolStub.reset()

        defer { URLProtocolStub.reset() }

        let url = anyURL()
        URLProtocolStub.stub(data: data, response: response, error: error)

        var verifyLeaks: (() async -> Void) = {}

        do {
            let (sut, v) = makeSUT(fileID: fileID, filePath: filePath, line: line, column: column)
            verifyLeaks = v

            let _ = try await sut.get(from: url)
            Issue.record("Expected to throw \(error)}, but succeeded instead.")
        } catch {
            onFailure(error)
        }
        await verifyLeaks()
    }
}

