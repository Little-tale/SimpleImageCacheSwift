//
//  File.swift
//  ImageCashing_LittleTale
//
//  Created by Jae hyung Kim on 12/27/25.
//

import Foundation

public struct CacheMetadata: CacheSerializer {
    public let originalUrlString: String
    public let createdDate: Date
    public var eTag: ETagCache?
    public var accessCount: Int
    public var lastAccessTime: Date
    /// last-modified ServerResponse Header 마지막 수정 - 서버 응답 헤더
    public var lastModified: Date?

    public init(
        originalUrlString: String,
        createdDate: Date = Date(),
        eTag: ETagCache? = nil,
        accessCount: Int = 0,
        lastAccessTime: Date = Date(),
        lastModified: Date? = nil
    ) {
        self.originalUrlString = originalUrlString
        self.createdDate = createdDate
        self.eTag = eTag
        self.accessCount = accessCount
        self.lastAccessTime = lastAccessTime
        self.lastModified = lastModified
    }
    
    /// count up & access time update
    public mutating func touch() {
        accessCount += 1
        lastAccessTime = Date()
    }
}
