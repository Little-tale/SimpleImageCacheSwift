# SimpleImageCachingSwift

Lightweight image caching for UIKit and SwiftUI with memory + disk stores, ETag revalidation, and optional resize / compression.

메모리 + 디스크 캐싱, ETAG 재검증, last-modified 검증,  
크기 조정 / 압축 옵션을 갖춘 UIKit 및 SwiftUI를 위한 간단한 이미지 캐싱.

# Requirements

- iOS 15.0+
- Swift 5.9+
- Xcode 15.0+

# Installation

## Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/Little-tale/SimpleImageCacheSwift.git", from: "1.0.0")
]
```

Or in Xcode:

1. File → Add Package Dependencies
2. Enter the repository URL
3. Select the version

# Usage Code

```swift
// UIKit
imageView.sic.setImage(
    urlString: "https://example.com/image.jpg",
    placeholder: UIImage(systemName: "photo")!,
    options: [
        .cacheOption(.diskAndMemory),
        .resize(type: .jpeg, targetMB: 0.2)
    ]
)

// SwiftUI
SICView(
    urlString: "https://example.com/image.jpg",
    options: [
        .cacheOption(.diskAndMemory),
        .resize(type: .jpeg, targetMB: 0.2)
    ]
)
.placeHolder(UIImage(systemName: "photo")!)
.onSuccess { image in
    print("success image = \(item)")
}
.onFailure { error in
    print("error - \(error.localizedDescription)")
}
.contentMode(.fill)
.resizable()
```

# Architecture

<picture><img src="sources/SimpleImageCachingSwift/Resources/SimpleImageCache_diagram.png" width="500" height="500"/></picture>

# Flow

## English

> `UIImageView.sic.setImage(...)` or `SICView(...)` starts the request.

> Options are parsed,
> a `CacheKey` is built (URL + transform key for resize), and cache lookup runs first (memory -> disk).

> If the entry is found on disk, it is promoted to memory for faster
> subsequent reads. If cached metadata exists, the network request revalidates with
> `If-None-Match` / `If-Modified-Since`. A `304 Not Modified` reuses the cached data,
> and a `200...299` updates metadata (ETag, last-modified, access time).

> Optional resize /
> compression runs before the final image is written back to cache.

Caching is configurable per request:

- `noCache`: no read/write to cache.
- `onlyMemory`: read/write memory cache only.
- `onlyDisk`: read/write disk cache only.
- `diskAndMemory`: read-through with promotion on disk hit.

Background handling:

- When the app enters background, disk access records are flushed.
- On memory warning, memory cache is cleared.

## 한국어

> UIKit - `UIImageView.sic.setImage(...)`  
> SwiftUI - `SICView(...)`로 요청을 시작합니다.

> 옵션을 파싱하고 `CacheKey`를 생성합니다. (리사이즈 시 변환 키 포함)  
> 먼저 캐시를 조회합니다. ( 메모리 -> 디스크 )  
> 디스크에서 캐시가 적중하면 메모리로 승격합니다. ( 다음 조회를 빠르게 )

> 캐시 메타데이터가 있으면 네트워크 요청에  
> `If-None-Match` / `If-Modified-Since`를 붙여 재검증합니다.

> `304 Not Modified`면 캐시를 재사용하고,  
> `200...299`면 해당하는 매타데이터를 모아두고,  
> 일정시간 후에 갱신합니다. ( `백그라운드` 진입시 포함 )  
> (ETag, last-modified, 접근 시간) 필요 시  
> 리사이즈/압축 후 캐시에 저장합니다.

캐싱 요청 방식들

- `noCache`: 캐시 읽기/쓰기 없음.
- `onlyMemory`: 메모리 캐시만 사용.
- `onlyDisk`: 디스크 캐시만 사용.
- `diskAndMemory`: read-through, 디스크 적중 시 메모리 승격.

백그라운드 처리:

- 앱이 백그라운드로 들어가면 디스크 접근 기록을 flush 합니다.
- 메모리 경고 시 메모리 캐시를 비웁니다.

### example

```swift
SICView(
    urlString: "https://example.com/image.jpg",
    options: [
        .cacheOption(.diskAndMemory),
    ]
)
```

# Components

## English

> `SimpleCacheManager` orchestrates option parsing, cache read/write, download, and resize.
> `CacheCoordinator` provides memory+disk read-through with promotions.
>
> `ImageDownLoader`
> handles in-flight de-dup and revalidation. `DiskCacheStore` prunes by age/size.

## 한국어

> `SimpleCacheManager`가 옵션 파싱, 캐시 읽기/쓰기, 다운로드, 리사이즈를 통합 관리합니다.
> `CacheCoordinator`가 메모리+디스크 read-through와 승격을 제공합니다.
>
> `ImageDownLoader`는 중복 요청 병합과 재검증을 담당하며,
> `DiskCacheStore`는 기간/용량 기준으로 prune합니다.

```swift
let parsed = SimpleCacheManager.parseOptions(options)

let key = SimpleCacheManager.makeCacheKey(for: url, options: parsed)

let cached = await SimpleCacheManager.readCache(key: key, option: parsed.cacheOption)

let image = try await SimpleCacheManager.loadImage(
    url: url,
    key: key,
    options: parsed,
    cachedEntry: cached
)
```

# Flow Code

```swift
// 1) Parse options and build cache key.
// 1) 옵션 파싱 및 캐시 키 생성
let parsed = SimpleCacheManager.parseOptions(options)
let key = SimpleCacheManager.makeCacheKey(for: url, options: parsed)

// 2) Read cache first (memory -> disk).
// 2) 캐시 우선 조회 (메모리 -> 디스크)
var cachedEntry: CacheEntry<CacheMetadata>? = nil
if parsed.cacheOption != .noCache {
    cachedEntry = await SimpleCacheManager.readCache(key: key, option: parsed.cacheOption)
    if let cachedEntry, let cachedImage = UIImage(data: cachedEntry.data) {
        imageView.image = cachedImage
    }
}

// 3) Download with revalidation if metadata exists.
// 3) 메타데이터가 있으면 재검증 후 다운로드
let finalImage = try await SimpleCacheManager.loadImage(
    url: url,
    key: key,
    options: parsed,
    cachedEntry: cachedEntry
)

// 4) Cache is written in loadImage, then update UI.
// 4) loadImage 내부에서 캐시 저장 후 UI 갱신
if let finalImage {
    imageView.image = finalImage
}
```

# StoragePath (Default / App Group / Custom)

## English  
> Configure the disk cache location once at app startup. After configuration, you can tune
disk limits and prune via the coordinator.

## 한국어  
> 앱 시작 시 디스크 캐시 경로를 설정할 수 있습니다.  
설정 후에는 coordinator로 디스크 제한과 prune을  
제어할 수 있습니다.

```swift
// Configure disk cache location.
// 디스크 캐시 경로 설정
SimpleCacheManager.configure(storagePath: .appGroup(groupID: "group.com.example.app"))
// SimpleCacheManager.configure(storagePath: .default)
// SimpleCacheManager.configure(storagePath: .custom(path: customURL))

Task {
    // Limit disk cache.
    // 디스크 제한 설정
    await SimpleCacheManager.coordinator.changeDiskAgeLimit(120_000)
    await SimpleCacheManager.coordinator.changeDiskSizeLimit(mb: 100)

    // Apply prune after changing limits.
    // 변경 후 prune 실행
    await SimpleCacheManager.coordinator.checkDisk()
}
```

# Demo

> Through the Demo App  
> You can check the operation yourself.

> 데모앱을 통해
> 동작을 직접 보실 수 있습니다.

![DemoExample](/Sources/SimpleImageCachingSwift/Resources/DemoExample.gif)


# License

MIT License. See `LICENSE`.
