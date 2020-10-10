//
//  Dns.h
//  QiniuDemo
//
//  Created by yangsen on 2020/10/10.
//  Copyright © 2020 Aaron. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Qiniu/QiniuSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface DnsNetworkAddress : NSObject<QNIDnsNetworkAddress>

/// 域名
@property(nonatomic,  copy)NSString *hostValue;

/// 地址IP信息
@property(nonatomic,  copy)NSString *ipValue;

/// ip有效时间 单位：秒
@property(nonatomic, strong)NSNumber *ttlValue;

/// ip预取来源, 自定义dns返回 @"customized"
@property(nonatomic,  copy)NSString *sourceValue;

/// 解析到host时的时间戳 单位：秒
@property(nonatomic, strong)NSNumber *timestampValue;

@end

@interface Dns : NSObject<QNDnsDelegate>

@end

NS_ASSUME_NONNULL_END
