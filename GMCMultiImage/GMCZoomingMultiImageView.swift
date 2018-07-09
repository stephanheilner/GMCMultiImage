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

public class GMCZoomingMultiImageView: UIView, UIScrollViewDelegate {
    
    static let PlaceholderSizeDefault = CGSize(width: 55, height: 55)
    
    var placeholderSize = CGSize.zero
    var scale: CGFloat = 1.0
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView(frame: self.bounds)
        #if !TARGET_OS_TV
        scrollView.scrollsToTop = false
        #endif
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        scrollView.maximumZoomScale = 1
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return scrollView
    }()
    
    private var doubleTapGestureRecognizer: UITapGestureRecognizer?
    private lazy var imageView = UIImageView()
    
    private lazy var loadingIndicatorView: UIActivityIndicatorView = {
        let loadingIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
        loadingIndicatorView.frame = self.bounds
        loadingIndicatorView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return loadingIndicatorView
    }()
    
    private var previousBoundsSize = CGSize.zero
    private var currentRendition: GMCMultiImageRendition?
    private var multiImageRenditionFetches: [Operation] = []
    private var decompressImageOperations: [Operation] = []
    private var initialZoomScale: CGFloat = 0.0
    private var otherZoomScale: CGFloat = 0.0
    
    public var multiImage: GMCMultiImage? {
        didSet {
            currentRendition = nil
            imageView.image = nil
            loadingIndicatorView.stopAnimating()
            // Cancel all pending fetches and decompress image operations
            for decompressImageOperation in decompressImageOperations {
                decompressImageOperation.cancel()
            }
            for multiImageRenditionFetch in multiImageRenditionFetches {
                multiImageRenditionFetch.cancel()
            }
            decompressImageOperations.removeAll()
            multiImageRenditionFetches.removeAll()
            // Resize image view
            
            if let fullImageSize = multiImage?.largestRenditionSize {
                imageView.frame = CGRect(x: 0, y: 0, width: fullImageSize.width, height: fullImageSize.height)
            }
            
            updateZoomInitial(true)
            updateImage()
            centerImage()
        }
    }
    
    override public var contentMode: UIViewContentMode {
        didSet {
            updateZoomInitial(false)
        }
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        contentMode = .scaleAspectFit
        
        addSubview(scrollView)
        scrollView.addSubview(imageView)
        
        addSubview(loadingIndicatorView)
        
        multiImageRenditionFetches = [Operation]()
        decompressImageOperations = [Operation]()
        
        let doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(doubleTap))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTapGestureRecognizer)
        self.doubleTapGestureRecognizer = doubleTapGestureRecognizer
        
        placeholderSize = GMCZoomingMultiImageView.PlaceholderSizeDefault
        scale = UIScreen.main.scale
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        guard !previousBoundsSize.equalTo(bounds.size) else { return }
        
        previousBoundsSize = bounds.size
        updateZoomInitial(false)
        updateImage()
        centerImage()
    }
    
    func updateZoomInitial(_ initial: Bool) {
        guard let fullImageSize = multiImage?.largestRenditionSize else { return }
        
        scrollView.contentSize = fullImageSize
        
        let contentFrame: CGRect = UIEdgeInsetsInsetRect(scrollView.bounds, scrollView.contentInset)
        let previousMinimumZoomScale: CGFloat = scrollView.minimumZoomScale
        
        switch contentMode {
        case .scaleAspectFill:
            scrollView.minimumZoomScale = max(contentFrame.size.width / fullImageSize.width, contentFrame.size.height / fullImageSize.height)
        default:
            scrollView.minimumZoomScale = min(1, min(contentFrame.size.width / fullImageSize.width, contentFrame.size.height / fullImageSize.height))
        }
        initialZoomScale = scrollView.minimumZoomScale
        
        if initial {
            scrollView.zoomScale = scrollView.minimumZoomScale
            otherZoomScale = 1
        } else {
            if scrollView.zoomScale == previousMinimumZoomScale {
                scrollView.zoomScale = scrollView.minimumZoomScale
            }
            scrollView.zoomScale = max(scrollView.minimumZoomScale, scrollView.zoomScale)
        }
    }
    
    func centerImage() {
        let contentFrame = UIEdgeInsetsInsetRect(scrollView.bounds, scrollView.contentInset)
        
        imageView.center = CGPoint(x: round(scrollView.contentSize.width / 2.0 + max(0.0, (contentFrame.size.width - scrollView.contentSize.width) / 2.0)),
                                    y: round(scrollView.contentSize.height / 2.0 + max(0.0, (contentFrame.size.height - scrollView.contentSize.height) / 2.0)))
    }
    
    func zoom(toScale scale: CGFloat, atLocation location: CGPoint) {
        let zoomWidth = scrollView.bounds.size.width / scale
        let zoomHeight = scrollView.bounds.size.height / scale
        
        let zoomRect = CGRect(x: location.x - (zoomWidth / 2.0),
                              y: location.y - (zoomHeight / 2.0),
                              width: zoomWidth,
                              height: zoomHeight)
        
        scrollView.zoom(to: zoomRect, animated: true)
    }
    
    func updateImage() {
        guard let multiImage = multiImage, let fullImageSize = multiImage.largestRenditionSize else { return }
        
        let desiredSize = CGSize(width: fullImageSize.width * scrollView.zoomScale, height: fullImageSize.height * scrollView.zoomScale)
        let rendition = multiImage.bestRenditionThatFits(size: desiredSize, scale: scale, contentMode: .scaleAspectFit)
        
        guard currentRendition != rendition else { return }
        
        currentRendition = rendition
        
        if imageView.image == nil {
            let smallestRendition = multiImage.bestRenditionThatFits(size: placeholderSize, scale: scale, contentMode: .scaleAspectFit)
            if smallestRendition?.isImageAvailable == true {
                // Show the smallest representation first, if available.

                DispatchQueue.main.async { [weak self] in
                    self?.loadingIndicatorView.stopAnimating()
                    self?.imageView.image = smallestRendition?.image
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.loadingIndicatorView.startAnimating()
                }
                
                // If the smallest representation is not available, go ahead and fetch it, then show it
                smallestRendition?.fetchImage { [weak self] error, image  in
                    guard error == nil, self?.currentRendition == rendition else { return }
                    
                    let operation = GMCDecompressImageOperation()
                    operation.image = smallestRendition?.image
                    operation.completionBlock = { [weak self] () in
                        DispatchQueue.main.async { [weak self] in
                            guard self?.currentRendition == rendition && self?.imageView.image == nil else { return }
                        
                            self?.loadingIndicatorView.stopAnimating()
                            self?.imageView.image = operation.image
                        }
                    }
                    self?.decompressImageOperations.append(operation)
                    OperationQueue.decompressImageQueue.addOperation(operation)
                }
                
                if rendition?.isImageAvailable == false, let bestAvailableRendition = multiImage.bestAvailableRenditionThatFits(size: desiredSize, scale: scale, contentMode: .scaleAspectFit), bestAvailableRendition != rendition {
                    bestAvailableRendition.fetchImage { [weak self] error, image in
                        guard self?.currentRendition == rendition else { return }
                        guard error == nil else {
                            DispatchQueue.main.async { [weak self] in
                                self?.loadingIndicatorView.stopAnimating()
                            }
                            return
                        }
                        
                        let operation = GMCDecompressImageOperation()
                        operation.image = bestAvailableRendition.image
                        operation.completionBlock = { [weak self] () in
                            guard self?.currentRendition == rendition else { return }
                            
                            DispatchQueue.main.async { [weak self] in
                                self?.loadingIndicatorView.stopAnimating()
                                self?.imageView.image = operation.image
                            }
                        }
                        self?.decompressImageOperations.append(operation)
                        OperationQueue.decompressImageQueue.addOperation(operation)
                    }
                }
            }
        } else {
            rendition?.fetchImage { [weak self] error, image in
                guard self?.currentRendition == rendition else { return }
                guard error == nil else {
                    DispatchQueue.main.async { [weak self] in
                        self?.loadingIndicatorView.stopAnimating()
                    }
                    return
                }
                
                let operation = GMCDecompressImageOperation()
                operation.image = rendition?.image
                operation.completionBlock = { [weak self] () in
                    guard self?.currentRendition == rendition else { return }
                    
                    DispatchQueue.main.async { [weak self] in
                        self?.loadingIndicatorView.stopAnimating()
                        self?.imageView.image = operation.image
                    }
                }
                self?.decompressImageOperations.append(operation)
                OperationQueue.decompressImageQueue.addOperation(operation)
            }
        }
    }
    
    // MARK: - Gesture Recognizers
    @objc func doubleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        let location = gestureRecognizer.location(in: imageView)
        if scrollView.zoomScale != initialZoomScale {
            zoom(toScale: initialZoomScale, atLocation: location)
        } else if initialZoomScale != otherZoomScale {
            zoom(toScale: otherZoomScale, atLocation: location)
        }
    }
    
    // MARK: - UIScrollViewDelegate
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    public func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        updateImage()
    }
    
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
    }
    
}
