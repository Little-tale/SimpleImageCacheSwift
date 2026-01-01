import XCTest
@testable import SimpleImageCachingSwift
import SwiftImageCompressor

@MainActor
final class SimpleCacheManagerTests: XCTestCase {
    
    /// # Test cache change after resizing
    ///
    /// - Test cache change after resizing
    /// - 리사이징후 캐시 변경 테스트
    func testCacheKeyIncludesTransformKeyWhenResizeOptionPresent() {
        let url = URL(string: "https://example.com/image.jpg")!
        let options: [SimpleImageCachingOptions] = [
            .cacheOption(.diskAndMemory),
            .resize(type: .jpeg, targetMB: 0.5, maxDimension: 512)
        ]

        let parsed = SimpleCacheManager.parseOptions(options)
        let key = SimpleCacheManager.makeCacheKey(for: url, options: parsed)

        XCTAssertTrue(key.rawValue.contains("#resize-"))
    }


    func testDiskCacheStorePruneOnSetHonorsDiskLimit() async {
        let baseURL = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let store = DiskCacheStore(baseURL: baseURL, limitMb: 1)
        let now = Date()

        let key1 = CacheKey("https://example.com/old.jpg")
        let meta1 = CacheMetadata(originalUrlString: key1.rawValue, lastAccessTime: now.addingTimeInterval(-1000))
        let entry1 = CacheEntry(data: Data(repeating: 0x01, count: 700_000), metadata: meta1)

        let key2 = CacheKey("https://example.com/new.jpg")
        let meta2 = CacheMetadata(originalUrlString: key2.rawValue, lastAccessTime: now.addingTimeInterval(-100))
        let entry2 = CacheEntry(data: Data(repeating: 0x02, count: 700_000), metadata: meta2)

        await store.set(entry1, for: key1, cost: entry1.data.count)
        await store.set(entry2, for: key2, cost: entry2.data.count)

        let result1 = await store.get(key1)
        let result2 = await store.get(key2)

        XCTAssertNil(result1)
        XCTAssertNotNil(result2)
    }

    private func makeTempDirectory() -> URL {
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dir = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makePNGData() -> Data {
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABJzQnCgAAAABJRU5ErkJggg=="
        return Data(base64Encoded: base64) ?? Data([0x00])
    }
}
