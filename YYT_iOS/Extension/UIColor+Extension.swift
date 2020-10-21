//
//  UIColor+Extension.swift
//  YYT_iOS
//
//  Created by evestorm on 2020/7/15.
//  Copyright © 2020 YYT. All rights reserved.
//

import UIKit

extension UIColor {
    //    rgba方法
    class func rgba(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1.0) -> UIColor {
        return UIColor(red: red / 255.0, green: green / 255.0, blue: blue / 255.0, alpha: alpha)
    }

    //    主题色
    class func globalBgColor() -> UIColor {
        return #colorLiteral(red: 0.02745098039, green: 0.5098039216, blue: 1, alpha: 1)
    }
}
