//
//  ImageDownLoader.swift
//  SimpleImageCachingSwift
//
//  Created by Jae hyung Kim on 12/28/25.
//

import Foundation

typealias ImageDownLoaderTask = Task<CacheEntry<CacheMetadata>, Error>

typealias ImageDownLoaderTasks = AnyValueSync<[CacheKey: ImageDownLoaderTask]>

final class ImageDownLoader: @unchecked Sendable  {
    
    // MARK: - Properties

    private let session: URLSession
    private let downloadTimeout: TimeInterval
    private let inFlight = ImageDownLoaderTasks([:])
    private var dateFormatter: DateFormatter!

    // MARK: - Initialization

    init(
        configuration: URLSessionConfiguration = .ephemeral,
        downloadTimeout: TimeInterval = 15.0
    ) {
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60

        self.session = URLSession(configuration: configuration)
        self.downloadTimeout = downloadTimeout
        setDateFormatter()
    }

    // MARK: - API
    
    /// Gets image data from the network and updates metadata.
    /// If the same key request is in progress, wait for an existing operation.
    /// If cachedEntry exists, revalidate with (ETag, last-modified) and return cache on 304.
    ///
    /// - 네트워크에서 이미지 데이터를 가져오고 메타데이터를 갱신합니다.
    /// - 동일 key 요청이 진행 중이면 기존 작업을 대기합니다.
    /// - cachedEntry가 있으면 ETag로 재검증하고 304면 캐시를 반환합니다.
    ///
    /// - Parameters:
    ///   - urlRequest: URLRequest
    ///   - key: in-flight 식별 캐시 키
    ///   - cachedEntry: 캐시된 데이터/메타데이터(ETag 재검증용)
    /// - Returns: 데이터와 메타데이터가 포함된 CacheEntry
    func fetch(
        urlRequest: URLRequest,
        key: CacheKey,
        cachedEntry: CacheEntry<CacheMetadata>? = nil
    ) async throws -> CacheEntry<CacheMetadata> {
        // 이미 진행중인 요청 있으면 대기
        if let task = inFlight.read({ $0[key] }) {
//            SimpleLog.network.info("Reusing in-flight task for \(key.filenameSafeHash)")
            return try await taskHandle(task: task)
        }

        let task = makeTask(urlRequest: urlRequest, cachedEntry: cachedEntry)
        
        if Task.isCancelled {
            throw ImageDownLoaderError.cancel
        }
        inFlight.write { $0[key] = task }
        
        defer {
            inFlight.write { $0.removeValue(forKey: key) }
        }
        
        return try await taskHandle(task: task)
    }

    func cancel(_ key: CacheKey) {
        inFlight.write { tasks in
            tasks[key]?.cancel()
            tasks.removeValue(forKey: key)
        }
    }

    func cancelAll() {
        inFlight.write { tasks in
            for (_, task) in tasks {
                task.cancel()
            }
            tasks.removeAll()
        }
    }
}

// MARK: Helper
extension ImageDownLoader {
    
    /// Create a Task
    /// - Parameters:
    ///   - urlRequest: urlRequest
    ///   - cachedEntry: cached entry (ETag revalidation)
    /// - Returns: ImageDownLoaderTask = Task<CacheEntry<CacheMetadata>, Error>
    private func makeTask(
        urlRequest: URLRequest,
        cachedEntry: CacheEntry<CacheMetadata>? = nil
    ) -> ImageDownLoaderTask {
        return Task { [session, downloadTimeout] in
            guard let url = urlRequest.url else {
                throw ImageDownLoaderError.invalidURL
            }
            var urlRequest = urlRequest
        
            urlRequest.timeoutInterval = downloadTimeout
            
            if let cachedEntry {
                urlRequest = buildRequest(urlRequest: urlRequest, cachedEntry: cachedEntry)
            }
            
            let (data, response) = try await handleResponse(session: session, request: urlRequest)
            
            guard let http = response as? HTTPURLResponse else {
                throw ImageDownLoaderError.invalidResponse
            }

            return try processResponse(
                url: url,
                response: http,
                data: data,
                cachedEntry: cachedEntry
            )
        }
    }
    
    internal func buildRequest(urlRequest: URLRequest, cachedEntry: CacheEntry<CacheMetadata>) -> URLRequest {
        var urlRequest = urlRequest
        if let eTag = cachedEntry.metadata.eTag?.eTag {
//            SimpleLog.cache.debug("find ETag in cachedEntry - \(eTag)")
            urlRequest.setValue(eTag, forHTTPHeaderField: "If-None-Match")
        }
        
        if let lastModified = cachedEntry.metadata.lastModified {
//            SimpleLog.cache.debug("find Cache in lastModified - \(lastModified)")
            
            let requestValue = dateFormatter.string(from: lastModified)
            urlRequest.setValue(requestValue, forHTTPHeaderField: "If-Modified-Since")
        }
        return urlRequest
    }
    
    
    /// 응답코드에 따른 에러처리와 캐시를 재사용합니다.
    /// - Parameters:
    ///   - response: HTTPURLResponse
    ///   - cachedEntry: CacheEntry<CacheMetadata> ( Optional )
    /// - Returns: ( Optional ) Nullable CacheEntry<CacheMetadata>
    private func handleHTTPStatusCodeWithCache(
        response: HTTPURLResponse,
        cachedEntry: CacheEntry<CacheMetadata>?
    ) throws(ImageDownLoaderError) -> CacheEntry<CacheMetadata>?  {
        let statusCode = response.statusCode
        
        if statusCode == 304 { // 변경사항 없음 -> 캐시 반환
//            SimpleLog.cache.debug("304 - Not Modified")
            guard var cached = cachedEntry else {
//                SimpleLog.cache.info("Not Change")
                throw ImageDownLoaderError.notModified
            }
            cached.metadata.touch()
            if cached.metadata.eTag != nil {
                cached.metadata.eTag?.lastValidated = Date()
            }
            return cached
        }

        guard (200...299).contains(statusCode) else {
//            SimpleLog.network.info("Error - Status Code: \(statusCode)")
            throw ImageDownLoaderError.invalidStatusCode(statusCode)
        }
        return nil
    }
    
    internal func processResponse(
        url: URL,
        response: HTTPURLResponse,
        data: Data,
        cachedEntry: CacheEntry<CacheMetadata>?
    ) throws(ImageDownLoaderError) -> CacheEntry<CacheMetadata> {
        if let cached = try handleHTTPStatusCodeWithCache(response: response, cachedEntry: cachedEntry) {
            return cached
        } else {
//            SimpleLog.cache.debug("can't Find cachedEntry.")
        }

        var metadata = cachedEntry?.metadata ?? CacheMetadata(originalUrlString: url.absoluteString)

        // Check "ETag", "last-modified"
        checkCases(metadata: &metadata, response: response)

        if Task.isCancelled {
            throw ImageDownLoaderError.cancel
        }

        metadata.touch()
        return CacheEntry(data: data, metadata: metadata)
    }

    /// Check "ETag", "last-modified"
    private func checkCases(metadata: inout CacheMetadata, response: HTTPURLResponse) {
        // Check Response Header Field in "ETag"
        metadata.eTag = checkETag(response: response)
        
        // Check Response Header Field in "last-modified"
        metadata.lastModified = checkLastModified(response: response)
    }
    
    private func checkLastModified(response: HTTPURLResponse) -> Date? {
        guard let headerValue = response.value(forHTTPHeaderField: "Last-Modified") else {
            return nil
        }
//        SimpleLog.network.debug("find Last-Modified - \(response.url?.absoluteString ?? "")")
        return dateFormatter.date(from: headerValue)
    }
    
    /// - If there is an ETag field in the response header Deliver the ETagCache.
    /// - 응답 Header 에서 ETag 필드 존재할 경우 ETagCache 를 전달합니다.
    ///
    /// - Parameter http: HTTPURLResponse
    /// - Returns: ETagCache
    private func checkETag(response: HTTPURLResponse) -> ETagCache? {
        guard let headerValue = response.value(forHTTPHeaderField: "ETag") else {
            return nil
        }
//        SimpleLog.network.debug("find Etag - \(response.url?.absoluteString ?? "")")
        return ETagCache(eTag: headerValue)
    }
  
    /// - Handles Task errors as ImageDownLoaderError
    /// - Task 에러를 ImageDownLoaderError 로 핸들링 함
    ///
    /// - Parameter task: typealias ImageDownLoaderTask = Task<CacheEntry<CacheMetadata>, Error>
    /// - Returns: CacheEntry<CacheMetadata>
    private func taskHandle(
        task: ImageDownLoaderTask
    ) async throws (ImageDownLoaderError) -> CacheEntry<CacheMetadata> {
        do {
            return try await task.value
        } catch {
            if let typed = error as? ImageDownLoaderError {
                throw typed
            }
            if error is CancellationError {
                throw ImageDownLoaderError.cancel
            }
            throw ImageDownLoaderError.unknown
        }
    }
    
    /// - Handles response errors as ImageDownLoaderError
    /// - 응답에러를 ImageDownLoaderError 로 핸들링 함
    ///
    /// - Parameters:
    ///   - session: URLSession
    ///   - request: URLRequest
    /// - Returns: ( Data,URLResponse )
    private func handleResponse(
        session: URLSession,
        request: URLRequest
    ) async throws (
        ImageDownLoaderError
    ) -> ( Data,URLResponse ) {
        do {
            let result = try await session.data(for: request)
            return result
        } catch {
            throw ImageDownLoaderError.invalidResponse
        }
    }
    
    /// 초기 DateFormatter 를 세팅합니다. -> lastModified 를 위함
    private func setDateFormatter() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"

        self.dateFormatter = formatter
    }
}
