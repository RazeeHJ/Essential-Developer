//
//  EssentialFeedAPIEndToEndTests.swift
//  EssentialFeedAPIEndToEndTests
//
//  Created by Razee Hussein-Jamal on 2026-01-30.
//

import Testing
import Foundation
import EssentialFeed

struct EssentialFeedAPIEndToEndTests {

    @Test
    func test_endToEndTestServerGETResult_matchesFixedTestAccountData() async throws {
        let receivedResult = try await getFeedResult()
        #expect(receivedResult.feedItem.count == 8)
        #expect(receivedResult.feedItem[0] == expectedItem(at: 0))
        #expect(receivedResult.feedItem[1] == expectedItem(at: 1))
        #expect(receivedResult.feedItem[2] == expectedItem(at: 2))
        #expect(receivedResult.feedItem[3] == expectedItem(at: 3))
        #expect(receivedResult.feedItem[4] == expectedItem(at: 4))
        #expect(receivedResult.feedItem[5] == expectedItem(at: 5))
        #expect(receivedResult.feedItem[6] == expectedItem(at: 6))
        #expect(receivedResult.feedItem[7] == expectedItem(at: 7))
    }

    @Test
    func getFeedResult_doesNotLeak() async throws {
        let (items, checkLeaks) = try await getFeedResult()
        #expect(!items.isEmpty) 
        await checkLeaks()
    }

    private func getFeedResult(fileID: String = #fileID, filePath: String = #filePath, line: Int = #line, column: Int = #column) async throws -> (
        feedItem: [FeedItem],
        verifyLeaks: () async -> Void
    ) {
        let testServerURL = URL(string: "https://essentialdeveloper.com/feed-case-study/test-api/feed")!
        let client = URLSessionHTTPClient()
        let loader = RemoteFeedLoader(url: testServerURL, client: client)

        let sourceLocation = SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column)
        let verifyClient = trackForMemoryLeaks(client, sourceLocation: sourceLocation)
        let verifyLoader = trackForMemoryLeaks(loader, sourceLocation: sourceLocation)

        let verifyLeaks = {
            await verifyClient()
            await verifyLoader()
        }
        let receivedResult = try await loader.load()

        return (receivedResult, verifyLeaks)
    }

    // MARK: - Helpers
    private func expectedItem(at index: Int) -> FeedItem {
        return FeedItem(
            id: id(at: index),
            description: description(at: index),
            location: location(at: index),
            imageURL: imageURL(at: index)
        )
    }

    private func id(at index: Int) -> UUID {
        return UUID(uuidString: [
            "73A7F70C-75DA-4C2E-B5A3-EED40DC53AA6",
            "BA298A85-6275-48D3-8315-9C8F7C1CD109",
            "5A0D45B3-8E26-4385-8C5D-213E160A5E3C",
            "FF0ECFE2-2879-403F-8DBE-A83B4010B340",
            "DC97EF5E-2CC9-4905-A8AD-3C351C311001",
            "557D87F1-25D3-4D77-82E9-364B2ED9CB30",
            "A83284EF-C2DF-415D-AB73-2A9B8B04950B",
            "F79BD7F8-063F-46E2-8147-A67635C3BB01"
        ][index])!
    }

    private func description(at index: Int) -> String? {
        return [
            "Description 1",
            nil,
            "Description 3",
            nil,
            "Description 5",
            "Description 6",
            "Description 7",
            "Description 8"
        ][index]
    }

    private func location(at index: Int) -> String? {
        return [
            "Location 1",
            "Location 2",
            nil,
            nil,
            "Location 5",
            "Location 6",
            "Location 7",
            "Location 8"
        ][index]
    }

    private func imageURL(at index: Int) -> URL {
        URL(string: "https://url-\(index+1).com")!
    }
}
