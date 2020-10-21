//
//  WX_Tools.swift
//  YYT_iOS
//
//  Created by evestorm on 2020/8/3.
//  Copyright © 2020 YYT. All rights reserved.
//  desc: 微信管理工具

import Alamofire
import AlamofireImage
import Foundation
import UIKit

class WeChatFunc: NSObject {
    // MARK: - 微信授权登录

    /// 发送Auth请求到微信，支持用户没安装微信，等待微信返回onResp
    /// - Parameters:
    ///   - wxApiDelegate: WXApiDelegate对象，用来接收微信触发的消息。
    ///   - currentVC: viewController 当前界面对象。
    static func sendWeChatLogin(wxApiDelegate: WXApiDelegate, currentVC: UIViewController) {
        // 构造SendAuthReq结构体
        let req = SendAuthReq()
        req.openID = WX_AppID
        req.scope = "snsapi_userinfo"
        req.state = "wx_oauth_authorization_state" // 用于保持请求和回调的状态，授权请求或原样带回。
        // 第三方向微信终端发送一个SendAuthReq消息结构
        WXApi.sendAuthReq(req, viewController: currentVC, delegate: wxApiDelegate, completion: nil)
    }

    /// 微信：获取用户个人信息（UnionID 机制）
    static func getWeChatUserInfo(code: String, success: @escaping (_ userInfo: [String: Any]) -> Void) {
        getWeChatAccessToken(code: code) { _, access_token, openid in
            self.getWeChatUserInfo(access_token: access_token, openID: openid) { userInfoJson in
                success(userInfoJson)
            }
        }
    }

    /// 微信：通过 code 获取 access_token、openid
    static func getWeChatAccessToken(code _: String, success: @escaping (_ result: [String: Any], _ access_token: String, _ openid: String) -> Void) {
        let urlString = "https://api.weixin.qq.com/sns/oauth2/access_token?appid=(WX_AppID)&secret=(WX_AppSecret)&code=(code)&grant_type=authorization_code"
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "GET"
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                if error == nil, data != nil {
                    do {
                        let dic = try JSONSerialization.jsonObject(with: data!, options: []) as! [String: Any]
                        let access_token = dic["access_token"] as! String
                        let openID = dic["openid"] as! String
                        //
                        success(dic, access_token, openID)
                    } catch {
                        print(#function)
                    }
                    return
                }
            }
        }.resume()
    }

    /// 微信：获取用户个人信息（UnionID 机制）
    static func getWeChatUserInfo(access_token _: String, openID _: String, success: @escaping (_ userInfo: [String: Any]) -> Void) {
        let urlString = "https://api.weixin.qq.com/sns/userinfo?access_token=(access_token)&openid=(openID)"
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "GET"
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                if error == nil, data != nil {
                    do {
                        let dic = try JSONSerialization.jsonObject(with: data!, options: []) as! [String: Any]
                        // dic当中包含了微信登录的个人信息，用于用户创建、登录、绑定等使用
                        success(dic)
                    } catch {
                        print(#function)
                    }
                    return
                }
            }
        }.resume()
    }

    // MARK: 微信分享

    /*
     @description 微信媒体消息内容 这里以发送图片+文字+链接形式（微信卡片形式）
     @param {UIImage} shareImage 分享图片
     @param {String} shareTitle 分享标题
     @param {String} shareDesc 分享描述文案
     @param {String} shareUrl 跳转链接
     */
    static func sendWXMediaMessage(shareImage: UIImage, shareTitle: String, shareDesc: String, shareUrl: String) {
        guard WXApi.isWXAppInstalled(), WXApi.isWXAppSupport() else {
            // 如果未安装微信或者微信版本过低，提示去安装或升级
            let ac = UIAlertController(title: "提醒", message: "您尚未安装微信或微信版本过低，请安装或升级微信", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "确定", style: .default))
            UIApplication.topViewController()?.present(ac, animated: true)

            return
        }
        let sendMessageToWXReq = SendMessageToWXReq()
        // 微信好友分享
        sendMessageToWXReq.scene = Int32(WXSceneSession.rawValue) // 朋友圈：WXSceneTimeline.rawValue
        sendMessageToWXReq.bText = false
        let wxMediaMessage = WXMediaMessage()
        wxMediaMessage.title = shareTitle
        wxMediaMessage.description = shareDesc
        // 压缩图片，防止图片数据过大导致分享无法成功，这里微信要求大小不能超过64K
        let thumImageData = UIImage.resetImgSize(sourceImage: shareImage, maxImageLenght: 300, maxSizeKB: 64)
        wxMediaMessage.thumbData = thumImageData as Data

        let wxWebPage = WXWebpageObject()
        wxWebPage.webpageUrl = shareUrl
        wxMediaMessage.mediaObject = wxWebPage
        sendMessageToWXReq.message = wxMediaMessage
        WXApi.send(sendMessageToWXReq)
    }

    /*
     @description 文字类型分享示例
     @param {String} 分享文字
     @param {Func} 闭包 版本过低时执行的操作
     */
    static func sendWXTextMessage(shareText: String) {
        guard WXApi.isWXAppInstalled(), WXApi.isWXAppSupport() else {
            // 如果未安装微信或者微信版本过低，提示去安装或升级
            let ac = UIAlertController(title: "提醒", message: "您尚未安装微信或微信版本过低，请安装或升级微信", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "确定", style: .default))
            UIApplication.topViewController()?.present(ac, animated: true)

            return
        }
        let sendMessageToWXReq = SendMessageToWXReq()
        sendMessageToWXReq.bText = true
        sendMessageToWXReq.text = shareText
        sendMessageToWXReq.scene = Int32(WXSceneSession.rawValue)
        WXApi.send(sendMessageToWXReq)
    }

    /*
     @description 分享图片
     @param {String} imageUrl 图片地址
     */
    static func sendWXImageMessage(imageUrl: String) {
        guard WXApi.isWXAppInstalled(), WXApi.isWXAppSupport() else {
            // 如果未安装微信或者微信版本过低，提示去安装或升级
            let ac = UIAlertController(title: "提醒", message: "您尚未安装微信或微信版本过低，请安装或升级微信", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "确定", style: .default))
            UIApplication.topViewController()?.present(ac, animated: true)

            return
        }
        let sendMessageToWXReq = SendMessageToWXReq()
        // 微信好友分享
        sendMessageToWXReq.scene = Int32(WXSceneSession.rawValue) // 朋友圈：WXSceneTimeline.rawValue
        sendMessageToWXReq.bText = false
        let wxMediaMessage = WXMediaMessage()

        if let url = URL(string: imageUrl), let data = try? Data(contentsOf: url) {
            let img = UIImage(data: data)
            // 压缩图片，防止图片数据过大导致分享无法成功，这里微信要求大小不能超过10M
            let thumImageData = UIImage.resetImgSize(sourceImage: img ?? UIImage(named: "zzylogo")!, maxImageLenght: 1024, maxSizeKB: 1024 * 10)
            let imageObject = WXImageObject()
            imageObject.imageData = thumImageData
            wxMediaMessage.mediaObject = imageObject
        }

        sendMessageToWXReq.message = wxMediaMessage
        WXApi.send(sendMessageToWXReq)
    }

    /*
     @description 发送到小程序
     @param {String} webpageUrl 网页链接
     @param {String} userName 小程序的userName 小程序原始ID获取方法：登录小程序管理后台-设置-基本设置-帐号信息
     @param {String} path 小程序的页面路径
     @param {String} hdImageData 小程序新版本的预览图二进制数据 限制大小不超过128KB，自定义图片建议长宽比是 5:4。
     @param {String} withShareTicket 是否使用带shareTicket的分享
     @param {String} programType 小程序的类型，默认正式版 release(正式) test(测试) preview(体验)
     @param {String} miniTitle 小程序标题
     @param {String} miniDescription 小程序描述
     */
    static func sendWXMiniProgramMessage(webpageUrl: String, userName: String, path: String, imageUrl: String, withShareTicket: Bool = false, programType: Int, miniTitle: String, miniDescription: String) {
        // 这里以发送图片+文字+链接形式（微信卡片形式）
        guard WXApi.isWXAppInstalled(), WXApi.isWXAppSupport() else {
            // 如果未安装微信或者微信版本过低，提示去安装或升级
            let ac = UIAlertController(title: "提醒", message: "您尚未安装微信或微信版本过低，请安装或升级微信", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "确定", style: .default))
            UIApplication.topViewController()?.present(ac, animated: true)
            return
        }

        let object = WXMiniProgramObject()
        object.webpageUrl = webpageUrl
        object.userName = userName
        object.path = path

        if let url = URL(string: imageUrl), let data = try? Data(contentsOf: url) {
//            object.hdImageData = try? Data(contentsOf: url)
            let img = UIImage(data: data)
            // 压缩图片，防止图片数据过大导致分享无法成功，这里微信要求大小不能超过64K
            let thumImageData = UIImage.resetImgSize(sourceImage: img ?? UIImage(named: "zzylogo")!, maxImageLenght: 300, maxSizeKB: 128)
            object.hdImageData = thumImageData as Data
        }

        object.withShareTicket = withShareTicket
        // ptype:正式版:0，测试版:1，体验版:2
        switch programType {
        case 0: // 正式版:0
            object.miniProgramType = WXMiniProgramType.release
        case 1: // 测试版:1
            object.miniProgramType = WXMiniProgramType.test
        case 2: // 体验版:2
            object.miniProgramType = WXMiniProgramType.preview
        default: // 默认正式版
            object.miniProgramType = WXMiniProgramType.release
        }
        let message = WXMediaMessage()
        message.title = miniTitle
        message.description = miniDescription
        message.thumbData = nil // 兼容旧版本节点的图片，小于32KB，新版本优先
        // 使用WXMiniProgramObject的hdImageData属性
        message.mediaObject = object
        let req = SendMessageToWXReq()
        req.bText = false
        req.message = message
        req.scene = Int32(WXSceneSession.rawValue) // 目前只支持会话
        WXApi.send(req)
    }
}
