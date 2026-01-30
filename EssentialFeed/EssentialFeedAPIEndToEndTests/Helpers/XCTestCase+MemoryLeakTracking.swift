//
//  XCTestCase+MemoryLeakTracking.swift
//  EssentialFeed
//
//  Created by Razee Hussein-Jamal on 2026-01-30.
//

import Testing

func trackForMemoryLeaks<T: AnyObject>(
    _ instance: T,
    sourceLocation: SourceLocation
) -> () async -> Void {
    weak let weakInstance = instance
    return {
        await Task.yield()
        #expect(
            weakInstance == nil,
            "Expected instance to be deallocated. Potential memory leak",
            sourceLocation: sourceLocation
        )
    }
}
