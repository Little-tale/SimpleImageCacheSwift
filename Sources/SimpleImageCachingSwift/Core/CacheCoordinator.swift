//
//  CacheCoordinator.swift
//  SimpleImageCachingSwift
//
//  Created by Jae hyung Kim on 12/28/25.
//

import UIKit

public final class CacheCoordinator: @unchecked Sendable {
    private let memory: MemoryCacheStore
    private let disk: DiskCacheStore
    private let accessRecorder: DiskAccessRecorder
    private var notificationTokens: [NSObjectProtocol] = []

    /// Coordinates memory + disk caches with read-through behavior.
    /// 메모리/디스크 캐시를 묶어서 시나리오 흐름을 제공.
    public init(memory: MemoryCacheStore, disk: DiskCacheStore) {
        self.memory = memory
        self.disk = disk
        self.accessRecorder = DiskAccessRecorder(disk: disk)
        registerObservers()
    }
    
    private func registerObservers() {
        let center = NotificationCenter.default
        
        let backgroundToken = center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.flushDiskAccesses() }
        }
        
        let memoryToken = center.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.memory.clear() }
        }
        
        notificationTokens = [backgroundToken, memoryToken]
    }
}

// MARK: Get Set
extension CacheCoordinator {
    
    /// - Find it first in memory and if it's not, look it up on disk. If discovered, it will be promoted to memory.
    /// - 메모리 먼저 탐색 후 Disk에서 탐색 합니다. Disk에서 발견시 메모리로 승격합니다.
    /// - Parameter key: CacheKey
    /// - Returns: CacheEntry
    public func get(_ key: CacheKey) async -> CacheEntry<CacheMetadata>? {
        if let entry = await memory.get(key) {
            Task { await accessRecorder.record(key) }
            return entry
        }
        if let entry = await disk.get(key) {
            // Promote disk hit to memory for faster future reads.
            // 디스크 적중 -> 메모리로 승격
            await memory.set(entry, for: key, cost: entry.data.count)
            return entry
        }
        return nil
    }
    
    /// - Cache save to Memory, disk .
    /// - Memory, Disk 두곳에 저장합니다.
    ///
    /// - Parameters:
    ///   - entry: CacheEntry
    ///   - key: CacheKey
    ///   - cost: cost - 비용
    public func set(_ entry: CacheEntry<CacheMetadata>, for key: CacheKey, cost: Int) async {
        await memory.set(entry, for: key, cost: cost)
        await disk.set(entry, for: key, cost: cost)
    }
    
    /// if you use this Function Need To Call With checkDisk()
    public func changeDiskAgeLimit(_ limit: TimeInterval) async {
        await disk.changeAgeLimit(to: limit)
    }
    
    /// if you use this Function Need To Call With checkDisk()
    public func changeDiskSizeLimit(mb: Int) async {
        await disk.changeDiskLimit(mb: mb)
    }
    
    public func checkDisk() async {
        await disk.prune()
    }

    /// - Flush batched disk access updates (ex. app background)
    /// - 디스크 접근 기록들을 즉시 반영
    public func flushDiskAccesses() async {
        await accessRecorder.flush()
    }
    
    public func changeMemoryLimitCost(mb: Int) {
        memory.setTotalCostLimit(mb: mb)
    }
}

// MARK: Remove
extension CacheCoordinator {
    
    /// - 키에 해당하는 캐시를 Memory, Disk 에서 제거합니다.
    /// - Remove the cache corresponding to the key from memory, disk.
    ///
    /// - Parameter key: CacheKey
    public func remove(_ key: CacheKey) async {
        await memory.remove(key)
        await disk.remove(key)
    }
    
    public func removeOnlyMemory(_ key: CacheKey) async {
        await memory.remove(key)
    }
    
    public func removeOnlyAllMemory() async {
        await memory.clear()
    }
    
    public func removeOnlyDisk(_ key: CacheKey) async {
        await disk.remove(key)
    }
    
    /// - All Cache remove to Memory, disk
    /// - Memory, Disk 캐시 전체 삭제
    public func clear() async {
        await memory.clear()
        await disk.clear()
    }
    
    public func clearOnlyMemory() async {
        await memory.clear()
    }
    
    public func clearOnlyDisk() async {
        await disk.clear()
    }
}
