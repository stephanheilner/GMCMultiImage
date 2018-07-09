//
// Copyright (c) 2018 Hilton Campbell
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import UIKit

public class GMCMultiImage: NSObject {
    
    public let renditions: [GMCMultiImageRendition]
    
    private let sortRenditions = { (lhs: GMCMultiImageRendition, rhs: GMCMultiImageRendition) -> Bool in
        if lhs.size.width == rhs.size.width {
            return lhs.size.height < rhs.size.height
        }
        return lhs.size.width < rhs.size.width
    }
    
    public init(renditions: [GMCMultiImageRendition]) {
        self.renditions = renditions.sorted(by: sortRenditions) // Sorted smallest to largest
        
        super.init()
    }
    
    public lazy var largestRenditionSize: CGSize? = {
        return largestRendition()?.size
    }()
    
    public func smallestRendition() -> GMCMultiImageRendition? {
        return renditions.sorted(by: sortRenditions).first
    }
    
    public func largestRendition() -> GMCMultiImageRendition? {
        return renditions.sorted(by: sortRenditions).last
    }
    
    public func bestRenditionThatFits(size: CGSize, scale: CGFloat, contentMode: UIViewContentMode) -> GMCMultiImageRendition? {
        return bestRenditionThatFits(size: size, scale: scale, contentMode: contentMode, mustBeAvailable: false)
    }
    
    public func bestAvailableRenditionThatFits(size: CGSize, scale: CGFloat, contentMode: UIViewContentMode) -> GMCMultiImageRendition? {
        return bestRenditionThatFits(size: size, scale: scale, contentMode: contentMode, mustBeAvailable: true)
    }
    
    public func bestRenditionThatFits(size: CGSize, scale: CGFloat, contentMode: UIViewContentMode, mustBeAvailable: Bool) -> GMCMultiImageRendition? {
        // Incorporate the scale in the size
        let adjustedSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        switch contentMode {
        case .scaleAspectFill:
            var bestRendition: GMCMultiImageRendition?
            
            for rendition in renditions {
                guard (!mustBeAvailable || rendition.isImageAvailable), rendition.size.width >= adjustedSize.width && rendition.size.height >= adjustedSize.height else { continue }
                
                // A viable ideal rendition must be larger than the desired size in both dimensions
                // Of the viable ideal renditions, the smallest one is best
                
                if bestRendition == nil || bestRendition?.size.width ?? 0 > rendition.size.width || bestRendition?.size.height ?? 0 > rendition.size.height {
                    bestRendition = rendition
                }
            }
            
            return bestRendition ?? largestRendition()
        default:
            var bestRendition: GMCMultiImageRendition? = nil
            
            for rendition in renditions {
                guard (!mustBeAvailable || rendition.isImageAvailable), rendition.size.width >= adjustedSize.width || rendition.size.height >= adjustedSize.height else { continue }
                
                // A viable ideal rendition must be larger than the desired size in at least one dimension
                // Of the viable ideal renditions, the smallest one is best
                
                if bestRendition == nil || bestRendition?.size.width ?? 0 > rendition.size.width || bestRendition?.size.height ?? 0 > rendition.size.height {
                    bestRendition = rendition
                }
            }
            
            return bestRendition ?? largestRendition()
        }
    }
    
    public func bestRendition(forSquareThumbnailThatFits size: CGSize, scale: CGFloat) -> GMCMultiImageRendition? {
        // Adjust the size to account for retina displays
        let adjustedSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        var bestRendition: GMCMultiImageRendition?
        var largestRendition: GMCMultiImageRendition?
        
        for rendition in renditions {
            // A viable ideal rendition must be larger than the desired size in both dimensions
            if rendition.squareThumbnailSize.width >= adjustedSize.width && rendition.squareThumbnailSize.height >= adjustedSize.height {
                // Of the viable ideal renditions, the smallest one is best
                if bestRendition == nil || bestRendition?.squareThumbnailSize.width ?? 0 > rendition.squareThumbnailSize.width || bestRendition?.squareThumbnailSize.height ?? 0 > rendition.squareThumbnailSize.height {
                    bestRendition = rendition
                }
            }
            
            // Find the largest rendition as well, just in case there is no ideal rendition
            if largestRendition == nil || largestRendition?.squareThumbnailSize.width ?? 0 < rendition.squareThumbnailSize.width || largestRendition?.squareThumbnailSize.height ?? 0 < rendition.squareThumbnailSize.height {
                largestRendition = rendition
            }
        }
        
        return bestRendition ?? largestRendition ?? self.largestRendition()
    }
    
}
