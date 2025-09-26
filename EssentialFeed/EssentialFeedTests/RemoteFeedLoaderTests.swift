//
//  RemoteFeedLoaderTests.swift
//  EssentialFeedTests
//
//  Created by Razee Hussein-Jamal on 2025-09-18.
//

import Testing
import XCTest
import EssentialFeed

struct RemoteFeedLoaderTests {

    @Test
    func test_init_doesNotRequestDataFromURL()  {
        let (_, client) = makeSUT()

        #expect(client.requestedURLs.isEmpty == true)
    }

    @Test
    func test_load_requestsDataFromURL() {
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
                client.complete(withStatusCode: code, at: index)
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
        var capturedResult = [RemoteFeedLoader.Result]()
        sut.load { capturedResult.append($0) }

        let emptyListJSON = Data("{\"items\": []}".utf8)
        client.complete(withStatusCode: 200, data: emptyListJSON)
        #expect(capturedResult == [.success([])])
    }

    // MARK - Helpers

    private func makeSUT(url: URL = URL(string: "https://a-url.com")!) -> (
        sut: RemoteFeedLoader,
        client: HTTPClientSpy
    ) {
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader(url: url, client: client)
        return (sut, client)
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

        func complete(withStatusCode code: Int, data: Data = Data(), at index: Int = 0) {
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
