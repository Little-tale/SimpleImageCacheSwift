//
//  DiskCacheStore.swift
//  SimpleImageCachingSwift
//
//  Created by Jae hyung Kim on 12/28/25.
//

import Foundation

public actor DiskCacheStore: CacheStore {
    public typealias Metadata = CacheMetadata

    // MARK: - Properties
    
    private var fileManager: FileManager
    
    /// - Root directory for cached files
    /// - 캐시 파일이 저장되는 루트 디렉터리
    private let baseURL: URL
    
    /// - JSON encoder for metadata
    /// - 메타데이터 JSON 인코더
    private let encoder: JSONEncoder
    
    /// - JSON decoder for metadata
    /// - 메타데이터 JSON 디코더
    private let decoder: JSONDecoder
    
    /// - disk 제한 용량 MB 기준
    private var diskLimit: Int
    
    /// - 유통기한 Default = 7 Day
    private var ageLimit: TimeInterval = .day * 7
    
    
    // MARK: - Initialization
    
    public init(
        baseURL: URL,
        fileManager: FileManager = .default,
        limitMb: Int = 50
    ) {
        self.fileManager = fileManager
        self.baseURL = baseURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        DiskCacheStore.createBaseDirectoryIfNeeded(baseURL: baseURL, fileManager: fileManager)
        self.diskLimit = Self.calcMBSize(mb:limitMb)
    }
    
    /// Entry used only for pruning.
    /// prune 계산에만 사용함
    private struct DiskItem {
        let keyHash: String
        let dataURL: URL
        let metaURL: URL
        let size: Int
        let lastAccessTime: Date
    }
    
    private struct LastPath {
        static let data = ".data"
        static let metadata = ".meta.json"
    }
    
}


// MARK: - public



// MARK: - Remove/Clear/Prune
extension DiskCacheStore {
    
    public func remove(_ key: CacheKey) async {
        removeEntry(for: key)
    }

    public func clear() async {
        clearDirectory()
    }

    public func synchronize() async {}

    @discardableResult
    public func prune() async -> Int {
        pruneInternal()
    }
}

// MARK: - Get Set
extension DiskCacheStore {

    public func get(_ key: CacheKey) async -> CacheEntry<CacheMetadata>? {
        readEntry(for: key)
    }

    @discardableResult
    public func set(_ entry: CacheEntry<CacheMetadata>, for key: CacheKey, cost: Int) async -> Int? {
        writeEntry(entry, for: key)
        if diskLimit > 0 {
            return pruneInternal()
        }
        return nil
    }

    /// - update MetaData
    /// - 캐시의 매타데이터를 업데이트 합니다.
    ///
    /// - Parameter key: CacheKey
    public func touch(_ key: CacheKey) async {
        await touch([key])
    }
    
    /// - `Cache` List Update `MetaData`
    /// - 배열 캐시의 매타데이터를 최신화 합니다.
    ///
    /// - Parameter keys: Array CacheKey
    public func touch(_ keys: [CacheKey]) async {
        for key in keys {
            updateMetadata(for: key)
        }
    }
    
    /// Plz Call With prune
    public func changeDiskLimit(mb: Int) {
        self.diskLimit = Self.calcMBSize(mb: mb)
    }
    
    /// Plz Call With prune
    public func changeAgeLimit(to ageLimit: TimeInterval) {
        self.ageLimit = ageLimit
    }
}



// MARK: - private




// MARK: - Core
extension DiskCacheStore {
    
    /// Pruning
    ///
    /// - A function that "prunches" old/exceeded items in the cache.
    /// If the cache becomes too large or old items are piled up, it pressures the performance/disk,
    /// so give it a standard and organize it.
    ///
    /// - 캐시중 오래된 혹은 초과된 것을 (가지치기) 하는 함수
    /// 캐시가 너무 커지거나, 오래된 항목이 쌓이면 성능 이슈 + 디스크 압박
    ///
    /// - Parameters:
    /// - Returns: the number of erased / 지워진 갯수
    private func pruneInternal() -> Int {
        let now = Date() // 기준시
        var removed = 0 // 지워진 갯수
        var items = collectItems() // Array DiskItem

        // Remove entries older than the age limit first.
        // ageLimit을 초과한 항목을 먼저 제거.
        items.sort { $0.lastAccessTime < $1.lastAccessTime }
        
        var remaining: [DiskItem] = []
        
        for item in items {
            if now.timeIntervalSince(item.lastAccessTime) > ageLimit {
                try? fileManager.removeItem(at: item.dataURL)
                try? fileManager.removeItem(at: item.metaURL)
                removed += 1
            } else {
                remaining.append(item)
            }
        }
        items = remaining

        var totalSize = items.reduce(0) { $0 + $1.size }
        
        // Evict LRU entries until size limit is satisfied.
        // diskLimit 만족할 때까지 LRU 순으로 제거.
        if totalSize > diskLimit {

            items.sort { $0.lastAccessTime < $1.lastAccessTime }
            
            for item in items where totalSize > diskLimit {
                try? fileManager.removeItem(at: item.dataURL)
                try? fileManager.removeItem(at: item.metaURL)
                totalSize -= item.size
                removed += 1
            }
        }

        return removed
    }

    /// - Scan ".data" files and pair them with metadata to build prune candidates.
    /// - ".data" 파일을 스캔하고 metadata와 매칭하여 가지치기 후보를 만듬.
    private func collectItems() -> [DiskItem] {
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [
                .fileSizeKey, // 파일 크기(byte)
                .contentModificationDateKey // 마지막 수정일자 / LastUpdateAt
            ],
            options: [
                .skipsHiddenFiles // 숨김파일 무시
            ]
        ) else {
            return []
        }

        var items: [DiskItem] = [] // 반환될 Array - DiskItem
        
        for url in contents where url.pathExtension == "data" {
            
            // SHA256 으로 변환한 파일명
            let keyHash = url.deletingPathExtension().lastPathComponent
            // Meta 데이터 위치
            let metaURL = baseURL.appendingPathComponent(keyHash + LastPath.metadata)
            
            // 파일크기 조회
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            
            // 마지막 접근 조회
            var lastAccess = ( // .contentModificationDateKey = 마지막 수정일자
                try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            ) ?? Date.distantPast

            // 매타데이터 조회후 있다면 디코딩
            if let metaData = try? Data(contentsOf: metaURL),
               let metadata = try? decoder.decode(CacheMetadata.self, from: metaData) {
                // Prefer metadata lastAccessTime if available.
                // metadata가 있으면 lastAccessTime을 우선 사용.
                lastAccess = metadata.lastAccessTime
            }

            items.append(DiskItem(
                keyHash: keyHash,
                dataURL: url,
                metaURL: metaURL,
                size: size,
                lastAccessTime: lastAccess
            ))
        }

        return items
    }

}


// MARK: - Helpers
extension DiskCacheStore {
    
    /// - Data file holds raw image bytes.
    /// - data 파일에는 이미지 byte가 저장됨.
    private func dataURLForKey(_ key: CacheKey) -> URL {
        // SHA256
        baseURL.appendingPathComponent(key.filenameSafeHash + LastPath.data)
    }

    /// - Metadata file stores CacheMetadata as JSON.
    /// - Metadata 파일에는 CacheMetadata(JSON)가 저장됨.
    private func metadataURLForKey(_ key: CacheKey) -> URL {
        // SHA256
        baseURL.appendingPathComponent(key.filenameSafeHash + LastPath.metadata)
    }
    
    /// - Read data + metadata, then update access info.
    /// - data/metadata 읽은 뒤 접근 정보를 갱신.
    private func readEntry(for key: CacheKey) -> CacheEntry<CacheMetadata>? {
        // SHA256 처리된 dataURL
        let dataURL = dataURLForKey(key)
        // SHA256 처리된 metaURL
        let metaURL = metadataURLForKey(key)

        guard
            let data = try? Data(contentsOf: dataURL), // 가져오기 시도
            let metaData = try? Data(contentsOf: metaURL), // " "
            var metadata = try? decoder.decode(CacheMetadata.self, from: metaData) // Decoding 시도
        else {
            return nil
        }
        // 접근 횟수 Up & lastAccessTime Update
        metadata.touch()
        
        // 다시 인코딩후 저장
        if let updatedMeta = try? encoder.encode(metadata) {
            try? updatedMeta.write(to: metaURL, options: .atomic)
        }

        return CacheEntry(data: data, metadata: metadata)
    }
    
    /// - Write data and metadata atomically
    /// - data, metadata를 기록
    private func writeEntry(_ entry: CacheEntry<CacheMetadata>, for key: CacheKey) {
        
        // SHA256 처리된 dataURL
        let dataURL = dataURLForKey(key)
        // SHA256 처리된 metaURL
        let metaURL = metadataURLForKey(key)
        // data save to url
        try? entry.data.write(to: dataURL, options: .atomic)
        // metaData 인코딩
        let metaData = try? encoder.encode(entry.metadata)
        // metaData 인코딩되면 저장
        try? metaData?.write(to: metaURL, options: .atomic)
    }

    /// - Update metadata only (lastAccessTime/accessCount)
    /// - 메타데이터만 갱신 (접근 시간/횟수)
    ///
    private func updateMetadata(for key: CacheKey) {
        let metaURL = metadataURLForKey(key)
        guard
            let metaData = try? Data(contentsOf: metaURL),
            var metadata = try? decoder.decode(CacheMetadata.self, from: metaData)
        else {
            return
        }

        metadata.touch()
        if let updatedMeta = try? encoder.encode(metadata) {
            try? updatedMeta.write(to: metaURL, options: .atomic)
        }
    }
    
    /// - Remove both data and metadata files.
    /// - data, metadata 파일을 제거
    private func removeEntry(for key: CacheKey) {
        try? fileManager.removeItem(at: dataURLForKey(key))
        try? fileManager.removeItem(at: metadataURLForKey(key))
    }
    
    /// - Remove all cached files under base directory.
    /// - base 디렉터리의 모든 캐시 제거
    private func clearDirectory() {
        // contents: [URL] - 경로들
        guard let contents = try? fileManager.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: nil
        ) else {
            return
        }
        for url in contents {
            try? fileManager.removeItem(at: url)
        }
    }
    
    /// - Function to create if there is no folder (baseURL) to store cache
    /// - 캐시를 저장할 폴더가 없으면 만드는 함수
    private static func createBaseDirectoryIfNeeded(baseURL: URL, fileManager: FileManager) {
        guard !fileManager.fileExists(atPath: baseURL.path) else { return }
        try? fileManager.createDirectory(
            at: baseURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    private static func calcMBSize(mb: Int) -> Int {
        mb * 1024 * 1024
    }
}
