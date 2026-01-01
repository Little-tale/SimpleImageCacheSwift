//
//  CacheSerializer.swift
//  SimpleImageCachingSwift
//
//  Created by Jae hyung Kim on 12/27/25.
//

import Foundation

public protocol CacheSerializer: Sendable, Codable {
    /// orgin URL
    var originalUrlString: String { get }
    
    /// create Time
    var createdDate: Date { get }
    
    /// ETag (Optional)
    var eTag: ETagCache? { get set }
    
    /// LFU
    var accessCount: Int { get set }

    /// LRU
    var lastAccessTime: Date { get set }
}
