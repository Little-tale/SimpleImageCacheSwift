//
//  MemoryCacheStore.swift
//  SimpleImageCachingSwift
//
//  Created by Jae hyung Kim on 12/28/25.
//

import Foundation

public final class MemoryCacheStore: CacheStore, @unchecked Sendable {
    public typealias Metadata = CacheMetadata

    private final class EntryBox: NSObject {
        let entry: CacheEntry<CacheMetadata>

        init(entry: CacheEntry<CacheMetadata>) {
            self.entry = entry
        }
    }
    // MARK: - Properties
    
    private let cache: NSCache<NSString, EntryBox>

    
    // MARK: - Initialization
    
    public init(totalCostLimit: Int = 64 * 1024 * 1024) {
        self.cache = NSCache<NSString, EntryBox>()
        self.cache.totalCostLimit = totalCostLimit
    }
    
    
    // MARK: - APIs
    
    public func setTotalCostLimit(mb: Int) {
        self.cache.totalCostLimit = mb * 1024 * 1024
    }
    
    public func get(_ key: CacheKey) async -> CacheEntry<CacheMetadata>? {
        guard let box = cache.object(forKey: key.rawValue as NSString) else {
            return nil
        }
        return box.entry
    }

    @discardableResult
    public func set(_ entry: CacheEntry<CacheMetadata>, for key: CacheKey, cost: Int) async -> Int? {
        // NSCache handles eviction based on totalCostLimit.
        // totalCostLimit 기준으로 NSCache가 자동 제거.
        cache.setObject(EntryBox(entry: entry), forKey: key.rawValue as NSString, cost: cost)
        
        // Can't Count Removed Count...
        return nil
    }

    public func remove(_ key: CacheKey) async {
        cache.removeObject(forKey: key.rawValue as NSString)
    }

    public func clear() async {
        cache.removeAllObjects()
    }
    
    /// no-op from Memory 메모리는 대기할 작업이 없음
    public func synchronize() async {
            
    }
}
