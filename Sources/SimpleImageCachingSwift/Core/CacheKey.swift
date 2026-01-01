//
//  CacheKey.swift
//  SimpleImageCachingSwift
//
//  Created by Jae hyung Kim on 12/28/25.
//

import Foundation
import CryptoKit

public struct CacheKey: Hashable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(urlString: String, transformKey: String? = nil) {
        if let transformKey, !transformKey.isEmpty {
            self.rawValue = urlString + "#" + transformKey
        } else {
            self.rawValue = urlString
        }
    }

    public var filenameSafeHash: String {
        // Use a stable, filesystem-safe hash for disk filenames.
        // 디스크 파일명 해시
        let data = Data(rawValue.utf8)
        let digest = SHA256.hash(data: data)
        
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
