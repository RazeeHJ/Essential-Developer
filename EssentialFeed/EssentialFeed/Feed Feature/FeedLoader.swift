//
//  Copyright © Essential Developer. All rights reserved.
//

import Foundation

protocol FeedLoader {
    func load() async throws -> [FeedItem]
}
