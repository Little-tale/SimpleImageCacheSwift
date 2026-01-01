//
//  DiskAccessRecorder.swift
//  SimpleImageCachingSwift
//
//  Created by Jae hyung Kim on 12/29/25.
//

import Foundation

///
/// 메모리 적중후 디스크 쓰기 정책입니다
/// Memory Hit -> afterTime -> Disk
actor DiskAccessRecorder {
    private let disk: DiskCacheStore
    private let debounceSeconds: TimeInterval
    private var pending: Set<CacheKey> = []
    private var flushTask: Task<Void, Never>?

    init(disk: DiskCacheStore, debounceSeconds: TimeInterval = 5.0) {
        self.disk = disk
        self.debounceSeconds = debounceSeconds
    }
}

// MARK: Internal

extension DiskAccessRecorder {
    
    /// # Record
    /// 메모리 적중 캐시를 임시에 넣어둡니다.
    ///
    /// - Parameter key: CacheKey
    func record(_ key: CacheKey) {
        pending.insert(key)
        scheduleFlushIfNeeded()
    }
    
    /// # Flush
    /// 메모리 적중 캐시들을 디스크에 반영합니다.
    ///
    func flush() async {
        cancelFlush()

        let keys = Array(pending)
        pending.removeAll()
        
        if !keys.isEmpty {
            await disk.touch(keys)
//            SimpleLog.cache.debug("\(#function) updated \(keys.count) keys")
        }
    }
    
    /// # Cancel Flush
    /// 플러시 작업을 취소합니다.
    func cancelFlush() {
        flushTask?.cancel()
        flushTask = nil
    }
}

// MARK: Private

extension DiskAccessRecorder {
    
    /// # If Needed ScheduleFlush
    /// 쌓아두었던 플러시 작업을 확인후 flush를 진행합니다.
    ///
    private func scheduleFlushIfNeeded() {
        guard flushTask == nil else { return }
        let delay = debounceSeconds
        
        flushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            if Task.isCancelled { return }
            
            await self?.flush()
        }
    }
}
