//
//  QNUploadLibcurlClient.m
//  QiniuSDK
//
//  Created by yangsen on 2020/8/26.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNUploadLibcurlClient.h"
#import "QNUserAgent.h"
#import "NSURLRequest+QNRequest.h"
#import "QNURLProtocol.h"
#import "QNLibcurl.h"

@interface QNUploadLibcurlClient()<QNURLSessionDataTaskDelegate>

@property(nonatomic, strong)QNUploadSingleRequestMetrics *requestMetrics;
@property(nonatomic, strong)QNURLSessionDataTask *uploadTask;
@property(nonatomic, strong)NSMutableData *responseData;
@property(nonatomic,   copy)void(^progress)(long long totalBytesWritten, long long totalBytesExpectedToWrite);
@property(nonatomic,  copy)QNRequestClientCompleteHandler complete;

@end
@implementation QNUploadLibcurlClient

- (void)request:(NSURLRequest *)request
connectionProxy:(NSDictionary *)connectionProxy
       progress:(void (^)(long long, long long))progress
       complete:(QNRequestClientCompleteHandler)complete {
    
    self.requestMetrics = [QNUploadSingleRequestMetrics emptyMetrics];
    self.requestMetrics.remoteAddress = request.qn_ip;
    self.requestMetrics.startDate = [NSDate date];
    
    self.responseData = [NSMutableData data];
    self.progress = progress;
    self.complete = complete;
    
    QNURLSessionConfiguration *configuration = [[QNURLSessionConfiguration alloc] init];
    if (request.qn_ip.length > 0 && request.qn_domain.length > 0) {
        QNDnsResolver *resolver = [[QNDnsResolver alloc] initWithHost:request.qn_domain
                                                                   ip:request.qn_ip
                                                                 port:request.qn_isHttps ? 443 : 80];
        configuration.dnsResolverArray = @[resolver];
        
    }
    if (connectionProxy) {
        configuration.connectionProxyDictionary = connectionProxy;
    }
    QNURLSession *session = [QNURLSession sessionWithConfiguration:configuration
                                                          delegate:self
                                                     delegateQueue:nil];
    QNURLSessionDataTask *uploadTask = [session dataTaskWithRequest:request];
    [uploadTask resume];
    
    self.uploadTask = uploadTask;
}

- (void)cancel{
    [self.uploadTask cancel];
}

//MARK:-- QNURLSessionDelegate
- (void)URLSession:(QNURLSession *)session dataTask:(QNURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(QNURLSession *)session dataTask:(QNURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
}

- (void)URLSession:(QNURLSession *)session task:(QNURLSessionDataTask *)task didCompleteWithError:(nullable NSError *)error {
    
    self.requestMetrics.endDate = [NSDate date];
    self.requestMetrics.request = task.currentRequest;
    self.requestMetrics.response = task.response;
    self.requestMetrics.countOfResponseBodyBytesReceived = task.response.expectedContentLength;
    self.requestMetrics.countOfRequestHeaderBytesSent = [NSString stringWithFormat:@"%@", task.currentRequest.allHTTPHeaderFields].length;
    self.complete(task.response, self.requestMetrics,self.responseData, error);
    
//    [session finishTasksAndInvalidate];
}

- (void)URLSession:(QNURLSession *)session task:(QNURLSessionDataTask *)task didFinishCollectingMetrics:(QNURLSessionTaskMetrics *)metrics {
    QNURLSessionTaskTransactionMetrics *transactionMetrics = metrics.transactionMetrics.lastObject;
    
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

- (void)URLSession:(QNURLSession *)session task:(NSURLSessionTask *)task
             didSendBodyData:(int64_t)bytesSent
              totalBytesSent:(int64_t)totalBytesSent
    totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    
    self.requestMetrics.countOfRequestBodyBytesSent = totalBytesSent;
    if (self.progress) {
        self.progress(totalBytesSent, totalBytesExpectedToSend);
    }
}

- (void)URLSession:(QNURLSession *)session task:(QNURLSessionTask *)task didReceiveBodyData:(int64_t)bytesReceive totalBytesReceive:(int64_t)totalBytesReceive totalBytesExpectedToReceive:(int64_t)totalBytesExpectedToReceive{
    
}

@end
