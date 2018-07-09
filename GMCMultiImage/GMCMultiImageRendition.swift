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

enum GMCMultiImageRenditionError: Error {
    case fileNotFound
}

open class GMCMultiImageRendition: NSObject {
    
    public let size: CGSize
    public let url: URL
    
    fileprivate lazy var cachedImageURL: URL? = {
        guard let directory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first else { return nil }
        
        return URL(fileURLWithPath: directory).appendingPathComponent(url.lastPathComponent)
    }()
    
    public lazy var image: UIImage? = {
        guard isImageAvailable, let cachedImageURL = cachedImageURL else { return nil }
        
        return UIImage(contentsOfFile: cachedImageURL.path)
    }()
    
    public var isImageAvailable: Bool {
        return cachedImageURL.flatMap { FileManager.default.fileExists(atPath: $0.path) } ?? false
    }
    
    public lazy var squareThumbnailSize: CGSize = {
        let shortestSideLength = min(size.width, size.height)
        return CGSize(width: shortestSideLength, height: shortestSideLength)
    }()
    
    public init(url: URL, size: CGSize, cachedImageURL: URL? = nil) {
        self.url = url
        self.size = size
        
        super.init()
        
        if let cachedImageURL = cachedImageURL {
            self.cachedImageURL = cachedImageURL
        }
    }
    
    open func fetchImage(completion: @escaping (Error?, UIImage?) -> Void) {
        if isImageAvailable, let image = image {
            completion(nil, image)
            return
        }
        
        URLSession.shared.downloadTask(with: self.url) { [weak self] fileURL, _, error in
            guard let fileURL = fileURL, let cachedImageURL = self?.cachedImageURL else {
                completion(GMCMultiImageRenditionError.fileNotFound, self?.image)
                return
            }
            do {
                try FileManager.default.moveItem(at: fileURL, to: cachedImageURL)
                self?.image = UIImage(contentsOfFile: fileURL.path)
                completion(nil, self?.image)
            } catch {
                completion(error, self?.image)
            }
        }.resume()
    }
    
    // MARK: - Square Thumbnail Image
    
    public func squareThumbnailImage() -> UIImage? {
        guard let image = image else { return nil }
        
        let shortestSideLength = min(image.size.width, image.size.height)
        let cropRect = CGRect(x: (image.size.width - shortestSideLength) / 2.0,
                              y: (image.size.height - shortestSideLength) / 2.0,
                              width: shortestSideLength,
                              height: shortestSideLength)
        
        return image.cgImage?.cropping(to: cropRect).flatMap { UIImage(cgImage: $0, scale: 1, orientation: image.imageOrientation) }
    }
    
}
