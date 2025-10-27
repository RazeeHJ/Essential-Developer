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
    }

    @Test
    func test_init_doesNotRequestDataFromURL()  {
        let (_, client) = makeSUT()

        #expect(client.requestedURLs.isEmpty == true)
    }

    @Test
    func test_load_requestsDataFromURL() async throws {
        let url = URL(string: "https://a-given-url.com")!
        let (sut, client) = makeSUT(url: url)

        sut.load { _ in }
        #expect(client.requestedURLs == [url])
    }

    @Test
    func test_loadTwice_requestsDataFromURLTwice() {
        let url = URL(string: "https://a-given-url.com")!
        let (sut, client) = makeSUT(url: url)

        sut.load { _ in }
        sut.load { _ in }

        #expect(client.requestedURLs == [url, url])
    }

    @Test
    func test_load_deliversErrorOnClientError() {
        let (sut, client) = makeSUT()

        expect(sut, toCompleteWith: .failure(.connectivity)) {
            let clientError = NSError(domain: "Test", code: 0)
            client.complete(with: clientError)
        }
    }

    @Test
    func test_load_deliversErrorOnNon200HTTPResponse() {
        let (sut, client) = makeSUT()

        let samples = [199, 201, 300, 400, 500]
        samples.enumerated().forEach { index, code in
            expect(sut, toCompleteWith: .failure(.invalidData)) {
                let json = makeItemsJSON([])
                client.complete(withStatusCode: code, data: json, at: index)
            }
        }
    }

    @Test
    func test_load_deliversErrorOn200HTTPResponseWithInvalidJSON() {
        let (sut, client) = makeSUT()
        expect(sut, toCompleteWith: .failure(.invalidData)) {
            let invalidJSON = Data("invalid json".utf8)
            client.complete(withStatusCode: 200, data: invalidJSON)
        }
    }

    @Test
    func test_load_deliversNoItemsOn200HTTPResponseWithEmptyJSONList() {
        let (sut, client) = makeSUT()
        expect(sut, toCompleteWith: .success([])) {
            let emptyListJSON = makeItemsJSON([])
            client.complete(withStatusCode: 200, data: emptyListJSON)
        }
    }

    @Test
    func test_load_deliversItemsOn200HTTPResponseWithJSONItems() {
        let (sut, client) = makeSUT()
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
        expect(sut, toCompleteWith: .success(items)) {
            let json = makeItemsJSON([item1.json, item2.json])
            client.complete(withStatusCode: 200, data: json)
        }
    }


    // MARK - Helpers

    private func makeSUT(
        url: URL = URL(string: "https://a-url.com")!,
        fileID: String = #fileID,
        filePath: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) -> (
        sut: RemoteFeedLoader,
        client: HTTPClientSpy
    ) {
        let client = HTTPClientSpy()
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
        toCompleteWith error: RemoteFeedLoader.Result,
        when action: () -> Void,
        fileID: String = #fileID,
        filePath: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) {
        var capturedResult = [RemoteFeedLoader.Result]()
        sut.load { capturedResult.append($0) }

        action()

        let sourceLocation = SourceLocation(
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )

        #expect(capturedResult == [error], sourceLocation: sourceLocation)
    }

    private class HTTPClientSpy: HTTPClient {
        private var messages = [(url: URL, completion: (HTTPClientResult) -> Void)]()
        var requestedURLs: [URL] {
            return messages.map { $0.url }
        }

        func get(from url: URL, completion: @escaping (HTTPClientResult) -> Void) {
            messages.append((url, completion))
        }

        func complete(with error: Error, at index: Int = 0) {
            messages[index].completion(.failure(error))
        }

        func complete(withStatusCode code: Int, data: Data, at index: Int = 0) {
            let response = HTTPURLResponse(
                url: requestedURLs[index],
                statusCode: code,
                httpVersion: nil,
                headerFields: nil
            )!
            messages[index].completion(.success(data, response))
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
