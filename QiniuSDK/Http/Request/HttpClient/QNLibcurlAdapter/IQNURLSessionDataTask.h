//
//  IQNURLSessionDataTask.h
//  QiniuSDK
//
//  Created by yangsen on 2020/10/10.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol QNURLSessionDataTaskDelegate,IQNURLSession;


@protocol IQNURLSessionTaskTransactionMetrics <NSObject>

@property (copy, readonly) NSURLRequest *request;
@property (nullable, copy, readonly) NSURLResponse *response;

@property (nullable, copy, readonly) NSDate *fetchStartDate;
@property (nullable, copy, readonly) NSDate *domainLookupStartDate;
@property (nullable, copy, readonly) NSDate *domainLookupEndDate;

@property (nullable, copy, readonly) NSDate *connectStartDate;
@property (nullable, copy, readonly) NSDate *secureConnectionStartDate;
@property (nullable, copy, readonly) NSDate *secureConnectionEndDate;
@property (nullable, copy, readonly) NSDate *connectEndDate;

@property (nullable, copy, readonly) NSDate *requestStartDate;
@property (nullable, copy, readonly) NSDate *requestEndDate;

@property (nullable, copy, readonly) NSDate *responseStartDate;
@property (nullable, copy, readonly) NSDate *responseEndDate;

/*
 * The network protocol used to fetch the resource, as identified by the ALPN Protocol ID Identification Sequence [RFC7301].
 * E.g., h2, http/1.1, spdy/3.1.
 *
 * When a proxy is configured AND a tunnel connection is established, then this attribute returns the value for the tunneled protocol.
 *
 * For example:
 * If no proxy were used, and HTTP/2 was negotiated, then h2 would be returned.
 * If HTTP/1.1 were used to the proxy, and the tunneled connection was HTTP/2, then h2 would be returned.
 * If HTTP/1.1 were used to the proxy, and there were no tunnel, then http/1.1 would be returned.
 *
 */
@property (nullable, copy, readonly) NSString *networkProtocolName;

@property (assign, readonly, getter=isProxyConnection) BOOL proxyConnection;

@property (readonly) int64_t countOfRequestHeaderBytesSent;
@property (readonly) int64_t countOfRequestBodyBytesSent;
@property (readonly) int64_t countOfRequestBodyBytesBeforeEncoding;

@property (readonly) int64_t countOfResponseHeaderBytesReceived;
@property (readonly) int64_t countOfResponseBodyBytesReceived;
@property (readonly) int64_t countOfResponseBodyBytesAfterDecoding;

@property (nullable, copy, readonly) NSString *localAddress;
@property (nullable, copy, readonly) NSNumber *localPort;

@property (nullable, copy, readonly) NSString *remoteAddress;
@property (nullable, copy, readonly) NSNumber *remotePort;

@end

@protocol IQNURLSessionTaskMetrics <NSObject>

@property (  copy, readonly) NSArray<id <IQNURLSessionTaskTransactionMetrics>> *transactionMetrics;
@property (  copy, readonly) NSDate *startDate;
@property (  copy, readonly) NSDate *endDate;
@property (assign, readonly) NSUInteger redirectCount;

@end


@protocol IQNURLSessionDataTask <NSObject>

@property (readonly)                 NSUInteger    taskIdentifier;
@property (nullable, readonly, copy) NSURLRequest  *originalRequest;
@property (nullable, readonly, copy) NSURLRequest  *currentRequest;
@property (nullable, readonly, copy) NSURLResponse *response;

@property (readonly, strong) NSProgress *progress;
@property (nullable, copy) NSDate *earliestBeginDate;

@property (readonly) int64_t countOfBytesReceived;
@property (readonly) int64_t countOfBytesSent;
@property (readonly) int64_t countOfBytesExpectedToSend;
@property (readonly) int64_t countOfBytesExpectedToReceive;

@property (nullable, copy) NSString *taskDescription;
@property (readonly) NSURLSessionTaskState state;
@property (nullable, readonly, copy) NSError *error;

@property float priority;

// 外部不需要调用
+ (void)initResource;
+ (void)releaseResource;

- (instancetype)initWithURLSession:(id <IQNURLSession>)urlSession
                           request:(NSURLRequest *)request
                       delegate:(id <QNURLSessionDataTaskDelegate> _Nullable)delegate
         delegateOperationQueue:(NSOperationQueue *)delegateOperationQueue;

- (void)cancel;

- (void)resume;

@end

NS_ASSUME_NONNULL_END
