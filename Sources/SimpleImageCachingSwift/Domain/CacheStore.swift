//
//  CacheStore.swift
//  SimpleImageCachingSwift
//
//  Created by Jae hyung Kim on 12/28/25.
//

import Foundation

public protocol CacheStore: Sendable {
    associatedtype Metadata: CacheSerializer

    /// Async-first cache access; implementations should be thread-safe.
    /// 비동기 우선 캐시 접근이며 구현체는 스레드 안전해야 함.
    func get(_ key: CacheKey) async -> CacheEntry<Metadata>?

    /// Async write; best-effort for disk caches.
    /// 비동기 쓰기이며 디스크 캐시는 실패 무시(best-effort) 가능.
    @discardableResult
    func set(_ entry: CacheEntry<Metadata>, for key: CacheKey, cost: Int) async -> Int?

    /// Async remove.
    /// 비동기 제거.
    func remove(_ key: CacheKey) async

    /// Async clear.
    /// 비동기 초기화.
    func clear() async

    /// Useful on tests/shutdown; memory can be no-op.
    /// 테스트/종료 시점 등에 유용. 메모리는 no-op 가능.
    func synchronize() async
}
