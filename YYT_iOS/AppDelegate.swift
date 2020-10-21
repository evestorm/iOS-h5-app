//
//  AppDelegate.swift
//  YYT_iOS
//
//  Created by evestorm on 2020/7/15.
//  Copyright © 2020 YYT. All rights reserved.

import Alamofire
import SwiftyJSON
import UIKit
import UserNotifications // 本地通知相关

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, WXApiDelegate, WXApiLogDelegate, JPUSHRegisterDelegate {
    var window: UIWindow?

    // block，用于回到微信授权登录成功获取的code，后续利用该code获取微信用户信息
    var wechatLoginCallback: ((_ code: String) -> Void)?

    func application(_: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        //        初始化 Network.reachability
        do {
            try Network.reachability = Reachability(hostname: "www.baidu.com")
        } catch {
            print("delelgate catch")
            switch error as? Network.Error {
            case let .failedToCreateWith(hostname)?:
                print("Network error:\nFailed to create reachability object With host named:", hostname)
            case let .failedToInitializeWith(address)?:
                print("Network error:\nFailed to initialize reachability object With address:", address)
            case .failedToSetCallout?:
                print("Network error:\nFailed to set callout")
            case .failedToSetDispatchQueue?:
                print("Network error:\nFailed to set DispatchQueue")
            case .none:
                print(error)
            }
        }

        // 忽略本地缓存，重新获取，防止没更新json文件
//        Alamofire.Session.default.session.configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

        // 初始化微信SDK
        registerWeChat()

        // 检测App是否需要更新
        checkVersion()

        // 注册极光推送
        sharedManager.JPUSHInit(launchOptions)

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()
        return true
    }

    func applicationDidFinishLaunching(_: UIApplication) {}

    // 初始化微信SDK
    func registerWeChat() {
        WXApi.startLog(by: .detail, logDelegate: self)
        WXApi.registerApp(WX_AppID, universalLink: WX_UNIVERSAL_LINK)
    }

    // 重写 handleOpenURL 和 openURL 方法
    func application(_: UIApplication, open url: URL, options _: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        let handleUrlStr = url.absoluteString
        if let handleUrl = URL(string: handleUrlStr) {
            return WXApi.handleOpen(handleUrl, delegate: self)
        }
        return false
    }

    func application(_: UIApplication, open url: URL, sourceApplication _: String?, annotation _: Any) -> Bool {
        let handleUrlStr = url.absoluteString
        if let handleUrl = URL(string: handleUrlStr) {
            return WXApi.handleOpen(handleUrl, delegate: self)
        }
        return false
    }

    // 重写AppDelegate的continueUserActivity方法
    func application(_: UIApplication, continue userActivity: NSUserActivity, restorationHandler _: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return WXApi.handleOpenUniversalLink(userActivity, delegate: self)
    }

    // MARK: WXApiDelegate

    func onReq(_: BaseReq) {
        print("=========> onRep")
    }

    func onResp(_ resp: BaseResp) {
        print("========> onResp")
        if resp.isKind(of: SendAuthResp.self) {
            let _resp = resp as! SendAuthResp
            if let code = _resp.code {
                if wechatLoginCallback != nil {
                    wechatLoginCallback!(code)
                }
            } else {
                print(resp.errStr)
            }
        }
    }

    func onLog(_ log: String, logLevel _: WXLogLevel) {
        print(log)
    }

    // MARK: App更新

    // 获取版本号
    func checkVersion() {
        // 苹果这个link有延迟或缓存，所以调用cn的接口，并发post请求
        let url = "https://itunes.apple.com/cn/lookup?bundleId=com.whcewei.yytapp" + "&random=" + String(describing: arc4random())
        AF.request(url, method: .post, parameters: [:])
            .responseJSON { response in
                if let value = response.value {
                    let json = JSON(value)
                    self.compareVersion(appStoreVersion: json["results"][0]["version"].stringValue)
                }
            }
    }

    // 比较版本
    func compareVersion(appStoreVersion: String) {
        print("线上" + appStoreVersion)
        let version: String = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)!
        print("本地" + version)
        if appStoreVersion == version {
            print("当前已是最新版")
        } else {
            let alertC = UIAlertController(title: "有新版本", message: "前去更新版本？", preferredStyle: .alert)
            alertC.addAction(UIAlertAction(title: "去更新", style: .default, handler: { _ in
                self.updateApp(appId: AppID)
            }))
            alertC.addAction(UIAlertAction(title: "下次再说", style: .cancel, handler: { _ in
            }))
            UIApplication.shared.keyWindow?.rootViewController?.present(alertC, animated: true, completion: nil)
        }
    }

    // 更新App
    func updateApp(appId _: String) {
        // 根据iOS系统版本，分别处理
        let urlString = "itms-apps://itunes.apple.com/cn/app/id\(AppID)"
        print(urlString)
        if let url = URL(string: urlString) {
            // 根据iOS系统版本，分别处理
            if #available(iOS 10, *) {
                UIApplication.shared.open(url, options: [:],
                                          completionHandler: {
                                              _ in
                })
            } else {
                UIApplication.shared.openURL(url)
            }
        }
    }

    // MARK: 极光推送相关

    func jpushNotificationCenter(_: UNUserNotificationCenter!, willPresent notification: UNNotification!, withCompletionHandler completionHandler: ((Int) -> Void)!) {
        let userInfo = notification.request.content.userInfo
        if notification.request.trigger is UNPushNotificationTrigger {
            JPUSHService.handleRemoteNotification(userInfo)
        }
        // 需要执行这个方法，选择是否提醒用户，有Badge、Sound、Alert三种类型可以选择设置
        completionHandler(Int(UNNotificationPresentationOptions.alert.rawValue))
    }

    // 接收到推送执行此方法
    func jpushNotificationCenter(_: UNUserNotificationCenter!, didReceive response: UNNotificationResponse!, withCompletionHandler completionHandler: (() -> Void)!) {
        let userInfo = response.notification.request.content.userInfo
        if response.notification.request.trigger is UNPushNotificationTrigger {
            JPUSHService.handleRemoteNotification(userInfo)
        }
        // 系统要求执行这个方法
        completionHandler()
    }

    // 当程序关闭或被强杀时候，通过点击消息打开APP，将触发
    func application(_: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        sharedManager.handleRemoteNotification(userInfo, completionHandler: completionHandler)
    }

    // 系统获取Token
    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // 注册APNs成功并上报DeviceToken
        sharedManager.registerDeviceToken(deviceToken)
    }

    // 获取token 失败
    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) { // 可选
        // 注册APNs失败
        print("did Fail To Register For Remote Notifications With Error: \(error)")
    }

    // 后台进前台
    func applicationDidEnterBackground(_: UIApplication) {
        // 销毁红点通知
//        sharedManager.reduceNotiOfBadge()
    }

    func jpushNotificationCenter(_: UNUserNotificationCenter!, openSettingsFor _: UNNotification!) {}

    func jpushNotificationAuthorization(_: JPAuthorizationStatus, withInfo _: [AnyHashable: Any]!) {}

    func applicationDidBecomeActive(_: UIApplication) {
//        let center = UNUserNotificationCenter.current()
//        if #available(iOS 10, *) {
//            UIApplication.shared.applicationIconBadgeNumber = -1
        ////            center.removeAllPendingNotificationRequests()
//        } else {
//            UIApplication.shared.cancelAllLocalNotifications()
//        }
//        JPUSHService.setBadge(0)
    }
}
