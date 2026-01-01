//
//  SimpleLog.swift
//  SimpleImageCachingSwift
//
//  Created by Jae hyung Kim on 12/28/25.
//

import Foundation
import os

public enum SimpleLog {
    private static let subsystem = "SimpleImageCachingSwift"

    public static let cache = Logger(subsystem: subsystem, category: "cache")
    public static let network = Logger(subsystem: subsystem, category: "network")
    public static let ui = Logger(subsystem: subsystem, category: "ui")
}
