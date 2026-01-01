//
//  File.swift
//  SimpleImageCachingSwift
//
//  Created by Jae hyung Kim on 12/30/25.
//

import Foundation

@MainActor
public final class SimpleDownloadTask: Sendable {
    
    let task: Task<Void, Never>
    let key: CacheKey
    
    init(task: Task<Void, Never>, key: CacheKey) {
        self.task = task
        self.key = key
    }
}

// MARK: APIs
public extension SimpleDownloadTask {
    func cancel() {
        task.cancel()
    }
}
