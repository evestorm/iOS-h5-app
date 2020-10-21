//
//  ViewController.swift
//  YYT_iOS
//
//  Created by evestorm on 2020/7/15.
//  Copyright © 2020 YYT. All rights reserved.
//  desc: 主控制器，使用 wkwebview 加载 H5 页面

// 导入各种库

import CallKit
import Contacts
import MessageUI
import SwiftyContacts
import SwiftyJSON
import UIKit
import WebKit

class ViewController: UIViewController, WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate, MFMessageComposeViewControllerDelegate, CXCallObserverDelegate {
    // MARK: - 变量

    // ------------ API前缀（配置所在位置：Utils/Const.swift文件）-------------
    // BWAppUrlDist: 生产 | BWAppUrlTest: 测试 | BWAppUrlLocal: 本地
    let baseURL = BWAppUrlDist

    // ------------ 推送相关 -------------
    var pageURL = "" // 推送过来的拼接url
    var params: NSDictionary? // JPush跳转的参数
    var registerId: String = "" // JPush注册id

    // ------------ 打电话相关 ------------
    let callObserver = CXCallObserver()
    private var beforeDate: Date!
    var didDetectOutgoingCall = false

    // ------------- 联调 JS 相关 --------------
    //    JS全局注册变量名 'iOS' ，用于前端识别当前设备是否为iOS
    private let iOS = "iOS"

    // ------------- 网络相关 ------------
    // 当前是否有网
    private var enabled: Bool? // 当前网络状态
    // 是否为第一次加载
    private var isFirstLoad = true

    // ------------- UI 相关 -------------
    // statusBar 相关
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return style
    }

    // 当前 statusBar 使用的样式
    var style: UIStatusBarStyle = .lightContent

    // ------------- 通讯录相关 ---------------
    var telArray: Array = [TelModel]()
    var telDict: [String: String] = [:]

    // ------------- 二维码相关 -------------
    let vc = ScannerVC() // 二维码扫码控制器

    // MARK: 视图

    // ------------- 伪启动页（欢迎界面） ---------------
    lazy var lanuchView: UIImageView = {
        let img = UIImage(named: "launch")
        let lanuchView = UIImageView(image: img, highlightedImage: img)
        lanuchView.frame = UIScreen.main.bounds
        lanuchView.contentMode = .scaleAspectFill
        return lanuchView
    }()

    // web容器（懒加载形式）
    lazy var webView: WKWebView = {
        // 创建设置对象
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        preferences.javaScriptCanOpenWindowsAutomatically = true

        // 专门用来配置WKWebView
        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        configuration.userContentController = WKUserContentController()

        // 注册iOS这个函数,让js调用
        configuration.userContentController.add(self, name: iOS)

        // app相关信息，挂载到 window.iOS 上
        let appInfo = getAppInfo()
        let scriptStr = """
        window.iOS = {
            'getAppInfo': {
                'version': "\(appInfo["version"]!)",
                'name': "\(appInfo["name"]!)",
            }
        }
        """

        // 注册全局变量
        let script = WKUserScript(source: scriptStr, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(script)
        var webView = WKWebView(frame: safeAreaFrame(self), configuration: configuration)
        // 设置ui和导航代理
        webView.uiDelegate = self
        webView.navigationDelegate = self
        return webView
    }()

    // ---------------- 懒加载断网时的提醒界面 -----------------
    lazy var noDataTipsView: UIView = {
        // 包含按钮/文字/图片的View的size
        var noDataTipsView = UIView(frame: UIScreen.main.bounds)
        noDataTipsView.backgroundColor = .white

        // 图片的size
        let tipViewWidth: CGFloat = 150.0
        let tipViewHeight: CGFloat = 150.0

        let tipView = UIImageView(frame: CGRect(x: 0, y: 0, width: tipViewWidth, height: tipViewHeight))
        tipView.center.x = screenW / 2
        tipView.center.y = screenH / 2 - 50

        tipView.image = UIImage(named: "off")
        noDataTipsView.addSubview(tipView)

        // 提示按钮
        let tipBtn = UIButton(frame: CGRect(x: 0, y: tipView.frame.origin.y + tipView.frame.height + 50, width: screenW, height: 40))
        tipBtn.setTitle("糟糕，网络似乎断开了", for: .normal)
        tipBtn.setTitleColor(.black, for: .normal)

        tipBtn.addTarget(self, action: #selector(setupTheNetwork(btn:)), for: UIControl.Event.touchUpInside)

        noDataTipsView.addSubview(tipBtn)

        return noDataTipsView
    }()

    // ---------------- 状态栏view(沉浸式导航栏) -------------
    var statusView: UIView!

    // MARK: 拦截js的alert弹窗（JS中的alert会被此事件拦截）

    func webView(_: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame _: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alertController = UIAlertController(title: message,
                                                message: nil,
                                                preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: "OK", style: .cancel) {
            _ in completionHandler()
        })

        present(alertController, animated: true, completion: nil)
    }

    // MARK: 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white

        // 获取当前设备宽高
        let width: CGFloat = screenW

        // 使用UIView覆盖状态栏
        statusView = UIView(frame: CGRect(x: 0, y: 0, width: width, height: statusBarHeight))
        // 使用 Extension/UIColor+Extension.swift 中的拓展方法
        statusView.backgroundColor = UIColor.globalBgColor()
        view.addSubview(statusView)

        // 监控网络
        NotificationCenter.default
            .addObserver(self,
                         selector: #selector(statusManager),
                         name: .flagsChanged,
                         object: nil)

        // 更新UI
        updateUserInterface()

        // 获取各种权限
        getPermissions()

        // 监听极光推送 jpush
        NotificationCenter.default.addObserver(self, selector: #selector(jpush(noti:)), name: NSNotification.Name(rawValue: "jpush"), object: nil)
        // 监听极光推送传递的 registerId
        NotificationCenter.default.addObserver(self, selector: #selector(getJPushID(noti:)), name: NSNotification.Name(rawValue: "jpushId"), object: nil)
    }

    // ------------- 监听 webview 启动完毕 --------------
    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        // 移除伪启动页
        for view in view.subviews {
            if view.isKind(of: UIImageView.self) {
                view.removeFromSuperview()
            }
        }
        // app被杀死后，极光推送跳转，进入此处
        swiftNavigateTo(from: "isFirst")
        // 上传registerID
        uploadJPushID()
    }

    func webViewDidClose(_ webView: WKWebView) {
        // 销毁，防止内存泄漏
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "iOS")
    }

    // -------------- 出现内存警告时 ---------------
    override func didReceiveMemoryWarning() {
        // 移除通知
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: 添加观察者方法

    override func observeValue(forKeyPath keyPath: String?, of _: Any?, change _: [NSKeyValueChangeKey: Any]?, context _: UnsafeMutableRawPointer?) {
        // 设置进度条
        if keyPath == "estimatedProgress" {
            if webView.estimatedProgress >= 1.0 {}
        }
    }

    // MARK: 更新UI

    func updateUserInterface() {
        view.addSubview(noDataTipsView)
        noDataTipsView.isHidden = true
        // 如果是真机再根据网络判断
        if Network.reachability.isRunningOnDevice {
            print("更新UI")
            switch Network.reachability.status {
            case .unreachable:
                print("没网")
                noDataTipsView.isHidden = false

            case .wwan, .wifi:
                noDataTipsView.isHidden = true
                if isFirstLoad {
                    // 加载h5
                    let url = URL(string: baseURL) // BWAppUrlDist BWAppUrlTest BWAppUrlLocal
                    let urlReq = URLRequest(url: url!)
                    webView.load(urlReq)
                    view.addSubview(webView)

                    // 加载伪启动页
                    view.addSubview(lanuchView)
                    // 把启动页放在最上次
                    // view.bringSubviewToFront(lanuchView)
                    // 监听 WKWebView 进度
                    webView.addObserver(self, forKeyPath: "estimatedProgress", options: .new, context: nil)

                    isFirstLoad = false
                }
            }

        } else { // 模拟器直接访问
            // 加载h5
            let url = URL(string: baseURL) // BWAppUrlDist BWAppUrlTest BWAppUrlLocal
            let urlReq = URLRequest(url: url!)

            webView.load(urlReq)
            view.addSubview(webView)

            // 加载伪启动页
            view.addSubview(lanuchView)
            // 把启动页放在最上次
            // view.bringSubviewToFront(lanuchView)
        }
    }

    // -------------- 状态栏管理 --------------
    @objc func statusManager(_: Notification) {
        // 更新用户界面
        updateUserInterface()
    }

    // -------------- 设置网络 ---------------
    @objc func setupTheNetwork(btn: UIButton) {
        print("btn ")
        // 这个判断防止按钮的重复点击，这个必须写，如果不这么写，连续点击按钮的时候，会出现倒计时快速减少的bug
        if enabled! {
            btn.isEnabled = true
        } else {
            btn.isEnabled = false
        }
    }

    // MARK: 监听js调用iOS方法

    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == iOS {
            guard let dict = message.body as? [String: AnyObject],
                let method = dict["method"] as? String else {
                return
            }
            iOSHandle(method: method, params: dict["params"] as AnyObject)
        }
    }

    //  MARK: 获取APP权限

    private func getPermissions() {
        bw_requestPhotoLibraryAuthorization(with: { _ in
            print("获取相册权限")
        })
        bw_requestCameraAuthorization { _ in
            print("获取拍照权限")
        }
    }

    // MARK: 暴露给前端的接口（important！！！！重要，接口都汇总在这里）

    private func iOSHandle(method: String, params: AnyObject) {
        switch method {
        case "getContacts": // 获取联系人
            returnContacts {
                self.telDict = self.telArray.reduce([String: String]()) { (dict, person) -> [String: String] in
                    var dict = dict
                    dict[person.tel ?? ""] = person.name
                    return dict
                }
                let encoder = JSONEncoder()

                // 字典 转 JSON
                if let jsonData = try? encoder.encode(self.telDict) {
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        print("bilibili" + jsonString)
                        self.webView.evaluateJavaScript("getContacts('\(jsonString)')") { _, error in
                            print("Error : \(String(describing: error))")
                        }
                    }
                }
            }
        case "setLoginUser": // 设置当前登录人id
            saveLoginUser(params: params)
        case "deleteLoginUser": // 删除当前登录人id
            deleteLoginUser()
        case "callPhone": // 打电话
            if let p = params as? [String: AnyObject], let phoneStr = p["phone"] as? String {
                print(phoneStr)
                callPhone(phoneStr: phoneStr)
            }
        case "canGetAddressBook": // 是否已授权联系人
            returnAuthAddressBook()
        case "reqAddressBookAuth": // 申请获取联系人授权
            reqAddressBookAuth()
        case "insertPhone": // 添加联系人
            if let p = params as? [String: AnyObject], let name = p["name"] as? String, let phone = p["phone"] as? String {
                insertPhone(name: name, phone: phone)
            }
        case "savePhoto": // 保存图片
            if let p = params as? [String: AnyObject], let urlStr = p["urlStr"] as? String {
                saveImageToPhotos(savedImage: addImageViewToLocal(urlStr: urlStr))
            }
        case "sentSMS": // 发送短信
            if let p = params as? [String: AnyObject], let phone = p["phone"] as? String, let message = p["message"] as? String {
                sentSMS(phone: phone, message: message)
            }
        case "sendWXTextMessage": // 发送文本信息给微信好友
            if let p = params as? [String: AnyObject], let message = p["message"] as? String {
                WeChatFunc.sendWXTextMessage(shareText: message)
            }
        case "sendWXImageMessage": // 发送图片
            if let p = params as? [String: AnyObject], let imageUrl = p["imageUrl"] as? String {
                WeChatFunc.sendWXImageMessage(imageUrl: imageUrl)
            }
        case "sendWXMiniProgramMessage": // 发送微信小程序
            if let p = params as? [String: AnyObject],
                let webpageurl = p["webpageurl"] as? String,
                let pagePath = p["pagePath"] as? String,
                let title = p["title"] as? String,
                let desc = p["desc"] as? String,
                let imageUrl = p["imageUrl"] as? String,
                let ptype = p["ptype"] as? Int {
                WeChatFunc.sendWXMiniProgramMessage(webpageUrl: webpageurl, userName: miniOrigID, path: pagePath, imageUrl: imageUrl, withShareTicket: false, programType: ptype, miniTitle: title, miniDescription: desc)
            }
        case "cleanBadge": // 清除程序icon角标
            sharedManager.cleanBadge()
        case "popupScanner": // 弹出扫码器
            popupScanner()
        default:
            print("请求失败")
        }
    }

    // MARK: 返回联系人授权状态

    private func returnAuthAddressBook() {
        let isAuth = bw_contactAuthorizationStatus()
        switch isAuth {
        case .notDetermined, .restricted, .denied: // 尚未授权, 家长控制, 拒绝
            webView.evaluateJavaScript("canGetAddressBook(false)") { _, error in
                print("Error : \(String(describing: error))")
            }
        case .authorized: // 已授权
            webView.evaluateJavaScript("canGetAddressBook(true)") { _, error in
                print("Error : \(String(describing: error))")
            }
        }
    }

    // MARK: 申请联系人权限

    private func reqAddressBookAuth() {
        bw_requestContactAuthorization(with: { auth in
            print(auth)
            self.webView.evaluateJavaScript("reqAddressBookAuth(\(auth))") { _, error in
                print("Error : \(String(describing: error))")
            }
        })
    }

    // MARK: 添加联系人

    private func insertPhone(name: String, phone: String) {
        let contact: CNMutableContact = CNMutableContact()
        contact.givenName = name

        // 设置电话
        let mobileNumber = CNPhoneNumber(stringValue: phone)
        let mobileValue = CNLabeledValue(label: CNLabelPhoneNumberMobile,
                                         value: mobileNumber)
        contact.phoneNumbers = [mobileValue]

        addContact(Contact: contact) { result in
            switch result {
            case let .success(bool):
                if bool {
                    self.webView.evaluateJavaScript("insertPhone('success')") { _, error in
                        print("Error : \(String(describing: error))")
                    }
                }
            case let .failure(error):
                let errorStr = String(error.localizedDescription)
                if errorStr == "Access Denied" {
                    bw_requestContactAuthorization(with: { auth in
                        print(auth)
                        if auth {
                            self.insertPhone(name: name, phone: phone)
                        }
                    })
                } else {
                    self.webView.evaluateJavaScript("insertPhone('\(errorStr)')") { _, error in
                        print("Error : \(String(describing: error))")
                    }
                }
            }
        }
    }

    // MARK: 存储用户id

    private func saveLoginUser(params: AnyObject) {
        print("saveLoginUser")
        if let p = params as? [String: AnyObject], let userId = p["id"] as? String {
            print("userId:" + userId) // Was a string
            // 设置alias
            sharedManager.setAlias(alias: userId)
        }
    }

    // MARK: 移除用户id

    private func deleteLoginUser() {
        sharedManager.deleteAlias()
    }

    // MARK: 授权获取联系人

    private func returnContacts(callback: @escaping () -> Void) {
        bw_requestContactAuthorization(with: { _ in
            // 遍历联系人列表
            self.getContatList()
            callback()
        })
        //        弹窗提醒如何编写
        //            let alertController = UIAlertController(title: "提示", message: "应用需要获取您的通讯录权限，请在设置给予相应权限", preferredStyle: .alert)
        //            let cancelAction1 = UIAlertAction(title: "确定", style: .destructive, handler: nil)
        //            let cancelAction2 = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        //            alertController.addAction(cancelAction1)
        //            alertController.addAction(cancelAction2)
        //
        //            //            展示alert弹窗
        //            DispatchQueue.main.async {
        //                self.present(alertController, animated: true, completion: nil)
        //            }
    }

    //  MARK: 获取联系人

    private func getContatList() {
        // 判断是否有权读取通讯录
        let status = CNContactStore.authorizationStatus(for: .contacts)
        guard status == .authorized else {
            return
        }
        // 1.创建通讯录对象
        let store = CNContactStore()
        // 2.定义要获取的属性键值
        let key = [CNContactFamilyNameKey, CNContactGivenNameKey, CNContactPhoneNumbersKey]
        // 3.获取请求对象
        let request = CNContactFetchRequest(keysToFetch: key as [CNKeyDescriptor])
        // 清空联系人列表
        telArray = [TelModel]()
        // 4.遍历所有联系人
        do {
            try store.enumerateContacts(with: request, usingBlock: { (contact: CNContact, _: UnsafeMutablePointer<ObjCBool>) in
                // 4.1获取电话号码
                let phoneNumbers = contact.phoneNumbers
                for phoneNumber in phoneNumbers {
                    // 由于同一个人可能有多个电话号码，所以遍历电话，每个电话当做一个新联系人添加
                    // 4.2获取姓名
                    let lastName = contact.familyName
                    let firstName = contact.givenName
                    let telModel: TelModel = TelModel()
                    telModel.name = "\(lastName)\(firstName)"
                    // 去除 ( ) - 和空格
                    telModel.tel = phoneNumber.value.stringValue.replacingOccurrences(of: "(", with: "", options: .literal, range: nil).replacingOccurrences(of: ")", with: "", options: .literal, range: nil).replacingOccurrences(of: "-", with: "", options: .literal, range: nil).replacingOccurrences(of: " ", with: "", options: .literal, range: nil)

                    self.telArray.append(telModel)

                    // 4.2 去掉联系人姓名为空或者 电话为空的数据
                    if telModel.name == "" || telModel.tel == "" {
                        self.telArray.remove(at: self.telArray.count - 1)
                    }
                }

            })
        } catch {
            print("读取通讯录出错")
        }
    }

    // MARK: 根据URL获取UIImage实例

    public func addImageViewToLocal(urlStr: String) -> UIImage {
        let url = URL(string: urlStr)! as URL
        guard let data = try? Data(contentsOf: url) else { return UIImage() }
        guard let myImage = UIImage(data: data) else { return UIImage() }
        return myImage
    }

    // MARK: 调用UIImageWriteToSavedPhotosAlbum方法

    public func saveImageToPhotos(savedImage: UIImage) {
        UIImageWriteToSavedPhotosAlbum(savedImage, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    // MARK: 保存图片回调

    @objc func image(_: UIImage, didFinishSavingWithError error: NSError?, contextInfo _: UnsafeRawPointer) {
        if let error = error {
            print(error.localizedDescription)
            let ac = UIAlertController(title: "保存失败", message: error.localizedDescription, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "确定", style: .default))
            present(ac, animated: true)
        } else {
            let ac = UIAlertController(title: "保存成功!", message: "图片已保存到您的相册", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "确定", style: .default))
            present(ac, animated: true)
        }
    }

    // MARK: 发送短信

    // 发送短信
    func sentSMS(phone: String, message: String) {
        // 首先要判断设备具不具备发送短信功能
        if MFMessageComposeViewController.canSendText() {
            let controller = MFMessageComposeViewController()
            controller.body = message
            controller.recipients = [phone]
            controller.messageComposeDelegate = self
            present(controller, animated: true, completion: nil)
        } else {
            let ac = UIAlertController(title: "无法发送短信", message: "本设备不能发送", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "确定", style: .default))
            present(ac, animated: true)
        }
    }

    // 发送短信代理
    func messageComposeViewController(_: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        dismiss(animated: true, completion: nil)
        switch result.rawValue {
        case MessageComposeResult.sent.rawValue:
            print("短信发送成功")
            webView.evaluateJavaScript("sentSMS('success')") { _, error in
                print("Error : \(String(describing: error))")
            }
        case MessageComposeResult.cancelled.rawValue:
            print("短信取消发送")
            webView.evaluateJavaScript("sentSMS('cancel')") { _, error in
                print("Error : \(String(describing: error))")
            }
        case MessageComposeResult.failed.rawValue:
            print("短信发送失败")
            webView.evaluateJavaScript("sentSMS('fail')") { _, error in
                print("Error : \(String(describing: error))")
            }
        default:
            break
        }
    }

    // MARK: 打电话

    //    参考: https://stackoverflow.com/questions/13743344/how-can-i-find-out-whether-the-user-pressed-the-call-or-the-cancel-button-when-m
    public func callPhone(phoneStr: String) {
        let phone = "telprompt://" + phoneStr
        if let url = NSURL(string: phone.replacingOccurrences(of: " ", with: "", options: .literal, range: nil)), UIApplication.shared.canOpenURL(url as URL) {
            callObserver.setDelegate(self, queue: DispatchQueue.main)
            didDetectOutgoingCall = false
            // we only want to add the observer after the alert is displayed,
            // that's why we're using asyncAfter(deadline:)
            UIApplication.shared.open(url as URL, options: [:]) { [weak self] success in
                if success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self?.addNotifObserver()
                    }
                }
            }
        }
    }

    func addNotifObserver() {
        let selector = #selector(appDidBecomeActive)
        let notifName = UIApplication.didBecomeActiveNotification
        NotificationCenter.default.addObserver(self, selector: selector, name: notifName, object: nil)
    }

    //    用户取消了打电话
    @objc func appDidBecomeActive() {
        // if callObserver(_:callChanged:) doesn't get called after a certain time,
        // the call dialog was not shown - so the Cancel button was pressed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            if !(self?.didDetectOutgoingCall ?? true) {
                print("Cancel button pressed")
            }
        }
    }

    //    用户点击了呼叫
    func callObserver(_: CXCallObserver, callChanged call: CXCall) {
        /**
         拨通:  outgoing :1  onHold :0   hasConnected :0   hasEnded :0
         拒绝:  outgoing :1  onHold :0   hasConnected :0   hasEnded :1
         链接:  outgoing :1  onHold :0   hasConnected :1   hasEnded :0
         挂断:  outgoing :1  onHold :0   hasConnected :1   hasEnded :1

         新来电话:    outgoing :0  onHold :0   hasConnected :0   hasEnded :0
         保留并接听:  outgoing :1  onHold :1   hasConnected :1   hasEnded :0
         另一个挂掉:  outgoing :0  onHold :0   hasConnected :1   hasEnded :0
         保持链接:    outgoing :1  onHold :0   hasConnected :1   hasEnded :1
         对方挂掉:    outgoing :0  onHold :0   hasConnected :1   hasEnded :1
         */

        // 接通
        if call.isOutgoing, call.hasConnected, !call.hasEnded {
            // 记录当前时间
            setBeginDate()
        }
        // 挂断
        if call.isOutgoing, call.hasConnected, call.hasEnded {
            // 计算通话时长
            let seconds = getCallPhoneTime()

            webView.evaluateJavaScript("callPhone(\(seconds))") { _, error in
                print("Error : \(String(describing: error))")
            }
        }
    }

    // 记录当前时间
    func setBeginDate() {
        beforeDate = Date()
    }

    // 计算通话时长
    func getCallPhoneTime() -> String {
        let dat = Date(timeInterval: 0, since: beforeDate)
        let a = dat.timeIntervalSinceNow

        let timeString = String(format: "%0.f", fabs(a)) // 转为字符型
        NSLog("%@秒", timeString)
        return timeString
    }

    // MARK: JPush获取跳转信息

    @objc func jpush(noti: Notification) {
        guard let userInfo = noti.userInfo, let url = userInfo["url"] as? String else {
            print("No userInfo found in notification")
            return
        }
        pageURL = url
        print(["lance": "123"])
        params = ["lance": "123"]
        print(userInfo["store"] as Any)
        if let store = userInfo["store"] as? [String: String] {
            // 极光后台发送消息，传过来的是 string
            // let dict = JSONString2Dict(text: store)
            // params = ["store": dict ?? ""]
            // 后端传过来的是字典
            params = ["store": store]
        }

        swiftNavigateTo()
    }

    // MARK: - swift跳转页面

    func swiftNavigateTo(from: String = "appRun") {
        // 判断 params 字典是否为nil，不为nil，跳转；否则不执行
        switch from {
        case "isFirst":
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                if let params = self.params, params.count > 0 {
                    // 字典 转 JSON
                    let jsonString = dict2JSONString(dict: params)
                    print("JPush params" + jsonString)
                    self.webView.evaluateJavaScript("nativeNavigateTo('\(self.pageURL)', '\(jsonString)')") { _, error in
                        print("Error : \(String(describing: error))")
                    }
                }
            }
        case "appRun":
            if let params = params, params.count > 0 {
                // 字典 转 JSON
                let jsonString = dict2JSONString(dict: params)
                print("JPush params" + jsonString)
                print("nativeNavigateTo('\(pageURL)', \(jsonString))")
                webView.evaluateJavaScript("nativeNavigateTo('\(pageURL)', '\(jsonString)')") { _, error in
                    print("Error : \(String(describing: error))")
                }
                // 清空params
                // self.params = nil
            }
        default:
            if let params = params, params.count > 0 {
                // 字典 转 JSON
                let jsonString = dict2JSONString(dict: params)
                print("JPush params" + jsonString)
                webView.evaluateJavaScript("nativeNavigateTo('\(pageURL)', '\(jsonString)')") { _, error in
                    print("Error : \(String(describing: error))")
                }
            }
        }
    }

    // MARK: 获取registerId

    @objc func getJPushID(noti: Notification) {
        guard let userInfo = noti.userInfo, let registerId = userInfo["registerId"] as? String else {
            print("No userInfo found in notification")
            return
        }
        self.registerId = registerId
        print("registerId" + self.registerId)
    }

    // MARK: 上传极光ID

    func uploadJPushID() {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
            self.webView.evaluateJavaScript("uploadJPushID('\(self.registerId)')") { _, error in
                print("Error : \(String(describing: error))")
            }
        }
    }

    // MARK: 打开扫码页面

    func popupScanner() {
        vc.setupScanner { code in

            print(code)

            self.dismiss(animated: true, completion: nil)

            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                self.webView.evaluateJavaScript("sendScannerMsg('\(code)')") { _, error in
                    print("Error : \(String(describing: error))")
                }
            }
        }

        present(vc, animated: true, completion: nil)
    }
}
