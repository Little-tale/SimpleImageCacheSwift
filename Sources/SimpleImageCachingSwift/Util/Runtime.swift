//
//  Runtime.swift
//  SimpleImageCachingSwift
//
//  Created by Jae hyung Kim on 12/30/25.
//

import Foundation

/// - Take out the value that was stored as a key in the object.
/// - Object에 key로 저장된 값을 꺼냅니다
///
///         private var someKey: UInt8 = 0
///         let keyPtr = &someKey
///
/// - Parameters:
///   - object: Any
///   - key: UnsafeRawPointer
/// - Returns: T
func getAssociatedObject<T>(
    _ object: Any,
    _ key: UnsafeRawPointer
) -> T? {
    return objc_getAssociatedObject(object, key) as? T
}


/// - Save the value as a key in the object.
/// - object에 key로 value를 저장합니다.
///
///         private var someKey: UInt8 = 0
///         let keyPtr = &someKey
///
/// - Parameters:
///   - object: Any
///   - key: UnsafeRawPointer
///   - value: T - Value
func setRetainedAssociatedObject<T> (
    _ object: Any,
    _ key: UnsafeRawPointer,
    _ value: T?
) {
    objc_setAssociatedObject(object, key, value, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
}
