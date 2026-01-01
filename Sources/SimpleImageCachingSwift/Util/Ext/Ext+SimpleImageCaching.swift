//
//  Ext+SimpleImageCaching.swift
//  SimpleImageCachingSwift
//
//  Created by Jae hyung Kim on 12/28/25.
//

import UIKit

@MainActor private var inFlightTaskKey: Void?

// MARK: - APIs
@MainActor
public extension SimpleImageCachingWrapper where Base: UIImageView {
    
    @discardableResult
    func setImage(
        urlString: String,
        placeholder: UIImage? = nil,
        priority: TaskPriority? = nil,
        options: [SimpleImageCachingOptions] = [.cacheOption(.diskAndMemory)]
    ) -> SimpleDownloadTask?  {
        guard let url = URL(string: urlString) else {
            base.image = placeholder
            return nil
        }
        
        return setImage(url: url, placeholder: placeholder, priority: priority, options: options)
    }
    
    @discardableResult
    func setImage(
        url: URL,
        placeholder: UIImage? = nil,
        priority: TaskPriority? = nil,
        options: [SimpleImageCachingOptions] = [.cacheOption(.diskAndMemory)]
    ) -> SimpleDownloadTask?  {
        // Cancellation of transfer request
        // 이전 요청 취소
        cancelInFlight()
        
        base.image = placeholder

        let parsed = SimpleCacheManager.parseOptions(options)
        let key = SimpleCacheManager.makeCacheKey(for: url, options: parsed)
        
        let task = Task(priority: priority) {
            var cachedEntry: CacheEntry<CacheMetadata>? = nil
            
            if parsed.cacheOption != .noCache {
                cachedEntry = await SimpleCacheManager.readCache(key: key, option: parsed.cacheOption)
                if let cachedEntry, let image = UIImage(data: cachedEntry.data) {
                    guard !Task.isCancelled, isCurrentKey(key) else { return }
                    await MainActor.run {
                        base.image = image
                    }
                }
            }
            
            await handleDownloading(url: url, key: key, cachedEntry: cachedEntry, options: parsed)
        }
        
        let returnTask = SimpleDownloadTask(task: task, key: key)
        setRetainedAssociatedObject(base, &inFlightTaskKey, returnTask)
        
        return returnTask
    }
}

// MARK: - Helpers

@MainActor
private extension SimpleImageCachingWrapper where Base: UIImageView {
    func handleDownloading(
        url: URL,
        key: CacheKey,
        cachedEntry: CacheEntry<CacheMetadata>? = nil,
        options: SimpleCacheManager.ParsedOptions
    ) async {
        do {
            let image = try await SimpleCacheManager.loadImage(
                url: url,
                key: key,
                options: options,
                cachedEntry: cachedEntry
            )

            guard !Task.isCancelled, isCurrentKey(key), let image else { return }
            await MainActor.run {
                base.image = image
            }
        } catch {
            // Ignore failures cus UI
        }
    }
}

@MainActor
private extension SimpleImageCachingWrapper where Base: UIImageView {
    /// 현재 요청된 이미지의 키 비교
    /// - Parameter key: 요청 키
    /// - Returns: 일치여부
    func isCurrentKey(_ key: CacheKey) -> Bool {
        guard let keyObj: SimpleDownloadTask = getAssociatedObject(base, &inFlightTaskKey) else {
            return false
        }
        return keyObj.key == key
    }
    
    func cancelInFlight() {
        if let task: SimpleDownloadTask = getAssociatedObject(base, &inFlightTaskKey) {
            task.cancel()
            SimpleCacheManager.downloader.cancel(task.key)
        }
        setRetainedAssociatedObject(base, &inFlightTaskKey, nil as SimpleDownloadTask?)
    }
}
