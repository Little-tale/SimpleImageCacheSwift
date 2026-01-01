//
//  ImageDownLoaderError.swift
//  SimpleImageCachingSwift
//
//  Created by Jae hyung Kim on 12/28/25.
//

import Foundation

public enum ImageDownLoaderError: Error {
    case invalidURL
    case invalidResponse
    case invalidStatusCode(Int)
    case notModified
    case cancel
    case unknown
}
