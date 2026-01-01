//
//  Ext+UIImage.swift
//  SimpleImageCachingSwift
//
//  Created by Jae hyung Kim on 12/28/25.
//

import UIKit

extension UIImage {
    /// Image Cost Estimation Function
    ///
    /// - RGBA 8-bit assumed -> 4 bytes per pixel
    /// - 1x/2x/3x -> Scale
    /// - Parameter image: UIImage
    /// - Returns: Int ( Estimation Cost )
    var imageCostEstimation: Int {
        let size = self.size
        let scale = self.scale
        let pixels = Int(size.width * scale) * Int(size.height * scale)
        return pixels * 4
    }
}


