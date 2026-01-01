//
//  StoragePathProtocol.swift
//  SimpleImageCachingSwift
//
//  Created by Jae hyung Kim on 1/1/26.
//

import Foundation


public protocol StoragePathProtocol: Sendable {
    var cacheDiskPath: URL? { get }
}
