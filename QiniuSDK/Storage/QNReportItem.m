//
//  QNReportItem.m
//  QiniuSDK
//
//  Created by yangsen on 2020/5/12.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNReportItem.h"
#import "QNAsyncRun.h"

@interface QNReportItem()

@property(nonatomic, strong)NSMutableDictionary *keyValues;

@end
@implementation QNReportItem

+ (instancetype)item{
    QNReportItem *item = [[QNReportItem alloc] init];
    return item;
}

- (instancetype)init{
    if (self = [super init]) {
        [self initData];
    }
    return self;
}

- (void)initData{
    _keyValues = [NSMutableDictionary dictionary];
}

- (void)setReportValue:(id _Nullable)value forKey:(NSString * _Nullable)key{
    if (!value || !key || ![key isKindOfClass:[NSString class]]) {
        return;
    }
    [self.keyValues setValue:value forKey:key];
}

- (void)removeReportValueForKey:(NSString * _Nullable)key{
    if (!key) {
        return;
    }
    [self.keyValues removeObjectForKey:key];
}


- (NSString *)toJson{
    
    NSString *jsonString = @"{}";
    if (!self.keyValues || self.keyValues.count == 0) {
        return jsonString;
    }
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self.keyValues
                                                       options:NSJSONWritingFragmentsAllowed
                                                         error:nil];
    if (!jsonData) {
        return jsonString;
    }
    
    jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return jsonString;
}

@end

@implementation QNUploadInfoReporter(ReportItem)

- (void)reportItem:(QNReportItem *)item token:(NSString *)token{
    QNAsyncRun(^{
        NSString *itemJsonString = [item toJson];
        if (itemJsonString && ![itemJsonString isEqualToString:@"{}"]) {
            [self report:itemJsonString token:token];
            NSLog(@"== report log: %@", itemJsonString);
        }
    });
}

@end

@implementation QNResponseInfo(Report)

- (NSNumber *)requestReportStatusCode{
    if (self.statusCode > -10 && self.statusCode < 0) {
        return @(self.statusCode);
    } else {
        return nil;
    }
}

- (NSString *)requestReportErrorType{
    NSString *errorType = nil;
    if (self.statusCode > 199 && self.statusCode < 300) {
        
    } else if (self.statusCode > 299){
        errorType = @"response_error";
    } else if (self.statusCode == QNResponseInfoErrorTypeNetworkError
            || self.statusCode == -1003 || self.statusCode == -1006 || self.statusCode == -1008){
        errorType = @"network_error";
    } else if (self.statusCode == -1009){
           errorType = @"network_slow";
    } else if (self.statusCode == -1001){
           errorType = @"timeout";
    } else if (self.statusCode == -1004){
        errorType = @"cannot_connect_to_host";
    } else if (self.statusCode == -1005 || self.statusCode == -1011){
        errorType = @"transmission_error";
    } else if (self.statusCode == -2001 ||self.statusCode == -9807){
        errorType = @"ssl_error";
    } else if (self.statusCode == -1015 || self.statusCode == -1016 || self.statusCode == -1017){
        errorType = @"parse_error";
    } else if (self.statusCode == -1007 || self.statusCode == -1010){
        errorType = @"malicious_response";
    } else if (self.statusCode == QNResponseInfoErrorTypeUserCanceled
            || self.statusCode == -999){//  NSURLErrorCancelled
        errorType = @"user_canceled";
    } else {
        errorType = @"unknown_error";
    }
    return errorType;
}

- (NSString *)qualityResult{
    NSString *result = nil;
    if (self.statusCode > 199 && self.statusCode < 300) {
        result = @"ok";
    } else if (self.statusCode > 399 && self.statusCode < 500) {
        result = @"bad_request";
    } else if (self.statusCode == QNResponseInfoErrorTypeZeroSizeFile){
        result = @"zero_size_file";
    } else if (self.statusCode == QNResponseInfoErrorTypeInvalidFile){
        result = @"invalid_file";
    } else if (self.statusCode == QNResponseInfoErrorTypeInvalidToken
            || self.statusCode == QNResponseInfoErrorTypeInvalidArgs){
        result = @"invalid_args";
    } else if (self.statusCode == QNResponseInfoErrorTypeUserCanceled
            || self.statusCode == -999){
        result = @"user_canceled";
    } else if (self.statusCode == QNResponseInfoErrorTypeNetworkError){
        result = @"zero_size_file";
    } else if (self.statusCode == -1009){
        result = @"network_error";
    } else if (self.statusCode == -1001){
        result = @"timeout";
    } else if (self.statusCode == -1004){
        result = @"cannot_connect_to_host";
    } else if (self.statusCode == -1005 || self.statusCode == -1011){
        result = @"transmission_error";
    } else if (self.statusCode == -2001 ||self.statusCode == -9807){
        result = @"ssl_error";
    } else if (self.statusCode == -1015 || self.statusCode == -1016 || self.statusCode == -1017){
        result = @"parse_error";
    } else if (self.statusCode == -1007 || self.statusCode == -1010){
        result = @"malicious_response";
    } else {
        result = @"unknown_error";
    }
    return result;
}

@end


//MARK:-- 日志类型
NSString * const QNReportLogTypeRequest = @"request";
NSString * const QNReportLogTypeBlock = @"block";
NSString * const QNReportLogTypeQuality = @"quality";


//MARK:-- 请求信息打点⽇志
NSString * const QNReportRequestKeyLogType = @"log_type";
NSString *const QNReportRequestKeyUpTime = @"up_time";
NSString * const QNReportRequestKeyStatusCode = @"status_code";
NSString * const QNReportRequestKeyRequestId = @"req_id";
NSString * const QNReportRequestKeyHost = @"host";
NSString * const QNReportRequestKeyRemoteIp = @"remote_ip";
NSString * const QNReportRequestKeyPort = @"port";
NSString * const QNReportRequestKeyTargetBucket = @"target_bucket";
NSString * const QNReportRequestKeyTargetKey = @"target_key";
NSString * const QNReportRequestKeyTotalElaspsedTime = @"total_elaspsed_time";
NSString * const QNReportRequestKeyDnsElapsedTime = @"dns_elapsed_time";
NSString * const QNReportRequestKeyConnectElapsedTime = @"connect_elapsed_time";
NSString * const QNReportRequestKeyTLSConnectElapsedTime = @"tls_connect_elapsed_time";
NSString * const QNReportRequestKeyRequestElapsedTime = @"request_elapsed_time";
NSString * const QNReportRequestKeyWaitElapsedTime = @"wait_elapsed_time";
NSString * const QNReportRequestKeyResponseElapsedTime = @"response_elapsed_time";
NSString * const QNReportRequestKeyFileOffset = @"file_offset";
NSString * const QNReportRequestKeyBytesSent = @"bytes_sent";
NSString * const QNReportRequestKeyBytesTotal = @"bytes_total";
NSString * const QNReportRequestKeyPid = @"pid";
NSString * const QNReportRequestKeyTid = @"tid";
NSString * const QNReportRequestKeyTargetRegionId = @"target_region_id";
NSString * const QNReportRequestKeyCurrentRegionId = @"current_region_id";
NSString * const QNReportRequestKeyErrorType = @"error_type";
NSString * const QNReportRequestKeyErrorDescription = @"error_description";
NSString * const QNReportRequestKeyUpType = @"up_type";
NSString * const QNReportRequestKeyOsName = @"os_name";
NSString * const QNReportRequestKeyOsVersion = @"os_version";
NSString * const QNReportRequestKeySDKName = @"sdk_name";
NSString * const QNReportRequestKeySDKVersion = @"sdk_version";
NSString * const QNReportRequestKeyClientTime = @"client_time";
NSString * const QNReportRequestKeyNetworkType = @"network_type";
NSString * const QNReportRequestKeySignalStrength = @"signal_strength";
NSString * const QNReportRequestKeyPrefetchedIpCount = @"prefetched_ip_count";


//MARK:-- 分块上传统计⽇志
NSString * const QNReportBlockKeyLogType = @"log_type";
NSString *const QNReportBlockKeyUpTime = @"up_time";
NSString * const QNReportBlockKeyTargetRegionId = @"target_region_id";
NSString * const QNReportBlockKeyCurrentRegionId = @"current_region_id";
NSString * const QNReportBlockKeyTotalElaspsedTime = @"total_elaspsed_time";
NSString * const QNReportBlockKeyBytesSent = @"bytes_sent";
NSString * const QNReportBlockKeyRecoveredFrom = @"recovered_from";
NSString * const QNReportBlockKeyFileSize = @"file_size";
NSString * const QNReportBlockKeyPid = @"pid";
NSString * const QNReportBlockKeyTid = @"tid";
NSString * const QNReportBlockKeyUpApiVersion = @"up_api_version";
NSString * const QNReportBlockKeyClientTime = @"client_time";


//MARK:-- 上传质量统计
NSString * const QNReportQualityKeyLogType = @"log_type";
NSString *const QNReportQualityKeyUpTime = @"up_time";
NSString * const QNReportQualityKeyResult = @"result";
NSString * const QNReportQualityKeyTotalElaspsedTime = @"total_elaspsed_time";
NSString * const QNReportQualityKeyRequestsCount = @"requests_count";
NSString * const QNReportQualityKeyRegionsCount = @"regions_count";
NSString * const QNReportQualityKeyBytesSent = @"bytes_sent";
NSString * const QNReportQualityKeyCloudType = @"cloud_type";