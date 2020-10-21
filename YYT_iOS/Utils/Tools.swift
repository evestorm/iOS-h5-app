//
//  Tools.swift
//  YYT_iOS
//
//  Created by evestorm on 2020/7/15.
//  Copyright © 2020 YYT. All rights reserved.
//  desc: 项目工具类

import Foundation
import UIKit

// MARK: 获取当前设备安全区域frame

public func safeAreaFrame(_ viewController: UIViewController) -> CGRect {
    let isIphoneX = UIScreen.main.bounds.height >= 812 ? true : false

    var navigationBarHeight: CGFloat = isIphoneX ? 44 : 20
    var tabBarHeight: CGFloat = isIphoneX ? 34 : 0

    // 标志导航视图控制器是否存在 默认不存在
    // 为什么需要这个？
    // 这里有个坑，当没有导航栏时，如果是iPhoneX等设备，tabBar.frame.height = 49 会不包含底部返回条的高度（34）, 存在导航栏时 tabBar.frame.height = 83
    var noNavigationExists = true

    if let navigation = viewController.navigationController {
        noNavigationExists = false
        navigationBarHeight += navigation.navigationBar.frame.height
    }
    if let tabBarController = viewController.tabBarController {
        tabBarHeight = noNavigationExists ? tabBarHeight : 0
        tabBarHeight += tabBarController.tabBar.frame.height
    }

    let frame = CGRect(x: 0, y: navigationBarHeight, width: screenW, height: screenH - tabBarHeight - navigationBarHeight)

    return frame
}

// MARK: 获取App信息

public func getAppInfo() -> [String: String] {
    let infoDictionary = Bundle.main.infoDictionary!
    let appVersion = infoDictionary["CFBundleShortVersionString"] as! String
    let appName = infoDictionary["CFBundleName"] as! String
    return ["version": appVersion, "name": appName]
}

// MARK: JSONString 转 字典

func JSONString2Dict(text: String) -> [String: AnyObject]? {
    if let data = text.data(using: String.Encoding.utf8) {
        do {
            return try JSONSerialization.jsonObject(with: data, options: [JSONSerialization.ReadingOptions(rawValue: 0)]) as? [String: AnyObject]
        } catch let error as NSError {
            print(error)
        }
    }
    return nil
}

// MARK: 字典 转 JSONString

func dict2JSONString(dict: NSDictionary?) -> String {
    let data = try? JSONSerialization.data(withJSONObject: dict!, options: JSONSerialization.WritingOptions(rawValue: 0))
    let jsonStr = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
    return jsonStr! as String
}

// MARK: JSONString 转 数组

func JSONString2Array(jsonString: String) -> NSArray {
    let jsonData: Data = jsonString.data(using: .utf8)!

    let array = try? JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers)
    if array != nil {
        return array as! NSArray
    }
    return array as! NSArray
}

// MARK: 数组 转 JSONString

func array2JSONString(array: NSArray) -> String {
    if !JSONSerialization.isValidJSONObject(array) {
        print("无法解析出JSONString")
        return ""
    }

    let data: NSData! = try? JSONSerialization.data(withJSONObject: array, options: []) as NSData?
    let JSONString = NSString(data: data as Data, encoding: String.Encoding.utf8.rawValue)
    return JSONString! as String
}
