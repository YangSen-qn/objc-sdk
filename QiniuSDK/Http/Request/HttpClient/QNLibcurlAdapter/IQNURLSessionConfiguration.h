//
//  IQNURLSessionConfiguration.h
//  QiniuSDK
//
//  Created by yangsen on 2020/10/10.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol IQNDnsResolver <NSObject>

@property(nonatomic,   copy, readonly)NSString *host;
@property(nonatomic,   copy, readonly)NSString *ip;
@property(nonatomic, assign, readonly)NSInteger port;

- (instancetype)initWithHost:(NSString *)host
                          ip:(NSString *)ip
                        port:(NSInteger)port;

- (NSString *)resolverString;

@end

@protocol IQNURLSessionConfiguration <NSObject>

@property (nonatomic, strong)NSArray <id <IQNDnsResolver>> *dnsResolverArray;

/* The proxy dictionary, as described by <CFNetwork/CFHTTPStream.h> */
@property (nullable,    copy) NSDictionary *connectionProxyDictionary;

/* Allow the use of HTTP pipelining */
@property BOOL HTTPShouldUsePipelining;

/* Specifies additional headers which will be set on outgoing requests.
   Note that these headers are added to the request only if not already present. */
@property (nullable,    copy) NSDictionary *HTTPAdditionalHeaders;

@end

NS_ASSUME_NONNULL_END
