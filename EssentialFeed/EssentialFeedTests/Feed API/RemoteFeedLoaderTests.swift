//
//  RemoteFeedLoaderTests.swift
//  EssentialFeedTests
//
//  Created by Razee Hussein-Jamal on 2025-09-18.
//

import Testing
import EssentialFeed
import Foundation

class RemoteFeedLoaderTests {
    @Test
    func test_init_doesNotRequestDataFromURL() async {
        var verifyLeaks: (() async -> Void) = {}

        do {
            let (_, client, v) = makeSUT()
            verifyLeaks = v

            #expect(client.requests.isEmpty == true)
        }
        await verifyLeaks()
    }

    @Test
    func test_load_requestsDataFromURL() async throws {
        var verifyLeaks: (() async -> Void) = {}
        let url = anyURL()

        do {
            let (sut, client, v) = makeSUT(url: url, result: .success(anyValidResponse()))
            verifyLeaks = v

            _ = try await sut.load()
            #expect(client.requests.map { $0.url } == [url])
        }
        await verifyLeaks()
    }

    @Test
    func test_loadTwice_requestsDataFromURLTwice() async throws {
        var verifyLeaks: (() async -> Void) = {}
        let url = anyURL()

        do {
            let (sut, client, v) = makeSUT(url: url, result: .success(anyValidResponse()))
            verifyLeaks = v

            _ = try await sut.load()
            _ = try await sut.load()

            #expect(client.requests.map { $0.url } == [url, url])
        }
        await verifyLeaks()
    }

    @Test
    func test_load_deliversErrorOnClientError() async throws {
        var verifyLeaks: (() async -> Void) = {}

        let clientError = NSError(domain: "Test", code: 0)
        do {
            let (sut, _, v) = makeSUT(result: .failure(clientError))
            verifyLeaks = v

            await expect(sut, toThrowWith: RemoteFeedLoader.Error.connectivity)
        }
        await verifyLeaks()
    }

    @Test
    func test_load_deliversErrorOnNon200HTTPResponse() async throws {
        var verifyLeaks: (() async -> Void) = {}

        let samples = [199, 201, 300, 400, 500]

        for code in samples {
            let non200Response = (Data(), httpResponse(code: code))
            do {
                let (sut, _, v) = makeSUT(result: .success(non200Response))
                verifyLeaks = v

                await expect(sut, toThrowWith: RemoteFeedLoader.Error.invalidData)
            }
            await verifyLeaks()
        }
    }

    @Test
    func test_load_deliversErrorOn200HTTPResponseWithInvalidJSON() async throws {
        var verifyLeaks: (() async -> Void) = {}

        let invalidJSON = Data("invalid json".utf8)
        do {
            let (sut, _, v) = makeSUT(result: .success((invalidJSON, anyValidHTTPResponse())))
            verifyLeaks = v

            await expect(sut, toThrowWith: RemoteFeedLoader.Error.invalidData)
        }
        await verifyLeaks()
    }

    @Test
    func test_load_deliversNoItemsOn200HTTPResponseWithEmptyJSONList() async throws {
        var verifyLeaks: (() async -> Void) = {}

        do {
            let (sut, _, v) = makeSUT(result: .success(anyValidResponse()))
            verifyLeaks = v

            await expect(sut, toSucceedWith: [])
        }
        await verifyLeaks()
    }

    @Test
    func test_load_deliversItemsOn200HTTPResponseWithJSONItems() async throws {
        var verifyLeaks: (() async -> Void) = {}

        let item1 = makeItem(
            id: UUID(),
            imageURL: URL(string: "http:\\a-url.com")!
        )

        let item2 = makeItem(
            id: UUID(),
            description: "a description",
            location: "a location",
            imageURL: URL(string: "http:\\another-url.com")!
        )

        let items = [item1.model, item2.model]
        let json = makeItemsJSON([item1.json, item2.json])
        do {
            let (sut, _, v) = makeSUT(result: .success((json, anyValidHTTPResponse())))
            verifyLeaks = v

            await expect(sut, toSucceedWith: items)
        }

        await verifyLeaks()
    }

    @Test
    func test_load_doesNotDeliverResultAfterInstanceHasBeenDeallocated() async throws {
        var verifyLeaks: (() async -> Void) = {}

        let json = makeItemsJSON([])

        do {
            var (sut, _, v): (RemoteFeedLoader?, HTTPClientSpy, () async -> Void) = makeSUT(result: .success((json, anyValidHTTPResponse())))
            verifyLeaks = v

            let capturedResults = try await sut?.load()
            sut = nil

            #expect(capturedResults == [])
        }

        await verifyLeaks()
    }

    // MARK - Helpers

    private func makeSUT(
        url: URL = URL(string: "https://a-url.com")!,
        result: Result<(Data, HTTPURLResponse), Error> = .success((
            Data(),
            HTTPURLResponse()
        )),
        fileID: String = #fileID,
        filePath: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) -> (
        sut: RemoteFeedLoader,
        client: HTTPClientSpy,
        verifyLeaks: () async -> Void
    ) {
        let client = HTTPClientSpy(result: result)
        let sut = RemoteFeedLoader(url: url, client: client)

        let sourceLocation = SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column)
        let verifySUT = trackForMemoryLeaks(sut, sourceLocation: sourceLocation)
        let verifyClient = trackForMemoryLeaks(client, sourceLocation: sourceLocation)

        let verifyLeaks = {
            await verifySUT()
            await verifyClient()
        }

        return (sut, client, verifyLeaks)
    }

    private func makeItem(id: UUID, description: String? = nil, location: String? = nil, imageURL: URL) -> (
        model: FeedItem, json: [String: Any]) {
            let item = FeedItem(
                id: id,
                description: description,
                location: location,
                imageURL: imageURL
            )

            let json = [
                "id": id.uuidString,
                "description": description,
                "location": location,
                "image": imageURL.absoluteString
            ].reduce(into: [String: Any]()) { (acc, e) in
                if let value = e.value { acc[e.key] = value }
            }

            return (item, json)
        }

    private func makeItemsJSON(_ items: [[String: Any]]) -> Data {
        let json = ["items": items]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    private func expect(
        _ sut: RemoteFeedLoader,
        toThrowWith expectedError: RemoteFeedLoader.Error,
        fileID: String = #fileID,
        filePath: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) async {
        let sourceLocation = SourceLocation(
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )

        do {
            let _ = try await sut.load()
            #expect(Bool(false), "Expected error: \(expectedError)", sourceLocation: sourceLocation)
        } catch {
            let error = error as? RemoteFeedLoader.Error
            print("Caught error type: \(type(of: error))")

            #expect(
                error == expectedError,
                sourceLocation: sourceLocation
            )
        }
    }

    private func expect(
        _ sut: RemoteFeedLoader,
        toSucceedWith expectedItems: [FeedItem],
        fileID: String = #fileID,
        filePath: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) async {
        do {
            let response = try await sut.load()
            #expect(response == expectedItems, sourceLocation: .init(
                fileID: fileID,
                filePath: filePath,
                line: line,
                column: column
            ))
        } catch {
            #expect(Bool(false),"Expected success, but got success",
                sourceLocation: .init(
                    fileID: fileID,
                    filePath: filePath,
                    line: line,
                    column: column
                )
            )
        }
    }

    private class HTTPClientSpy: HTTPClient {
        private(set) var requests = [URLRequest]()

        let result: Result<(Data, HTTPURLResponse), Error>

        init(result: Result<(Data, HTTPURLResponse), Error>) {
            self.result = result
        }

        func get(from url: URL) async throws -> (Data, HTTPURLResponse) {
            let request = URLRequest(url: url)
            requests.append(request)
            return try result.get()
        }
    }
}

func anyURL() -> URL {
    URL(string: "https://any-url.com")!
}

func anyData() -> Data {
    Data("any data".utf8)
}

func anyValidResponse() -> (Data, HTTPURLResponse) {
    (emptyItemsJSON(), anyValidHTTPResponse())
}

private func emptyItemsJSON() -> Data {
    Data("{\"items\": []}".utf8)
}

func anyValidHTTPResponse() -> HTTPURLResponse {
    httpResponse(code: 200)
}

func httpResponse(code: Int) -> HTTPURLResponse {
    let httpResponse = HTTPURLResponse(url: anyURL(), statusCode: code, httpVersion: nil, headerFields: nil)!
    return httpResponse
}


