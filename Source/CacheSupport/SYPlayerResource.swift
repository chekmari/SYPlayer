//
//  SYPlayerResource.swift
//  SmartYard
//
//  Created by Александр Попов on 07.08.2024.
//  Copyright © 2024 LanTa. All rights reserved.
//

import Foundation
import AVFoundation

class SYPlayerResource {
    let video: [SYPlayerResourceVideo]
    let previewImage: URL
    let name: String
    
    init(video: [SYPlayerResourceVideo], previewImage: URL, name: String) {
        self.video = video
        self.previewImage = previewImage
        self.name = name
    }
    
    convenience init(url: URL, previewImage: URL, name: String) {
        let video = SYPlayerResourceVideo(url: url)
        self.init(video: [video], previewImage: previewImage, name: name)
    }
}

class SYPlayerResourceVideo {
    let url: URL
    
    /// An instance of NSDictionary that contains keys for specifying options for the initialization of the AVURLAsset. 
    /// See AVURLAssetPreferPreciseDurationAndTimingKey and AVURLAssetReferenceRestrictionsKey above.
    public var options: [String: Any]?
    
    var avURLAsset: AVURLAsset? {
        get {
            guard !url.isFileURL, url.pathExtension != "m3u8" else {
                return AVURLAsset(url: url)
            }
            return SYPlayerConfig.asset(for: self) ?? nil
        }
    }
    
    init(url: URL, options: [String: Any]? = nil) {
        self.url = url
        self.options = options
    }
}
