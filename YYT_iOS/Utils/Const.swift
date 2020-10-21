//
//  Const.swift
//  YYT_iOS
//
//  Created by evestorm on 2020/7/15.
//  Copyright © 2020 YYT. All rights reserved.
//  desc: 各种项目中需要使用的常量

import Foundation
import UIKit

// 屏幕宽高
let screenW = UIScreen.main.bounds.width
let screenH = UIScreen.main.bounds.height

// 状态栏高度
let statusBarHeight: CGFloat = {
    var heightToReturn: CGFloat = 0.0
    for window in UIApplication.shared.windows {
        if #available(iOS 13.0, *) {
            if let height = window.windowScene?.statusBarManager?.statusBarFrame.height, height > heightToReturn {
                heightToReturn = height
            }
        } else {
            // Fallback on earlier versions
            heightToReturn = UIApplication.shared.statusBarFrame.size.height
        }
    }
    return heightToReturn
}()

// App名称
let BWAppDispalyName = "云于天"
let AppID = "1523830607"
// App H5 url
let BWAppUrlTest = "https://tapp.yunyutian.cn/"
let BWAppUrlDist = "https://app.cwyyt.cn/"
let BWAppUrlLocal = "http://192.168.1.25:8080/" // 192.168.0.103 169.254.83.17 192.168.1.25  192.168.1.8 192.168.0.107

// WXAppID
// let WXAppID = "wx54cb281b0a7f0c9a"
// let WXUniversalLinks = "https://pic.cwyyt.cn/"

// 小程序相关
let miniOrigID = "gh_5447134f2e70"

// 极光推送
let JPushAppKey = "6b8283ea80a448ea7308efb6"
// yyt: 6b8283ea80a448ea7308efb6
// lance:43d50ae0fd5fe168f77ad6b0
