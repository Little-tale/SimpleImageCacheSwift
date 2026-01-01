//
//  ETagCache.swift
//  ImageCashing_LittleTale
//
//  Created by Jae hyung Kim on 12/27/25.
//

import Foundation

/// ETag (optional)
public struct ETagCache: Sendable, Codable {
    
    /// 서버에서 준 ETag 키를 저장함
    public var eTag: String

    public var lastValidated: Date

    public init(eTag: String, lastValidated: Date = Date()) {
        self.eTag = eTag
        self.lastValidated = lastValidated
    }
}
