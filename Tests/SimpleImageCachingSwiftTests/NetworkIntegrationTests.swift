import XCTest
@testable import SimpleImageCachingSwift

@MainActor
final class NetworkIntegrationTests: XCTestCase {
    
    func testSICViewLoadPathUsesNetwork() async throws {
        let url = URL(string: "https://image.tmdb.org/t/p/w500/iN41Ccw4DctL8npfmYg1j5Tr1eb.jpg")!
        let options = SimpleCacheManager.parseOptions([.cacheOption(.noCache)])
        let key = SimpleCacheManager.makeCacheKey(for: url, options: options)

        let image = try await SimpleCacheManager.loadImage(
            url: url,
            key: key,
            options: options,
            cachedEntry: nil
        )

        XCTAssertNotNil(image)
    }

    func testImageDownLoaderFetchLiveURL() async throws {
        let url = URL(string: "https://image.tmdb.org/t/p/w500/iN41Ccw4DctL8npfmYg1j5Tr1eb.jpg")!
        let key = CacheKey(url.absoluteString)
        let downloader = ImageDownLoader()

        let entry = try await downloader.fetch(urlRequest: URLRequest(url: url), key: key)
        XCTAssertFalse(entry.data.isEmpty)

        let second = try await downloader.fetch(
            urlRequest: URLRequest(url: url),
            key: key,
            cachedEntry: entry
        )
        XCTAssertFalse(second.data.isEmpty)
    }
}
