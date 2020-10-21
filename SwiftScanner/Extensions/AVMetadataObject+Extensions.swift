//
//  AVMetadataObject+Extensions.swift
//  SwiftScanner
//
//  Created by Jason on 2018/11/29.
//  Copyright © 2018 Jason. All rights reserved.
//

import AVFoundation

extension AVMetadataObject.ObjectType {
    public static let upca: AVMetadataObject.ObjectType = .init(rawValue: "org.gs1.UPC-A")

    /// `AVCaptureMetadataOutput` metadata object types.
    public static var metadata = [
        AVMetadataObject.ObjectType.aztec,

        AVMetadataObject.ObjectType.code128,

        AVMetadataObject.ObjectType.code39,

        AVMetadataObject.ObjectType.code39Mod43,

        AVMetadataObject.ObjectType.code93,

        AVMetadataObject.ObjectType.dataMatrix,

        AVMetadataObject.ObjectType.ean13,

        AVMetadataObject.ObjectType.ean8,

        AVMetadataObject.ObjectType.face,

        AVMetadataObject.ObjectType.interleaved2of5,

        AVMetadataObject.ObjectType.itf14,

        AVMetadataObject.ObjectType.pdf417,

        AVMetadataObject.ObjectType.qr,

        AVMetadataObject.ObjectType.upce,
    ]
}
