//
//  UIImage+Extension.swift
//  YYT_iOS
//
//  Created by evestorm on 2020/8/3.
//  Copyright © 2020 YYT. All rights reserved.
//

import UIKit

extension UIImage {
    /*
     @description UIImage 转 Data
     @param sourceImage UIImage
     @param maxImageLenght 图片最大大小
     @param maxSizeKB 图片最大KB
     */
    class func resetImgSize(sourceImage: UIImage, maxImageLenght: CGFloat, maxSizeKB: CGFloat) -> Data {
        var maxSize = maxSizeKB

        var maxImageSize = maxImageLenght

        if maxSize <= 0.0 {
            maxSize = 1024.0
        }

        if maxImageSize <= 0.0 {
            maxImageSize = 1024.0
        }

        // 先调整分辨率

        var newSize = CGSize(width: sourceImage.size.width, height: sourceImage.size.height)

        let tempHeight = newSize.height / maxImageSize

        let tempWidth = newSize.width / maxImageSize

        if tempWidth > 1.0, tempWidth > tempHeight {
            newSize = CGSize(width: sourceImage.size.width / tempWidth, height: sourceImage.size.height / tempWidth)
        } else if tempHeight > 1.0, tempWidth < tempHeight {
            newSize = CGSize(width: sourceImage.size.width / tempHeight, height: sourceImage.size.height / tempHeight)
        }

        UIGraphicsBeginImageContext(newSize)

        sourceImage.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()

        UIGraphicsEndImageContext()

        var imageData = newImage!.jpegData(compressionQuality: 1.0)

        var sizeOriginKB: CGFloat = CGFloat((imageData?.count)!) / 1024.0

        // 调整大小

        var resizeRate = 0.9

        while sizeOriginKB > maxSize, resizeRate > 0.1 {
            imageData = newImage!.jpegData(compressionQuality: CGFloat(resizeRate))

            sizeOriginKB = CGFloat((imageData?.count)!) / 1024.0

            resizeRate -= 0.1
        }

        return imageData!
    }
}
