//
//  SimpleCacheManager.swift
//  SimpleImageCachingSwift
//
//  Created by Jae hyung Kim on 12/29/25.
//

import UIKit
import SwiftImageCompressor

@MainActor
public enum SimpleCacheManager {
    
    // MARK: - Properties
    
    /// MemoryStore
    private static var memory = MemoryCacheStore()
    /// DiskStore
    private static var disk = DiskCacheStore(baseURL: defaultDiskURL)
    /// Memory + Disk Coordinator
    public static var coordinator = CacheCoordinator(memory: memory, disk: disk)
    /// ImageDownLoader
    internal static let downloader = ImageDownLoader()
    
    private static var defaultDiskURL: URL {
        StoragePath.default.cacheDiskPath ?? FileManager.default.temporaryDirectory
    }

    struct ParsedOptions {
        var headers: [String: String]
        var cacheOption: CacheOptions
        var resize: ResizeOptions?
        var transformKey: String?
    }

    struct ResizeOptions {
        let type: ImageType
        let targetMB: Double
        let maxDimension: CGFloat
    }
}

// MARK: - Configuration
public extension SimpleCacheManager {
    
    /// Configure disk cache storage location.
    /// 앱 시작 시 한 번 호출하는 것을 권장합니다.
    static func configure(storagePath: StoragePath) {
        let baseURL = storagePath.cacheDiskPath ?? defaultDiskURL
        disk = DiskCacheStore(baseURL: baseURL)
        coordinator = CacheCoordinator(memory: memory, disk: disk)
    }
}

// MARK: - internal
extension SimpleCacheManager {

    /// - Reflects the parsed options.
    /// - 파싱한 옵션들을 반영합니다.
    ///
    /// - Parameter options: options [SimpleImageCachingOptions]
    /// - Returns: ParsedOptions
    internal static func parseOptions(_ options: [SimpleImageCachingOptions]) -> ParsedOptions {
        var headers: [String: String] = [:]
        var cacheOption: CacheOptions = .diskAndMemory
        var resize: ResizeOptions?
        var transformKey: String?

        for option in options {
            switch option {
            case .addHeaders(let newHeaders):
                for (k, v) in newHeaders { headers[k] = v }
                
            case .cacheOption(let newOption):
                cacheOption = newOption
                
            case .resize(let type, let targetMB, let maxDimension):
                let resizeValue = ResizeOptions(type: type.mapping, targetMB: targetMB, maxDimension: maxDimension)
                resize = resizeValue
                transformKey = makeTransformKey(resizeValue)
            }
        }

        return ParsedOptions(
            headers: headers,
            cacheOption: cacheOption,
            resize: resize,
            transformKey: transformKey
        )
    }
    
    /// # loadImage
    /// UIImage 를 불러옵니다.
    ///
    /// - Parameters:
    ///   - url: URL
    ///   - key: CacheKey
    ///   - options: ParsedOptions
    ///   - cachedEntry: CacheEntry<CacheMetadata> ( Optional )
    /// - Returns: UIImage ( Optional )
    internal static func loadImage(
        url: URL,
        key: CacheKey,
        options: ParsedOptions,
        cachedEntry: CacheEntry<CacheMetadata>?
    ) async throws -> UIImage? {
        var request = URLRequest(url: url)
        
        for (header, value) in options.headers {
            request.setValue(value, forHTTPHeaderField: header)
        }
        
        let entry = try await downloader.fetch(
            urlRequest: request,
            key: key,
            cachedEntry: cachedEntry
        )
        
        let (finalData, finalImage) = await applyResizeIfNeeded(
            entry: entry,
            resize: options.resize
        )
        
        guard let image = finalImage else { return nil }
        let cost = image.imageCostEstimation
        let finalEntry = CacheEntry(data: finalData ?? entry.data, metadata: entry.metadata)
        
        await writeCache(entry: finalEntry, key: key, cost: cost, option: options.cacheOption)
        return image
    }
}

// MARK: internal - CRUD
extension SimpleCacheManager {
    
    /// - makeCacheKey
    /// - 캐시키를 생성합니다.
    ///
    /// - Parameters:
    ///   - url: URL
    ///   - options: ParsedOptions
    /// - Returns: CacheKey
    internal static func makeCacheKey(for url: URL, options: ParsedOptions) -> CacheKey {
        return CacheKey(urlString: url.absoluteString, transformKey: options.transformKey)
    }
    
    /// - readCache
    /// - 캐시를 읽어 옵니다.
    ///
    /// - Parameters:
    ///   - key: CacheKey
    ///   - option: CacheOptions
    /// - Returns: CacheEntry<CacheMetadata> ( Optional )
    internal static func readCache(key: CacheKey, option: CacheOptions) async -> CacheEntry<CacheMetadata>? {
        switch option {
        case .noCache:
            return nil
        case .onlyMemory:
            
            return await memory.get(key)
        case .onlyDisk:
            
            return await disk.get(key)
        case .diskAndMemory:
            
            return await coordinator.get(key)
        }
    }
    
    /// - writeCache
    /// - 캐시를 저장합니다.
    ///
    /// - Parameters:
    ///   - entry: CacheEntry<CacheMetadata>
    ///   - key: CacheKey
    ///   - cost: Int
    ///   - option: CacheOptions
    internal static func writeCache(
        entry: CacheEntry<CacheMetadata>,
        key: CacheKey,
        cost: Int,
        option: CacheOptions
    ) async {
        switch option {
        case .noCache:
            return
        case .onlyMemory:

            await memory.set(entry, for: key, cost: cost)
        case .onlyDisk:

            await disk.set(entry, for: key, cost: cost)
        case .diskAndMemory:

            await coordinator.set(entry, for: key, cost: cost)
        }
    }
}



// MARK: - Resize
extension SimpleCacheManager {
    
    /// Try resizing if resize option exists.
    /// 리사이즈 옵션이 존재할시 리사이징을 시도합니다.
    ///
    /// - Parameters:
    ///   - entry: CacheEntry
    ///   - resize: ResizeOptions ( Optional )
    ///
    /// - Returns: (Data?, UIImage?)
    static func applyResizeIfNeeded(
        entry: CacheEntry<CacheMetadata>,
        resize: ResizeOptions?
    ) async -> (Data?, UIImage?) {
        guard let resize else {
            return (entry.data, UIImage(data: entry.data))
        }

        guard let image = UIImage(data: entry.data) else {
            return (nil, nil)
        }

        if let resized = await image.reSizeWithCompressImage(
            type: resize.type,
            targetMB: resize.targetMB,
            maxDimension: resize.maxDimension
        ) {
            return (resized, UIImage(data: resized))
        }

        return (entry.data, image)
    }
    
    /// Resize Only Cache Key
    /// 리사이즈 전용 캐시 키
    static func makeTransformKey(_ resize: ResizeOptions) -> String {
        let typeKey = String(describing: resize.type)
        return "resize-\(typeKey)-\(resize.targetMB)-\(resize.maxDimension)"
    }
}
