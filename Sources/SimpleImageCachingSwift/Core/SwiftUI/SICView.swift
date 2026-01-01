//
//  SICView.swift
//  SimpleImageCachingSwift
//
//  Created by Jae hyung Kim on 12/29/25.
//

import SwiftUI
import UIKit


/// # SwiftUI Simple Image Caching View
///
/// - `SICView`는 SwiftUI 전용 캐싱 이미지 뷰입니다.
/// - `SICView` is a dedicated SwiftUI caching image view.
///
/// ## Example
/// ```swift
///     SICView(urlString: item, options: [
///         .cacheOption(.diskAndMemory),
///         .resize(type: .jpeg, targetMB: 0.1)
///     ])
///     .contentMode(.fill)
///     .placeHolder(UIImage(systemName: "house")!)
///     .onSuccess { image in
///         print("success url = \(item)")
///     }
///     .onFailure { error in
///         print("error - \(error.localizedDescription)")
///     }
///     .resizable()
/// ```
public struct SICView: View {
    private let urlString: String
    private let priority: TaskPriority?
    private var placeholder: UIImage?
    private var isResizable: Bool = false
    private var contentMode: ContentMode
    private var options: [SimpleImageCachingOptions]
    
    @State private var image: UIImage? = nil
    @State private var inFlight: Task<Void, Never>? = nil
    @State private var currentKey: CacheKey? = nil
    
    private var onSuccess: (@MainActor @Sendable (UIImage) -> Void)?
    private var onFailure: (@MainActor @Sendable (Error) -> Void)?

    public init(
        urlString: String,
        placeholder: UIImage? = nil,
        priority: TaskPriority? = nil,
        options: [SimpleImageCachingOptions] = [.cacheOption(.diskAndMemory)],
        contentMode: ContentMode = .fill,
    ) {
        self.urlString = urlString
        self.placeholder = placeholder
        self.priority = priority
        self.options = options
        self.contentMode = contentMode
    }

    public var body: some View {
        Group {
            if let image {
                makeImageView(image)
            } else if let placeholder {
                makeImageView(placeholder)
            } else {
                ProgressView()
            }
        }
        .clipped()
        .task(id: urlString) {
            await startLoad()
        }
        .onDisappear {
            inFlight?.cancel()
            inFlight = nil
        }
    }
}

// MARK: APIs
public extension SICView {
    
    func placeHolder(_ image: UIImage) -> Self {
        var copy = self
        copy.placeholder = image
        return copy
    }
    
    func resizable(_ resizable: Bool = true) -> Self {
        var copy = self
        copy.isResizable = resizable
        return copy
    }
    
    func contentMode(_ mode: ContentMode) -> Self {
        var copy = self
        copy.contentMode = mode
        return copy
    }
    
    func onSuccess(_ block: @escaping @MainActor @Sendable (UIImage) -> Void) -> Self {
        var copy = self
        copy.onSuccess = block
        return copy
    }
    
    func onFailure(_ block: @escaping @MainActor @Sendable (Error) -> Void) -> Self {
        var copy = self
        copy.onFailure = block
        return copy
    }
}

// MARK: - Loader
private extension SICView {
    
    @ViewBuilder
    func makeImageView(_ image: UIImage) -> some View {
        if isResizable {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            Image(uiImage: image)
                .aspectRatio(contentMode: contentMode)
        }
    }

    func startLoad() async {
        inFlight?.cancel()
        let task = Task(priority: priority) {
            await load()
            
        }
        inFlight = task
        await task.value
    }

    func load() async {
        guard let url = URL(string: urlString) else { return }
        
        let parsed = SimpleCacheManager.parseOptions(options)
        
        let key = SimpleCacheManager.makeCacheKey(for: url, options: parsed)
        
        if Task.isCancelled { return }
        
        await MainActor.run {
            currentKey = key
        }

        var cachedEntry: CacheEntry<CacheMetadata>? = nil
        
        if parsed.cacheOption != .noCache {
            cachedEntry = await SimpleCacheManager.readCache(key: key, option: parsed.cacheOption)
            
            if let cachedEntry, let cachedImage = UIImage(data: cachedEntry.data) {
                guard await isCurrentKey(key), !Task.isCancelled else { return }
                await MainActor.run {
                    image = cachedImage
                }
            }
        }

        do {
            let finalImage = try await SimpleCacheManager.loadImage(
                url: url,
                key: key,
                options: parsed,
                cachedEntry: cachedEntry
            )
            guard await isCurrentKey(key), !Task.isCancelled, let finalImage else { return }
            await MainActor.run {
                image = finalImage
            }
            
            onSuccess?(finalImage)
            
        } catch(let error) {
            
            onFailure?(error)
        }
    }

    func isCurrentKey(_ key: CacheKey) async -> Bool {
        await MainActor.run {
            currentKey?.rawValue == key.rawValue
        }
    }
}

#if DEBUG
@MainActor
extension SICView {
    func _testLoadOnce() async {
        await startLoad()
    }

    func _testCurrentImage() -> UIImage? {
        image
    }
}
#endif
