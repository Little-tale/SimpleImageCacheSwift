//
//  StoragePath.swift
//  SimpleImageCachingSwift
//
//  Created by Jae hyung Kim on 1/1/26.
//

import Foundation

public enum StoragePath: StoragePathProtocol {
    
    case `default`
    
    case appGroup(groupID: String)
    
    case custom(path: URL)
}

extension StoragePath {
    
    public var cacheDiskPath: URL? {
        switch self {
        case .default:
            let url = FileManager.default
                .urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent(
                    "SimpleImageCachingSwift",
                    conformingTo: .directory
                )
            return url
            
        case .appGroup(let groupID):
            guard let container = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
                return nil
            }
            
            return container.appendingPathComponent("SimpleImageCachingSwift", conformingTo: .directory)
            
        case .custom(let path):
            return path
        }
    }
}
