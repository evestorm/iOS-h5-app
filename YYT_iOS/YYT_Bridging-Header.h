//
//  WX_Bridging-Header.h
//  YYT_iOS
//
//  Created by evestorm on 2020/8/3.
//  Copyright © 2020 YYT. All rights reserved.
//

#ifndef YYT_Bridging_Header_h
#define YYT_Bridging_Header_h

// 微信
#define WX_AppID @"wx54cb281b0a7f0c9a"
#define WX_AppSecret @"2e9252a191e59604a569051ac61ace28"

// 微信-通用链接 Universal Link
#define WX_UNIVERSAL_LINK @"https://pic.cwyyt.cn/"

#ifdef __OBJC__

// 微信授权登录
#import "WXApi.h"

/*极光推送*/
#import "JPUSHService.h"
// iOS10注册APNs所需头文件
//#ifdef NSFoundationVersionNumber_iOS_9_x_Max
#import <UserNotifications/UserNotifications.h>

#endif

#endif /* YYT_Bridging_Header_h */
