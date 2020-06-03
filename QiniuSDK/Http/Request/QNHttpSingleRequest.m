//
//  QNHttpRequest+SingleRequestRetry.m
//  QiniuSDK
//
//  Created by yangsen on 2020/4/29.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNAsyncRun.h"
#import "QNVersion.h"
#import "QNUtils.h"
#import "QNHttpSingleRequest.h"
#import "QNConfiguration.h"
#import "QNUploadOption.h"
#import "QNUpToken.h"
#import "QNResponseInfo.h"
#import "QNRequestClient.h"

#import "QNReportItem.h"

#import "QNUploadSystemClient.h"
#import "NSURLRequest+QNRequest.h"


@implementation QNUploadRequstState
- (instancetype)init{
    if (self = [super init]) {
        [self initData];
    }
    return self;
}
- (void)initData{
    _isUserCancel = NO;
}
@end



@interface QNHttpSingleRequest()

@property(nonatomic, assign)int currentRetryTime;
@property(nonatomic, strong)QNConfiguration *config;
@property(nonatomic, strong)QNUploadOption *uploadOption;
@property(nonatomic, strong)QNUpToken *token;
@property(nonatomic, strong)QNUploadRequestInfo *requestInfo;
@property(nonatomic, strong)QNUploadRequstState *requestState;

@property(nonatomic, strong)NSMutableArray <QNUploadSingleRequestMetrics *> *requestMetricsList;

@property(nonatomic, strong)id <QNRequestClient> client;

@end
@implementation QNHttpSingleRequest

- (instancetype)initWithConfig:(QNConfiguration *)config
                  uploadOption:(QNUploadOption *)uploadOption
                         token:(QNUpToken *)token
                   requestInfo:(QNUploadRequestInfo *)requestInfo
                  requestState:(QNUploadRequstState *)requestState{
    if (self = [super init]) {
        _config = config;
        _uploadOption = uploadOption;
        _token = token;
        _requestInfo = requestInfo;
        _requestState = requestState;
        _currentRetryTime = 1;
    }
    return self;
}

- (void)request:(NSURLRequest *)request
      isSkipDns:(BOOL)isSkipDns
    shouldRetry:(BOOL(^)(QNResponseInfo *responseInfo, NSDictionary *response))shouldRetry
       progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
       complete:(QNSingleRequestCompleteHandler)complete{
    
    _currentRetryTime = 1;
    _requestMetricsList = [NSMutableArray array];
    [self retryRquest:request isSkipDns:isSkipDns shouldRetry:shouldRetry progress:progress complete:complete];
}

- (void)retryRquest:(NSURLRequest *)request
          isSkipDns:(BOOL)isSkipDns
        shouldRetry:(BOOL(^)(QNResponseInfo *responseInfo, NSDictionary *response))shouldRetry
           progress:(void(^)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
           complete:(QNSingleRequestCompleteHandler)complete{
    
    if (isSkipDns && kQNGloableConfiguration.isDnsOpen) {
        self.client = [[QNUploadSystemClient alloc] init];
    } else {
        self.client = [[QNUploadSystemClient alloc] init];
    }
    
    NSLog(@"QN Single Request:%@ / %@", request.URL.absoluteString, request.qn_domain);
    
    __weak typeof(self) weakSelf = self;
    BOOL (^checkCancelHandler)(void) = ^{
        BOOL isCancel = weakSelf.requestState.isUserCancel;
        if (!isCancel && weakSelf.uploadOption.cancellationSignal) {
            isCancel = weakSelf.uploadOption.cancellationSignal();
        }
        return isCancel;
    };
    
    [self.client request:request connectionProxy:self.config.proxy progress:^(long long totalBytesWritten, long long totalBytesExpectedToWrite) {
        
        if (checkCancelHandler()) {
            weakSelf.requestState.isUserCancel = YES;
            [weakSelf.client cancel];
        } else if (progress) {
            progress(totalBytesWritten, totalBytesExpectedToWrite);
        }
        
    } complete:^(NSURLResponse *response, QNUploadSingleRequestMetrics *metrics, NSData * responseData, NSError * error) {
        
        if (metrics) {
            [self.requestMetricsList addObject:metrics];
        }
        
        QNResponseInfo *responseInfo = nil;
        if (checkCancelHandler()) {
            responseInfo = [QNResponseInfo cancelResponse];
            [self complete:responseInfo response:nil requestMetrics:metrics complete:complete];
            return;
        }
        
        NSDictionary *responseDic = nil;
        if (responseData) {
            responseDic = [NSJSONSerialization JSONObjectWithData:responseData
                                                          options:NSJSONReadingMutableLeaves
                                                            error:nil];
        }
        
        responseInfo = [[QNResponseInfo alloc] initWithResponseInfoHost:request.qn_domain
                                                               response:(NSHTTPURLResponse *)response
                                                                   body:responseData
                                                                  error:error];
        if (shouldRetry(responseInfo, responseDic)
            && self.currentRetryTime < self.config.retryMax
            && responseInfo.couldHostRetry) {
            self.currentRetryTime += 1;
            QNAsyncRunAfter(self.config.retryInterval, kQNBackgroundQueue, ^{
                [self retryRquest:request isSkipDns:isSkipDns shouldRetry:shouldRetry progress:progress complete:complete];
            });
        } else {
            [self complete:responseInfo response:responseDic requestMetrics:metrics complete:complete];
        }
    }];
    
}

- (void)complete:(QNResponseInfo *)responseInfo
        response:(NSDictionary *)response
  requestMetrics:(QNUploadSingleRequestMetrics *)requestMetrics
        complete:(QNSingleRequestCompleteHandler)complete {
    
    [self reportRequest:responseInfo requestMetrics:requestMetrics];
    if (complete) {
        complete(responseInfo, [self.requestMetricsList copy], response);
    }
}

//MARK:-- 统计quality日志
- (void)reportRequest:(QNResponseInfo *)info
       requestMetrics:(QNUploadSingleRequestMetrics *)requestMetrics {
    
    QNUploadSingleRequestMetrics *requestMetricsP = requestMetrics ?: [QNUploadSingleRequestMetrics emptyMetrics];
    
    QNReportItem *item = [QNReportItem item];
    [item setReportValue:QNReportLogTypeRequest forKey:QNReportRequestKeyLogType];
    [item setReportValue:@([[NSDate date] timeIntervalSince1970]) forKey:QNReportRequestKeyUpTime];
    [item setReportValue:info.requestReportStatusCode forKey:QNReportRequestKeyStatusCode];
    [item setReportValue:info.reqId forKey:QNReportRequestKeyRequestId];
    [item setReportValue:requestMetricsP.request.qn_domain forKey:QNReportRequestKeyHost];
    [item setReportValue:requestMetricsP.remoteAddress forKey:QNReportRequestKeyRemoteIp];
    [item setReportValue:requestMetricsP.localPort forKey:QNReportRequestKeyPort];
    [item setReportValue:self.requestInfo.bucket forKey:QNReportRequestKeyTargetBucket];
    [item setReportValue:self.requestInfo.key forKey:QNReportRequestKeyTargetKey];
    [item setReportValue:requestMetricsP.totalElaspsedTime forKey:QNReportRequestKeyTotalElaspsedTime];
    [item setReportValue:requestMetricsP.totalDnsTime forKey:QNReportRequestKeyDnsElapsedTime];
    [item setReportValue:requestMetricsP.totalConnectTime forKey:QNReportRequestKeyConnectElapsedTime];
    [item setReportValue:requestMetricsP.totalSecureConnectTime forKey:QNReportRequestKeyTLSConnectElapsedTime];
    [item setReportValue:requestMetricsP.totalRequestTime forKey:QNReportRequestKeyRequestElapsedTime];
    [item setReportValue:requestMetricsP.totalWaitTime forKey:QNReportRequestKeyWaitElapsedTime];
    [item setReportValue:requestMetricsP.totalWaitTime forKey:QNReportRequestKeyResponseElapsedTime];
    [item setReportValue:requestMetricsP.totalResponseTime forKey:QNReportRequestKeyResponseElapsedTime];
    [item setReportValue:self.requestInfo.fileOffset forKey:QNReportRequestKeyFileOffset];
    [item setReportValue:requestMetricsP.bytesSend forKey:QNReportRequestKeyBytesSent];
    [item setReportValue:requestMetricsP.totalBytes forKey:QNReportRequestKeyBytesTotal];
    [item setReportValue:@([QNUtils getCurrentProcessID]) forKey:QNReportRequestKeyPid];
    [item setReportValue:@([QNUtils getCurrentThreadID]) forKey:QNReportRequestKeyTid];
    [item setReportValue:self.requestInfo.targetRegionId forKey:QNReportRequestKeyTargetRegionId];
    [item setReportValue:self.requestInfo.currentRegionId forKey:QNReportRequestKeyCurrentRegionId];
    [item setReportValue:info.requestReportErrorType forKey:QNReportRequestKeyErrorType];
    NSString *errorDesc = info.requestReportErrorType ? info.message : nil;
    [item setReportValue:errorDesc forKey:QNReportRequestKeyErrorDescription];
    [item setReportValue:self.requestInfo.requestType forKey:QNReportRequestKeyUpType]; 
    [item setReportValue:[QNUtils systemName] forKey:QNReportRequestKeyOsName];
    [item setReportValue:[QNUtils systemVersion] forKey:QNReportRequestKeyOsVersion];
    [item setReportValue:[QNUtils sdkLanguage] forKey:QNReportRequestKeySDKName];
    [item setReportValue:kQiniuVersion forKey:QNReportRequestKeySDKVersion];
    [item setReportValue:@([QNUtils currentTimestamp]) forKey:QNReportRequestKeyClientTime];
    [item setReportValue:[QNUtils getCurrentNetworkType] forKey:QNReportRequestKeyNetworkType];
    [item setReportValue:[QNUtils getCurrentSignalStrength] forKey:QNReportRequestKeySignalStrength];

    [kQNReporter reportItem:item token:self.token.token];
}

@end