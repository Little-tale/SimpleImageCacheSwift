//
//  SimpleImageCaching.swift
//  SimpleImageCachingSwift
//
//  Created by Jae hyung Kim on 12/28/25.
//

import UIKit

public protocol SimpleImageCaching: AnyObject { }

extension UIImageView: SimpleImageCaching { }


public struct SimpleImageCachingWrapper<Base>: @unchecked Sendable {
    public let base: Base
    public init(_ base: Base) {
        self.base = base
    }
}

extension SimpleImageCaching {
    public var sic: SimpleImageCachingWrapper<Self> {
        get { return SimpleImageCachingWrapper(self) }
        set { }
    }
}
