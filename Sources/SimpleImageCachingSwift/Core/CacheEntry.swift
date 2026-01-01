//
//  CacheEntry.swift
//  SimpleImageCachingSwift
//
//  Created by Jae hyung Kim on 12/28/25.
//

import Foundation

public struct CacheEntry<Metadata: CacheSerializer>: Sendable {
    public var data: Data
    public var metadata: Metadata

    public init(data: Data, metadata: Metadata) {
        self.data = data
        self.metadata = metadata
    }
}
