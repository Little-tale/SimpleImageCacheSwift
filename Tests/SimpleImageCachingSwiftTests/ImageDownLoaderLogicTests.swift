import XCTest
@testable import SimpleImageCachingSwift

final class ImageDownLoaderLogicTests: XCTestCase {

    private func makePNGData() -> Data {
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABJzQnCgAAAABJRU5ErkJggg=="
        return Data(base64Encoded: base64) ?? Data([0x00])
    }

    
    /// # ETag, last-modified Test
    func testBuildRequestAddsETagAndLastModified() {
        let downloader = ImageDownLoader()
        let url = URL(string: "https://example.com/a.jpg")!
        let key = CacheKey(url.absoluteString)
        let lastModified = Date(timeIntervalSince1970: 0)

        var metadata = CacheMetadata(originalUrlString: key.rawValue)
        metadata.eTag = ETagCache(eTag: "\"v1\"")
        metadata.lastModified = lastModified

        let entry = CacheEntry(data: makePNGData(), metadata: metadata)
        let request = URLRequest(url: url)

        let updated = downloader.buildRequest(urlRequest: request, cachedEntry: entry)
        XCTAssertEqual(updated.value(forHTTPHeaderField: "If-None-Match"), "\"v1\"")

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        let expected = formatter.string(from: lastModified)
        XCTAssertEqual(updated.value(forHTTPHeaderField: "If-Modified-Since"), expected)
    }

    /// # 304 Status Code Test
    func testProcessResponseReturnsCachedEntryOn304() throws {
        let downloader = ImageDownLoader()
        let url = URL(string: "https://example.com/b.jpg")!
        let key = CacheKey(url.absoluteString)

        var metadata = CacheMetadata(originalUrlString: key.rawValue)
        metadata.eTag = ETagCache(eTag: "\"v1\"")
        let cached = CacheEntry(data: makePNGData(), metadata: metadata)

        let response = HTTPURLResponse(url: url, statusCode: 304, httpVersion: nil, headerFields: [:])!
        let result = try downloader.processResponse(
            url: url,
            response: response,
            data: Data(),
            cachedEntry: cached
        )

        XCTAssertEqual(result.data, cached.data)
        XCTAssertEqual(result.metadata.eTag?.eTag, "\"v1\"")
        XCTAssertEqual(result.metadata.accessCount, 1)
    }

    /// # 200 Status Code Test
    func testProcessResponseSetsETagAndLastModifiedOn200() throws {
        let downloader = ImageDownLoader()
        let url = URL(string: "https://example.com/c.jpg")!
        let _ = CacheKey(url.absoluteString)
        let data = makePNGData()

        let lastModified = "Mon, 29 Dec 2025 12:00:00 GMT"
        let headers = [
            "ETag": "\"v2\"",
            "Last-Modified": lastModified
        ]
        
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers)!

        let result = try downloader.processResponse(
            url: url,
            response: response,
            data: data,
            cachedEntry: nil
        )

        XCTAssertEqual(result.metadata.eTag?.eTag, "\"v2\"")
        XCTAssertNotNil(result.metadata.lastModified)
    }
}
