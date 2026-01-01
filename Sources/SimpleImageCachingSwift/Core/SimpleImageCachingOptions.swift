//
//  SimpleImageCachingOptions.swift
//  SimpleImageCachingSwift
//
//  Created by Jae hyung Kim on 12/28/25.
//

import Foundation
import SwiftImageCompressor

public enum SimpleImageCachingOptions: Sendable {

    case addHeaders([String: String])
    
    case cacheOption(CacheOptions)
    
    case resize(
        type: SimpleImageType,
        targetMB: Double,
        maxDimension: CGFloat = 2048
    )
}

// MARK: ImageType SwiftImageCompressor Mapping
public enum SimpleImageType: Sendable {
    case png
    case jpeg
    
    var mapping: ImageType {
        switch self {
        case .png:
            return .png
        case .jpeg:
            return .jpeg
        }
    }
}
