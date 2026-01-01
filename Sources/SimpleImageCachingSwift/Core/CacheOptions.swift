//
//  CacheOptions.swift
//  SimpleImageCachingSwift
//
//  Created by Jae hyung Kim on 12/28/25.
//

import Foundation

public enum CacheOptions: Sendable {
    case noCache
    case onlyDisk
    case onlyMemory
    case diskAndMemory
}
