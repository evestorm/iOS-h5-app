//
//  JPushManager.swift
//  YYT_iOS
//
//  Created by evestorm on 2020/8/25.
//  Copyright © 2020 YYT. All rights reserved.
//  desc: 极光推送工具类

import Foundation
import UIKit
import UserNotifications // 本地通知相关

let AppKey = JPushAppKey

let sharedManager = JPushPublicManager()

// 极光文档官网：http://docs.jiguang.cn/jpush/client/iOS/ios_new_fetures/
class JPushPublicManager: NSObject {
    override init() {
        super.init()
    }

    func JPUSHInit(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        let entity = JPUSHRegisterEntity()
        if #available(iOS 10.0, *) {
            entity.types = Int(JPAuthorizationOptions.badge.rawValue | JPAuthorizationOptions.sound.rawValue | JPAuthorizationOptions.alert.rawValue)
        } else {
            entity.types = Int(JPAuthorizationOptions.badge.rawValue | JPAuthorizationOptions.sound.rawValue)
        }
        let device = UIDevice()
        let version = (device.systemVersion as NSString).doubleValue
        if version >= 8.0 {
            // 自定义 categories
        }

        JPUSHService.register(forRemoteNotificationConfig: entity, delegate: self)

        // TODO: 别忘了提交审核 apsForProduction 改为true
        JPUSHService.setup(withOption: launchOptions, appKey: AppKey, channel: "iOS", apsForProduction: true)

        // 获取registrationID上送至服务端
        JPUSHService.registrationIDCompletionHandler { resCode, registrationID in
            let registrationID = String(registrationID ?? "")
            print("resCode = \(resCode), registrationID = \(String(describing: registrationID))")
            let noti = NSNotification.Name(rawValue: "jpushId")
            NotificationCenter.default.post(name: noti, object: nil, userInfo: ["registerId": registrationID])
        }

        // APP后台被杀死，主动调用remotenoti通知
        let userInfo = launchOptions?[UIApplication.LaunchOptionsKey.remoteNotification] as? [AnyHashable: Any]
        if userInfo != nil {
            JPUSHService.handleRemoteNotification(userInfo)
            let notification = NSNotification.Name(rawValue: "jpush")
            NotificationCenter.default.post(name: notification, object: nil, userInfo: userInfo)
        }
        // https://stackoverflow.com/questions/40209234/how-to-handle-launch-options-in-swift-3-when-a-notification-is-tapped-getting-s
    }

    func registerDeviceToken(_ deviceToken: Data!) {
        JPUSHService.registerDeviceToken(deviceToken)
    }

    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]!, completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        JPUSHService.handleRemoteNotification(userInfo)
//        addNotiOfBadge(userInfo as! [String: Any])
        completionHandler(UIBackgroundFetchResult.newData)
    }

    // 增加红点通知（不需要）
    func addNotiOfBadge(_: [String: Any]) {
//        let badge = (userInfo["aps"] as? [String: Any])?["badge"]
//        if let badgeNum = badge as? Int {
//            var curBadge = UIApplication.shared.applicationIconBadgeNumber
//            curBadge = curBadge + badgeNum
//            UIApplication.shared.applicationIconBadgeNumber = curBadge
//            // 同步badge
//            JPUSHService.setBadge(curBadge)
//            print("curBadge:\(curBadge)")
//        }
    }

    // 销毁红点通知
    func reduceNotiOfBadge() {
//        UIApplication.shared.applicationIconBadgeNumber = 0
        var curBadge = UIApplication.shared.applicationIconBadgeNumber
        if curBadge > 0 {
            curBadge = curBadge - 1
        } else {
            curBadge = 0
        }
        UIApplication.shared.applicationIconBadgeNumber = curBadge
        JPUSHService.setBadge(curBadge)

//        print("\(curBadge)")
//        let center = UNUserNotificationCenter.current()
//        center.removeAllDeliveredNotifications() // To remove all delivered notifications
//        center.removeAllPendingNotificationRequests() // To remove all pending notifications which are not delivered yet but scheduled.

        // source: https://stackoverflow.com/questions/40397552/cancelalllocalnotifications-not-working-in-ios10
    }

    // 清除badge角标
    func cleanBadge() {
        UIApplication.shared.applicationIconBadgeNumber = 0
        JPUSHService.setBadge(0)
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications() // To remove all delivered notifications
        center.removeAllPendingNotificationRequests() // To remove all pending notifications which are not delivered yet but scheduled.
    }

    // 设置 alias
    func setAlias(alias: String) {
        JPUSHService.setAlias(alias, completion: { iResCode, iAlias, seq in
            print("alias,\(alias) . completion,\(iResCode),\(String(describing: iAlias)),\(seq)")
        }, seq: 0)
    }

    // 删除 alias
    func deleteAlias() {
        JPUSHService.deleteAlias({ iResCode, iAlias, seq in
            print("退出注销极光别名 \(iResCode),\(String(describing: iAlias)),\(seq)")
        }, seq: 0)
    }
}

extension JPushPublicManager: JPUSHRegisterDelegate {
    @available(iOS 10.0, *)
    func jpushNotificationCenter(_: UNUserNotificationCenter!, openSettingsFor notification: UNNotification!) {
        if notification != nil, (notification.request.trigger?.isKind(of: UNPushNotificationTrigger.classForCoder()))! {
            // 从通知界面直接进入应用
        } else {
            // 从通知设置界面进入应用
        }
    }

    @available(iOS 10.0, *)
    func jpushNotificationCenter(_: UNUserNotificationCenter!, didReceive response: UNNotificationResponse!, withCompletionHandler completionHandler: (() -> Void)!) {
        print("点击推送消息 content=\(response.notification.request.content.userInfo)")
        let userInfo = response.notification.request.content.userInfo
        if response.notification.request.trigger is UNPushNotificationTrigger {
            JPUSHService.handleRemoteNotification(userInfo)
        }
        let notification = NSNotification.Name(rawValue: "jpush")
        NotificationCenter.default.post(name: notification, object: nil, userInfo: userInfo)
        // 点推送进来销毁小圆点
        reduceNotiOfBadge()
        print("\(UIApplication.shared.applicationIconBadgeNumber)")
        completionHandler()
    }

    @available(iOS 10.0, *)
    func jpushNotificationCenter(_: UNUserNotificationCenter!, willPresent notification: UNNotification!, withCompletionHandler completionHandler: ((Int) -> Void)!) {
        // 接收到通知
        if notification != nil, (notification.request.trigger?.isKind(of: UNPushNotificationTrigger.classForCoder()))! {
            JPUSHService.handleRemoteNotification(notification.request.content.userInfo)
        }
        completionHandler(Int(UNNotificationPresentationOptions.alert.rawValue))
    }

    // 监测通知授权状态返回的结果
    func jpushNotificationAuthorization(_: JPAuthorizationStatus, withInfo _: [AnyHashable: Any]!) {}
}
