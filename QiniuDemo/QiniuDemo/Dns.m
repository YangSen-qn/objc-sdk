//
//  Dns.m
//  QiniuDemo
//
//  Created by yangsen on 2020/10/10.
//  Copyright © 2020 Aaron. All rights reserved.
//

#import "Dns.h"


@implementation DnsNetworkAddress
- (NSString *)sourceValue{
    return @"customized";
}
@end

@implementation Dns

- (NSArray<id<QNIDnsNetworkAddress>> *)lookup:(NSString *)host{
    if (![host isEqualToString:@"up.qiniu.com"]) {
        return nil;
    }
    
    DnsNetworkAddress *address = [[DnsNetworkAddress alloc] init];
    address.hostValue = host;
    address.ipValue = @"10.200.20.57";
    address.ttlValue = @120;
    address.timestampValue = @([[NSDate date] timeIntervalSince1970]);
    return @[address];
}

@end
