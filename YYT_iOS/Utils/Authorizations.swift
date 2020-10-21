//
//  Authorizations.swift
//  YYT_iOS
//
//  Created by evestorm on 2020/7/15.
//  Copyright © 2020 YYT. All rights reserved.
//  desc: 授权相关

import AssetsLibrary // 资源库
import AVFoundation // 媒体资源
import ContactsUI // 联系人
import CoreLocation // 地理位置
import CoreTelephony // 手机运营商等信息
import Foundation
// import EventKitUI // 系统日历与提醒交互
import PhotosUI // 电话

// MARK: 回调处理

typealias BWPrivacyAuthorizerCompletionClosure = (_ granted: Bool) -> Void

enum BWPrivacyAuthorizerStatus {
    case notDetermined // 尚未授权
    case restricted // 家长控制
    case denied // 拒绝
    case authorized // 已授权
}

// MARK: 常用权限状态，将各种权限状态转化成统一的自定义的权限状态，方便统一处理

// MARK: 定位授权状态

func bw_locationAuthorizationStatus() -> BWPrivacyAuthorizerStatus {
    let status = CLLocationManager.authorizationStatus()
    switch status {
    case .denied:
        return .denied
    case .notDetermined:
        return .notDetermined
    case .restricted:
        return .restricted
    case .authorized:
        return .authorized
    default:
        return .authorized
    }
}

// MARK: 通讯录授权状态

func bw_contactAuthorizationStatus() -> BWPrivacyAuthorizerStatus {
    let status = CNContactStore.authorizationStatus(for: .contacts)
    switch status {
    case .notDetermined:
        return .notDetermined
    case .restricted:
        return .restricted
    case .denied:
        return .denied
    case .authorized:
        return .authorized
    default:
        return .authorized
    }
}

// MARK: 相册授权状态

func bw_photoLibraryAuthorizationStatus() -> BWPrivacyAuthorizerStatus {
    if #available(iOS 9.0, *) {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        default:
            return .authorized
        }
    } else {
        let status = ALAssetsLibrary.authorizationStatus()
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        default:
            return .authorized
        }
    }
}

// MARK: 相机授权状态

func bw_cameraAuthorizationStatus() -> BWPrivacyAuthorizerStatus {
    let status = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
    switch status {
    case .notDetermined:
        return .notDetermined
    case .restricted:
        return .restricted
    case .denied:
        return .denied
    case .authorized:
        return .authorized
    default:
        return .authorized
    }
}

// 日历授权状态
// func bw_calendarAuthorizationStatus() -> BWPrivacyAuthorizerStatus {
//    let status = EKEventStore.authorizationStatus(for: EKEntityType.event)
//    switch status {
//    case .notDetermined:
//        return .notDetermined
//    case .restricted:
//        return .restricted
//    case .denied:
//        return .denied
//    case .authorized:
//        return .authorized
//    default:
//        return .authorized
//    }
// }

// 麦克风权限
// func bw_audioAuthorizationStatus() -> BWPrivacyAuthorizerStatus {
//    let status = AVAudioSession.sharedInstance().recordPermission
//    switch status {
//    case .undetermined:
//        return .notDetermined
//    case .denied:
//        return .denied
//    case .granted:
//        return .authorized
//    default:
//        return .authorized
//    }
// }

// MARK: 请求授权

//
//
//

// MARK: 通讯录相关权限

func bw_requestContactAuthorization(with completion: @escaping BWPrivacyAuthorizerCompletionClosure) {
    let status = bw_contactAuthorizationStatus()
    switch status {
    case .notDetermined:
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, _ in
            DispatchQueue.main.async {
                if granted == false {
                    bw_showAlertWithTitle("无法访问通讯录", message: bw_authorizationNotice(title: "通讯录"))
                }
                completion(granted)
            }
        }
    case .restricted, .denied:
        completion(false)
        bw_showAlertWithTitle("无法访问通讯录", message: bw_authorizationNotice(title: "通讯录"))
    case .authorized:
        completion(true)
    }
}

// MARK: 相册相关权限

func bw_requestPhotoLibraryAuthorization(with completion: @escaping BWPrivacyAuthorizerCompletionClosure) {
    let status = bw_photoLibraryAuthorizationStatus()
    switch status {
    case .notDetermined:
        if #available(iOS 9.0, *) {
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized:
                        completion(true)
                    default:
                        completion(false)
                        bw_showAlertWithTitle("无法访问照片", message: bw_authorizationNotice(title: "照片"))
                    }
                }
            }
        }
    case .restricted, .denied:
        bw_showAlertWithTitle("无法访问照片", message: bw_authorizationNotice(title: "照片"))
    case .authorized:
        completion(true)
    }
}

// MARK: 相机相关权限

func bw_requestCameraAuthorization(with completion: @escaping BWPrivacyAuthorizerCompletionClosure) {
    let status = bw_cameraAuthorizationStatus()
    switch status {
    case .notDetermined:
        AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
            DispatchQueue.main.async {
                if granted == false {
                    bw_showAlertWithTitle("无法访问相机", message: bw_authorizationNotice(title: "相机"))
                }
                completion(granted)
            }
        })
    case .restricted, .denied:
        bw_showAlertWithTitle("无法访问相机", message: bw_authorizationNotice(title: "相机"))
    case .authorized:
        completion(true)
    }
}

// MARK: 日历相关权限

// func bw_requestCalendarAuthorization(with completion: @escaping BWPrivacyAuthorizerCompletionClosure) {
//    let status = bw_calendarAuthorizationStatus()
//    switch status {
//    case .notDetermined:
//        let store = EKEventStore()
//        store.requestAccess(to: .event) { granted, _ in
//            DispatchQueue.main.async {
//                if granted == false {
//                    bw_showAlertWithTitle("无法访问日历", message: bw_authorizationNotice(title: "日历"))
//                }
//                completion(granted)
//            }
//        }
//    case .authorized:
//        completion(true)
//    case .restricted, .denied:
//        bw_showAlertWithTitle("无法访问日历", message: bw_authorizationNotice(title: "日历"))
//    }
// }

// MARK: 定位相关权限

func bw_requestLocationAuthorization(with locationManager: CLLocationManager, completion: @escaping BWPrivacyAuthorizerCompletionClosure) {
    let status = bw_locationAuthorizationStatus()
    switch status {
    case .denied, .restricted:
        completion(false)
        bw_showAlertWithTitle("无法开启定位", message: "请在iPhone的\"设置-隐私-位置\"中允许\(BWAppDispalyName)开启位置权限")
    case .notDetermined:
        locationManager.requestWhenInUseAuthorization()
    //            locationManager.startUpdatingLocation()
    case .authorized:
        completion(true)
    }
}

// MARK: 麦克风相关权限

// func bw_requestAudioAuthorization(with completion: @escaping BWPrivacyAuthorizerCompletionClosure) {
//    let status = bw_audioAuthorizationStatus()
//    switch status {
//    case .notDetermined:
//        AVAudioSession.sharedInstance().requestRecordPermission { granted in
//            DispatchQueue.main.async {
//                if granted == false {
//                    bw_showAlertWithTitle("无法访问麦克风", message: bw_authorizationNotice(title: "麦克风"))
//                }
//                completion(granted)
//            }
//        }
//    case .denied:
//        completion(true)
//        bw_showAlertWithTitle("无法访问麦克风", message: bw_authorizationNotice(title: "麦克风"))
//    case .authorized:
//        completion(true)
//    default:
//        break
//    }
// }

// MARK: 通知相关权限

func bw_notificationAuthorizationStatus(with completion: @escaping BWPrivacyAuthorizerCompletionClosure) {
    if #available(iOS 10.0, *) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                completion(true)
            case .notDetermined:
                completion(false)
            case .denied:
                completion(false)
            @unknown default:
                completion(false)
            }
        }
    } else {
        let isNotificationEnabled = UIApplication.shared.currentUserNotificationSettings?.types.contains(UIUserNotificationType.alert)
        if isNotificationEnabled == true {
            completion(true)
        } else {
            completion(false)
        }
    }
}

// MARK: 弹窗展示

private func bw_authorizationNotice(title: String) -> String {
    return "请在iPhone的\"设置-隐私-\(title)\"中允许\(BWAppDispalyName)访问\(title)"
}

private func bw_showAlertWithTitle(_ title: String, message: String) {
    let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
    let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
    let goAction = UIAlertAction(title: "前往设置", style: .default) { _ in
        if let settingUrl = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(settingUrl) {
//                UIApplication.shared.openURL(settingUrl)
                UIApplication.shared.open(settingUrl, options: [:], completionHandler: nil)
            }
        }
    }
    alertController.addAction(cancelAction)
    alertController.addAction(goAction)
    UIApplication.shared.keyWindow?.rootViewController?.present(alertController, animated: true, completion: nil)
}
