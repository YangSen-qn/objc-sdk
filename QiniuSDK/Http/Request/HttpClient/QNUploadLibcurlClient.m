//
//  QNUploadLibcurlClient.m
//  QiniuSDK
//
//  Created by yangsen on 2020/8/26.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "IQNURLSessionDataTask.h"
#import "IQNURLSessionConfiguration.h"
#import "IQNURLSession.h"

#import "QNUploadLibcurlClient.h"
#import "QNUserAgent.h"
#import "NSURLRequest+QNRequest.h"
#import "QNURLProtocol.h"

@interface QNUploadLibcurlClient()

@property(nonatomic, strong)QNUploadSingleRequestMetrics *requestMetrics;

@property(nonatomic, strong)id <IQNURLSessionDataTask> uploadTask;


@property(nonatomic, strong)NSMutableData *responseData;
@property(nonatomic,   copy)void(^progress)(long long totalBytesWritten, long long totalBytesExpectedToWrite);
@property(nonatomic,  copy)QNRequestClientCompleteHandler complete;

@end
@implementation QNUploadLibcurlClient

- (void)request:(NSURLRequest *)request
connectionProxy:(NSDictionary *)connectionProxy
       progress:(void (^)(long long, long long))progress
       complete:(QNRequestClientCompleteHandler)complete {
    
    if (!kIsLoadLibcurl()) {
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:-1003 userInfo:@{@"error" : @"no libcurl exist"}];
        complete(nil, nil, nil, error);
        return;
    }
    
    self.requestMetrics = [QNUploadSingleRequestMetrics emptyMetrics];
    self.requestMetrics.remoteAddress = request.qn_ip;
    self.requestMetrics.startDate = [NSDate date];
    
    self.responseData = [NSMutableData data];
    self.progress = progress;
    self.complete = complete;
    
    Class QNURLSessionConfiguration = NSClassFromString(@"QNURLSessionConfiguration");
    id <IQNURLSessionConfiguration> _Nonnull configuration = [[QNURLSessionConfiguration alloc] init];
    if (request.qn_ip.length > 0 && request.qn_domain.length > 0) {
        Class QNDnsResolver = NSClassFromString(@"QNDnsResolver");
        id <IQNDnsResolver> resolver = [[QNDnsResolver alloc] initWithHost:request.qn_domain
                                                                        ip:request.qn_ip
                                                                      port:request.qn_isHttps ? 443 : 80];
        configuration.dnsResolverArray = @[resolver];
        
    }
    if (connectionProxy) {
        configuration.connectionProxyDictionary = connectionProxy;
    }
    
    Class QNURLSession = NSClassFromString(@"QNURLSession");
    id <IQNURLSession> session = (id <IQNURLSession>)[QNURLSession sessionWithConfiguration:(NSURLSessionConfiguration *)configuration
                                                                                   delegate:(id <NSURLSessionDelegate>)self
                                                                              delegateQueue:nil];
    
    id <IQNURLSessionDataTask> uploadTask = [session dataTaskWithRequest:request];
    [uploadTask resume];
    
    self.uploadTask = uploadTask;
}

- (void)cancel{
    
#if LoadLibCurl
    [self.uploadTask cancel];
#endif
    
}

//MARK:-- QNURLSessionDelegate
- (void)URLSession:(id <IQNURLSession>)session dataTask:(id <IQNURLSessionDataTask>)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(id <IQNURLSession>)session dataTask:(id <IQNURLSessionDataTask>)dataTask didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
}

- (void)URLSession:(id <IQNURLSession>)session task:(id <IQNURLSessionDataTask>)task didCompleteWithError:(nullable NSError *)error {
    
    self.requestMetrics.endDate = [NSDate date];
    self.requestMetrics.request = task.currentRequest;
    self.requestMetrics.response = task.response;
    self.requestMetrics.countOfResponseBodyBytesReceived = task.response.expectedContentLength;
    self.requestMetrics.countOfRequestHeaderBytesSent = [NSString stringWithFormat:@"%@", task.currentRequest.allHTTPHeaderFields].length;
    self.complete(task.response, self.requestMetrics,self.responseData, error);
    
//    [session finishTasksAndInvalidate];
}

- (void)URLSession:(id <IQNURLSession>)session task:(id <IQNURLSessionDataTask>)task didFinishCollectingMetrics:(id <IQNURLSessionTaskMetrics>)metrics {
    
    id <IQNURLSessionTaskTransactionMetrics> transactionMetrics = metrics.transactionMetrics.lastObject;
    
    self.requestMetrics.domainLookupStartDate = transactionMetrics.domainLookupStartDate;
    self.requestMetrics.domainLookupEndDate = transactionMetrics.domainLookupEndDate;
    self.requestMetrics.connectStartDate = transactionMetrics.connectStartDate;
    self.requestMetrics.secureConnectionStartDate = transactionMetrics.secureConnectionStartDate;
    self.requestMetrics.secureConnectionEndDate = transactionMetrics.secureConnectionEndDate;
    self.requestMetrics.connectEndDate = transactionMetrics.connectEndDate;
    
    self.requestMetrics.requestStartDate = transactionMetrics.requestStartDate;
    self.requestMetrics.requestEndDate = transactionMetrics.requestEndDate;
    self.requestMetrics.responseStartDate = transactionMetrics.responseStartDate;
    self.requestMetrics.responseEndDate = transactionMetrics.responseEndDate;
    
    self.requestMetrics.localAddress = transactionMetrics.localAddress;
    self.requestMetrics.localPort = transactionMetrics.localPort;
    self.requestMetrics.remoteAddress = transactionMetrics.remoteAddress;
    self.requestMetrics.remotePort = transactionMetrics.remotePort;
}

- (void)URLSession:(id <IQNURLSession>)session
              task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    
    self.requestMetrics.countOfRequestBodyBytesSent = totalBytesSent;
    if (self.progress) {
        self.progress(totalBytesSent, totalBytesExpectedToSend);
    }
}

- (void)URLSession:(id <IQNURLSession>)session task:(id <IQNURLSessionDataTask>)task didReceiveBodyData:(int64_t)bytesReceive totalBytesReceive:(int64_t)totalBytesReceive totalBytesExpectedToReceive:(int64_t)totalBytesExpectedToReceive{
    
}

@end

extern BOOL kIsLoadLibcurl(){
    return NSClassFromString(@"QNURLSession");
}
