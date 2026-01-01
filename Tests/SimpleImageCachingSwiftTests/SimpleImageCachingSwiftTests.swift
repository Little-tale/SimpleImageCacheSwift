import XCTest
@testable import SimpleImageCachingSwift

@MainActor
final class SimpleImageCachingSwiftTests: XCTestCase {
    
    /// # Test for Get Set From Memory
    ///
    /// - Compare Memory Cache to Source
    /// - 메모리 캐시와 원본 비교
    func testMemoryCacheStoreSetGet() async {
        let store = MemoryCacheStore(totalCostLimit: 1024)
        let key = CacheKey("https://fastly.picsum.photos/id/237/200/300.jpg?hmac=TmmQSbShHz9CdQm0NkEjx1Dyh_Y984R9LpNrpvH2D_U")
        let metadata = CacheMetadata(originalUrlString: key.rawValue)
        let entry = CacheEntry(data: Data([0x01, 0x02, 0x03]), metadata: metadata)

        await store.set(entry, for: key, cost: entry.data.count)
        let fetched = await store.get(key)

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.data, entry.data)
        XCTAssertEqual(fetched?.metadata.originalUrlString, entry.metadata.originalUrlString)
    }
    
    /// # Test for Get Set From Disk
    ///
    /// - Compare Disk Cache to Source
    /// - 디스크 캐시와 원본 비교
    func testDiskCacheStoreSetGet() async {
        let baseURL = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let store = DiskCacheStore(baseURL: baseURL)
        let key = CacheKey("https://fastly.picsum.photos/id/237/200/300.jpg?hmac=TmmQSbShHz9CdQm0NkEjx1Dyh_Y984R9LpNrpvH2D_U")
        let metadata = CacheMetadata(originalUrlString: key.rawValue)
        let entry = CacheEntry(data: Data([0x0A, 0x0B]), metadata: metadata)

        await store.set(entry, for: key, cost: entry.data.count)
        let fetched = await store.get(key)

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.data, entry.data)
        XCTAssertEqual(fetched?.metadata.originalUrlString, entry.metadata.originalUrlString)
    }

    /// # Clear when capacity is full Test
    ///
    /// - clear when capacity is full Test
    /// - 용량이 가득 차게되면 지우기
    func testDiskCacheStorePruneBySize() async {
        let baseURL = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let store = DiskCacheStore(baseURL: baseURL)
        let now = Date()

        let key1 = CacheKey("https://fastly.picsum.photos/id/237/200/300.jpg?hmac=TmmQSbShHz9CdQm0NkEjx1Dyh_Y984R9LpNrpvH2D_U")
        let meta1 = CacheMetadata(originalUrlString: key1.rawValue, lastAccessTime: now.addingTimeInterval(-300))
        let entry1 = CacheEntry(data: Data(repeating: 0x01, count: makeMb(mb: 1)), metadata: meta1)

        let key2 = CacheKey("https://fastly.picsum.photos/id/1/5000/3333.jpg?hmac=Asv2DU3rA_5D1xSe22xZK47WEAN0wjWeFOhzd13ujW4")
        let meta2 = CacheMetadata(originalUrlString: key2.rawValue, lastAccessTime: now.addingTimeInterval(-200))
        let entry2 = CacheEntry(data: Data(repeating: 0x02, count: makeMb(mb: 2)), metadata: meta2)

        let key3 = CacheKey("https://fastly.picsum.photos/id/2/5000/3333.jpg?hmac=_KDkqQVttXw_nM-RyJfLImIbafFrqLsuGO5YuHqD-qQ")
        let meta3 = CacheMetadata(originalUrlString: key3.rawValue, lastAccessTime: now.addingTimeInterval(-100))
        
        let entry3 = CacheEntry(data: Data(repeating: 0x03, count: makeMb(mb: 3)), metadata: meta3)

        await store.set(entry1, for: key1, cost: entry1.data.count)
        await store.set(entry2, for: key2, cost: entry2.data.count)
        await store.set(entry3, for: key3, cost: entry3.data.count)

        await store.synchronize()
        await store.changeDiskLimit(mb: 3)

        let removed = await store.prune()
        
        XCTAssertEqual(removed, 2)
        
        let result1 = await store.get(key1)
        let result2 = await store.get(key2)
        let result3 = await store.get(key3)
        
        XCTAssertNil(result1)
        XCTAssertNil(result2)
        XCTAssertNotNil(result3)
    }

    
    /// # Test memory promotion when imported after disk-style cache
    ///
    /// - Test memory promotion when imported after disk-style cache
    /// - 디스크 방식 캐싱 후 적중시 메모리 승격 테스트
    func testDiskHitPromotesToMemory() async {
        let baseURL = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let memory = MemoryCacheStore(totalCostLimit: 1024 * 1024)
        let disk = DiskCacheStore(baseURL: baseURL)
        let coordinator = CacheCoordinator(memory: memory, disk: disk)

        let key = CacheKey("https://example.com/promote.jpg")
        let metadata = CacheMetadata(originalUrlString: key.rawValue)
        let entry = CacheEntry(data: Data([0xAA, 0xBB, 0xCC]), metadata: metadata)

        await disk.set(entry, for: key, cost: entry.data.count)
        let fetched = await coordinator.get(key)
        let memoryEntry = await memory.get(key)

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.data, entry.data)
        XCTAssertNotNil(memoryEntry)
        XCTAssertEqual(memoryEntry?.data, entry.data)
    }

    
    /// # TimeOver Remove Test from Disk Cache
    ///
    /// - Test if the cache is cleared from the disk over time.
    /// - 시간이 지나면 디스크에서 캐시가 지워지는지 테스트 합니다.
    func testDiskCacheStorePruneByAgeLimit() async {
        let baseURL = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let store = DiskCacheStore(baseURL: baseURL)
        await store.changeAgeLimit(to: 59) // Sec

        let key = CacheKey("https://example.com/old.jpg")
        
        let meta = CacheMetadata(
            originalUrlString: key.rawValue,
            lastAccessTime: Date().addingTimeInterval(-60)
        )
        
        let entry = CacheEntry(data: Data([0x01]), metadata: meta)

        let removed = await store.set(entry, for: key, cost: entry.data.count)
        XCTAssertEqual(removed, 1)
        
        let result = await store.get(key)
        XCTAssertNil(result)
    }
    
    /// # StoragePath Custom
    ///
    /// - StoragePath.custom returns the same URL
    /// - StoragePath.custom은 전달한 경로를 그대로 반환
    func testStoragePathCustomReturnsSameURL() {
        let customURL = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: customURL) }
        
        let path = StoragePath.custom(path: customURL)
        XCTAssertEqual(path.cacheDiskPath, customURL)
    }
    
    /// # Configure Custom Disk Path
    ///
    /// - Configure disk base path and verify files are written there
    /// - 디스크 경로 설정 후 해당 위치에 파일이 생성되는지 확인
    func testConfigureCustomDiskPathWritesToCustomDirectory() async {
        let customURL = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: customURL) }
        defer { SimpleCacheManager.configure(storagePath: .default) }
        
        SimpleCacheManager.configure(storagePath: .custom(path: customURL))
        
        let key = CacheKey("https://example.com/custom-path.jpg")
        let metadata = CacheMetadata(originalUrlString: key.rawValue)
        let entry = CacheEntry(data: Data([0x11, 0x22, 0x33]), metadata: metadata)
        
        await SimpleCacheManager.writeCache(
            entry: entry,
            key: key,
            cost: entry.data.count,
            option: .onlyDisk
        )
        
        let dataURL = customURL.appendingPathComponent(key.filenameSafeHash + ".data")
        let metaURL = customURL.appendingPathComponent(key.filenameSafeHash + ".meta.json")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: dataURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: metaURL.path))
    }

    private func makeTempDirectory() -> URL {
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dir = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private func makeMb(mb: Int) -> Int {
        return mb * 1024 * 1024
    }
}
