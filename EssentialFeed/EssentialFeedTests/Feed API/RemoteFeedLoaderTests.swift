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
    private var sutTracker: MemoryLeakTracker<RemoteFeedLoader>?
    private var clientTracker: MemoryLeakTracker<HTTPClientSpy>?

    deinit {
        sutTracker?.verify()
        clientTracker?.verify()
    }

    @Test
    func test_init_doesNotRequestDataFromURL()  {
        let (_, client) = makeSUT()

        #expect(client.requests.isEmpty == true)
    }

    @Test
    func test_load_requestsDataFromURL() async throws {
        let url = anyURL()
        let (sut, client) = makeSUT(url: url, result: .success(anyValidResponse()))

        let _ = try await sut.load()
        #expect(client.requests.map { $0.url } == [url])
    }

    @Test
    func test_loadTwice_requestsDataFromURLTwice() async throws {
        let url = anyURL()
        let (sut, client) = makeSUT(url: url, result: .success(anyValidResponse()))

        let _ = try await sut.load()
        let _ = try await sut.load()

        #expect(client.requests.map { $0.url } == [url, url])
    }

    @Test
    func test_load_deliversErrorOnClientError() async throws {
        let clientError = NSError(domain: "Test", code: 0)
        let (sut, _) = makeSUT(result: .failure(clientError))

        await expect(sut, toThrowWith: RemoteFeedLoader.Error.connectivity)
    }

    @Test
    func test_load_deliversErrorOnNon200HTTPResponse() async throws {
        let samples = [199, 201, 300, 400, 500]

        for code in samples {
            let non200Response = (Data(), httpResponse(code: code))
            let (sut, _) = makeSUT(result: .success(non200Response))
            await expect(sut, toThrowWith: RemoteFeedLoader.Error.invalidData)
        }
    }

    @Test
    func test_load_deliversErrorOn200HTTPResponseWithInvalidJSON() async throws {
        let invalidJSON = Data("invalid json".utf8)
        let (sut, _) = makeSUT(
            result: .success((invalidJSON, anyValidHTTPResponse()))
        )
        await expect(sut, toThrowWith: RemoteFeedLoader.Error.invalidData)
    }

    @Test
    func test_load_deliversNoItemsOn200HTTPResponseWithEmptyJSONList() async throws {
        let (sut, _) = makeSUT(result: .success(anyValidResponse()))
        await expect(sut, toSucceedWith: [])
    }

    @Test
    func test_load_deliversItemsOn200HTTPResponseWithJSONItems() async throws {
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
        let (sut, _) = makeSUT(result: .success((json, anyValidHTTPResponse())))
        await expect(sut, toSucceedWith: items)
    }

    @Test
    func test_load_doesNotDeliverResultAfterInstanceHasBeenDeallocated() async throws {
        let json = makeItemsJSON([])

        var (sut, _): (RemoteFeedLoader?, HTTPClientSpy) = makeSUT(result: .success((json, anyValidHTTPResponse())))
        let capturedResults = try await sut?.load()
        sut = nil

        #expect(capturedResults == [])
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
        client: HTTPClientSpy
    ) {
        let client = HTTPClientSpy(result: result)
        let sut = RemoteFeedLoader(url: url, client: client)
        let sourceLocation = SourceLocation(fileID: #fileID, filePath: filePath, line: line, column: column)

        clientTracker = .init(instance: client, sourceLocation: sourceLocation)
        sutTracker = .init(instance: sut, sourceLocation: sourceLocation)

        return (sut, client)
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

struct MemoryLeakTracker<T: AnyObject> {
    weak var instance: T?
    var sourceLocation: SourceLocation

    func verify() {
        #expect(instance == nil, "Expected \(instance) to be deallocated. Potential memory leak", sourceLocation: sourceLocation)
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
