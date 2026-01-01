//
//  AnyValueSync.swift
//  SimpleImageCachingSwift
//
//  Created by Jae hyung Kim on 12/28/25.
//

import Foundation

public final class AnyValueSync<Value>: @unchecked Sendable {
    private var _value: Value
    private let lock = NSLock()

    public init(_ value: @autoclosure () throws -> Value) rethrows {
        self._value = try value()
    }

    public func read<T>(_ body: (Value) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body(_value)
    }

    /// Do Not Overlapping Calls
    @discardableResult
    public func write<T>(_ body: (inout Value) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body(&_value)
    }

    @inlinable
    public var value: Value { read { $0 } }

    /// Do Not Overlapping Calls
    @inlinable
    public func set(_ newValue: Value) {
        write { $0 = newValue }
    }

    /// Do Not Overlapping Calls
    @inlinable
    public func update(_ transform: (inout Value) -> Void) {
        write { v in transform(&v) }
    }

    @inlinable
    @discardableResult
    public func replace(with newValue: Value) -> Value {
        write { v in
            let old = v
            v = newValue
            return old
        }
    }
}
