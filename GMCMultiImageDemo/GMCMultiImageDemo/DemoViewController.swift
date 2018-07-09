//
//  DemoViewController.swift
//  GMCMultiImageDemo
//
//  Created by Stephan Heilner on 7/9/18.
//  Copyright © 2018 Galactic Megacorp. All rights reserved.
//

import UIKit
import GMCMultiImage

class DemoViewController: UIViewController {
    
    private lazy var renditions: [GMCMultiImageRendition] = {
        let renditionsArray = NSArray(contentsOfFile: Bundle.main.path(forResource: "MapleViewers", ofType: "plist") ?? "") as? [[AnyHashable : Any]]
        return renditionsArray?.compactMap { rendition -> GMCMultiImageRendition? in
            guard let urlString = rendition["URL"] as? String, let url = URL(string: urlString), let sizeString = rendition["size"] as? String else { return nil }
           
            return GMCMultiImageRendition(url: url, size: CGSizeFromString(sizeString))
        } ?? []
    }()
    
    private lazy var multiImage: GMCMultiImage = {
        return GMCMultiImage(renditions: self.renditions)
    }()
    
    private lazy var zoomingMultiImageView: GMCZoomingMultiImageView = {
        let zoomingMultiImageView = GMCZoomingMultiImageView(frame: self.view.bounds)
        zoomingMultiImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        zoomingMultiImageView.multiImage = self.multiImage
        return zoomingMultiImageView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(zoomingMultiImageView)
    }
}
