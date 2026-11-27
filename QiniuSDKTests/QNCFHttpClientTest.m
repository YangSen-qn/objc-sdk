//
//  QNCFHttpClientTest.m
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/4/17.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "QNCFHttpClient.h"
#import "NSURLRequest+QNRequest.h"
#import "QNCFHttpClientInner.h"
#import "QNTestConfig.h"
#import "QNUpToken.h"
#import "XCTestCase+QNTest.h"
#import <XCTest/XCTest.h>
#import <netinet/in.h>
#import <sys/socket.h>
#import <unistd.h>

@interface QNCFHttpClientInner (TestPrivate)
- (NSInputStream *)createInputStream:(NSURLRequest *)urlRequest;
- (void)inputStreamDrainRemainingData;
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode;
@end

@interface QNNilInputStreamClient : QNCFHttpClientInner
@end

@implementation QNNilInputStreamClient

// 测试底层流创建失败时是否能进入错误终态。
- (NSInputStream *)createInputStream:(NSURLRequest *)urlRequest {
    return nil;
}

@end

@interface QNZeroReadInputStream : NSInputStream
@property(nonatomic, assign)NSInteger readCount;
@end

@implementation QNZeroReadInputStream

// 首次读到零字节后仍报告可读，最多允许两次读取以避免回归时挂起。
- (BOOL)hasBytesAvailable {
    return self.readCount < 2;
}

// 返回零字节，验证排空逻辑不会重复读取。
- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    self.readCount += 1;
    return 0;
}

@end

@interface QNCFHttpClientTest : XCTestCase

@property(nonatomic, strong)QNCFHttpClient *client;

@end

@interface QNCFHttpClientIdleTimeoutTest : XCTestCase <QNCFHttpClientInnerDelegate>
@property (nonatomic, strong) QNCFHttpClientInner *innerClient;
@property (nonatomic, strong) QNCFHttpClient *outerClient;
@property (nonatomic, strong) XCTestExpectation *completion;
@property (nonatomic, strong) NSMutableData *receivedData;
@property (nonatomic, strong) NSError *requestError;
@property (nonatomic, assign) NSInteger callbackCount;
@property (nonatomic, assign) NSInteger sendProgressCount;
@property (nonatomic, assign) int64_t lastBytesSent;
@property (nonatomic, assign) int listenSocket;
@property (nonatomic, strong) dispatch_semaphore_t serverFinished;
@end

@implementation QNCFHttpClientIdleTimeoutTest

// 每个用例使用独立的本机服务和请求观察状态。
- (void)setUp {
    [super setUp];
    self.listenSocket = -1;
    self.receivedData = [NSMutableData data];
    self.callbackCount = 0;
    self.sendProgressCount = 0;
    self.lastBytesSent = 0;
    self.requestError = nil;
}

// 清理请求和监听端口，并等待后台服务退出。
- (void)tearDown {
    [self.innerClient cancel];
    [self.outerClient cancel];
    if (self.listenSocket >= 0) {
        close(self.listenSocket);
    }
    if (self.serverFinished) {
        XCTAssertEqual(dispatch_semaphore_wait(self.serverFinished, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)), 0);
    }
    [super tearDown];
}

// 创建接收单个请求的本机服务，处理函数控制响应和关闭时机。
- (NSURLRequest *)requestWithTimeout:(NSTimeInterval)timeout handler:(void (^)(int, int))handler {
    self.completion = [self expectationWithDescription:@"request completed"];
    self.listenSocket = socket(AF_INET, SOCK_STREAM, 0);
    XCTAssertGreaterThanOrEqual(self.listenSocket, 0);
    struct sockaddr_in address = {0};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    XCTAssertEqual(bind(self.listenSocket, (struct sockaddr *)&address, sizeof(address)), 0);
    XCTAssertEqual(listen(self.listenSocket, 1), 0);
    socklen_t addressLength = sizeof(address);
    XCTAssertEqual(getsockname(self.listenSocket, (struct sockaddr *)&address, &addressLength), 0);
    int listener = self.listenSocket;
    self.serverFinished = dispatch_semaphore_create(0);
    dispatch_semaphore_t finished = self.serverFinished;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        int peer = accept(listener, NULL, NULL);
        if (peer >= 0) {
            int noSigpipe = 1;
            setsockopt(peer, SOL_SOCKET, SO_NOSIGPIPE, &noSigpipe, sizeof(noSigpipe));
            struct timeval receiveTimeout = {2, 0};
            setsockopt(peer, SOL_SOCKET, SO_RCVTIMEO, &receiveTimeout, sizeof(receiveTimeout));
            int receiveBufferSize = 128 * 1024;
            setsockopt(peer, SOL_SOCKET, SO_RCVBUF, &receiveBufferSize, sizeof(receiveBufferSize));
            NSMutableData *requestData = [NSMutableData data];
            NSData *headerEnd = [@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
            char buffer;
            while ([requestData rangeOfData:headerEnd options:0 range:NSMakeRange(0, requestData.length)].location == NSNotFound) {
                ssize_t length = recv(peer, &buffer, sizeof(buffer), 0);
                if (length <= 0) {
                    break;
                }
                [requestData appendBytes:&buffer length:length];
            }
            handler(peer, listener);
            close(peer);
        }
        dispatch_semaphore_signal(finished);
    });
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%u/idle-timeout", ntohs(address.sin_port)]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = timeout;
    return request;
}

// 返回跨线程共享的错误状态快照。
- (NSError *)requestErrorSnapshot {
    @synchronized (self) {
        return self.requestError;
    }
}

// 返回跨线程共享的回调次数快照。
- (NSInteger)callbackCountSnapshot {
    @synchronized (self) {
        return self.callbackCount;
    }
}

// 返回跨线程共享的响应数据快照。
- (NSData *)receivedDataSnapshot {
    @synchronized (self) {
        return [self.receivedData copy];
    }
}

// 返回跨线程共享的发送进度次数快照。
- (NSInteger)sendProgressCountSnapshot {
    @synchronized (self) {
        return self.sendProgressCount;
    }
}

// 返回跨线程共享的已发送字节数快照。
- (int64_t)lastBytesSentSnapshot {
    @synchronized (self) {
        return self.lastBytesSent;
    }
}

// 验证流错误事件缺少错误对象时仍回调失败。
- (void)testStreamErrorWithoutDetailsFails {
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:1"]];
    QNCFHttpClientInner *client = [QNCFHttpClientInner client:request connectionProxy:@{}];
    client.delegate = self;
    NSInputStream *stream = [NSInputStream inputStreamWithData:[NSData data]];
    [stream open];
    [client setValue:stream forKey:@"inputStream"];
    [client stream:stream handleEvent:NSStreamEventErrorOccurred];
    XCTAssertNotNil([self requestErrorSnapshot]);
    XCTAssertEqual([self callbackCountSnapshot], 1);
}

// 验证底层流创建失败时不会遗留定时器。
- (void)testNilInputStreamFailsWithoutTimer {
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:1"]];
    QNNilInputStreamClient *client = [QNNilInputStreamClient client:request connectionProxy:@{}];
    client.delegate = self;
    [client main];
    XCTAssertNotNil([self requestErrorSnapshot]);
    XCTAssertEqual([self callbackCountSnapshot], 1);
    XCTAssertNil([client valueForKey:@"progressTimer"]);
}

// 可读标记为真但读取返回零字节时，排空逻辑必须及时退出。
- (void)testDrainStopsWhenReadReturnsZero {
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:1"]];
    QNCFHttpClientInner *client = [QNCFHttpClientInner client:request connectionProxy:@{}];
    QNZeroReadInputStream *stream = [QNZeroReadInputStream new];
    [client setValue:stream forKey:@"inputStream"];
    [client inputStreamDrainRemainingData];
    XCTAssertEqual(stream.readCount, 1);
}

// 在当前运行循环启动请求流，以便测试真实流事件和定时器。
- (void)startInnerRequest:(NSURLRequest *)request {
    self.innerClient = [QNCFHttpClientInner client:request connectionProxy:@{}];
    self.innerClient.delegate = self;
    [self.innerClient main];
}

// 服务端持续无响应时必须超时，关闭连接后不得再次回调。
- (void)testNoResponseTimesOutOnce {
    NSURLRequest *request = [self requestWithTimeout:0.5 handler:^(int peer, int listener) {
        usleep(1500000);
    }];
    [self startInnerRequest:request];
    [self waitForExpectationsWithTimeout:3 handler:nil];
    NSError *error = [self requestErrorSnapshot];
    XCTAssertEqualObjects(error.domain, NSURLErrorDomain);
    XCTAssertEqual(error.code, NSURLErrorTimedOut);
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.9]];
    XCTAssertEqual([self callbackCountSnapshot], 1);
    XCTAssertNil([self.innerClient valueForKey:@"inputStream"]);
    XCTAssertNil([self.innerClient valueForKey:@"progressTimer"]);
}

// 总耗时超过超时时长但持续收取响应体时，应完整成功。
- (void)testContinuousResponseDoesNotTimeOut {
    NSURLRequest *request = [self requestWithTimeout:0.5 handler:^(int peer, int listener) {
        const char *header = "HTTP/1.1 200 OK\r\nContent-Length: 65536\r\nConnection: close\r\n\r\n";
        send(peer, header, strlen(header), 0);
        char chunk[8192];
        memset(chunk, 'a', sizeof(chunk));
        for (int i = 0; i < 8; i++) {
            usleep(200000);
            send(peer, chunk, sizeof(chunk), 0);
        }
    }];
    [self startInnerRequest:request];
    [self waitForExpectationsWithTimeout:4 handler:nil];
    XCTAssertNil([self requestErrorSnapshot]);
    XCTAssertEqual([self receivedDataSnapshot].length, 65536);
    XCTAssertEqual([self callbackCountSnapshot], 1);
}

// 收到响应头和部分数据后停止传输，也应触发空闲超时。
- (void)testStalledResponseBodyTimesOut {
    NSURLRequest *request = [self requestWithTimeout:0.5 handler:^(int peer, int listener) {
        const char *response = "HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\nab";
        send(peer, response, strlen(response), 0);
        usleep(1500000);
    }];
    [self startInnerRequest:request];
    [self waitForExpectationsWithTimeout:3 handler:nil];
    XCTAssertEqual([self requestErrorSnapshot].code, NSURLErrorTimedOut);
    XCTAssertEqualObjects([self receivedDataSnapshot], [@"ab" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertEqual([self callbackCountSnapshot], 1);
}

// 服务端持续慢速读取请求体时，发送活动应刷新空闲时间。
- (void)testContinuousUploadDoesNotTimeOut {
    const NSUInteger bodySize = 4 * 1024 * 1024;
    __block NSUInteger receivedBytes = 0;
    NSMutableURLRequest *request = [[self requestWithTimeout:1 handler:^(int peer, int listener) {
        char buffer[64 * 1024];
        while (receivedBytes < bodySize) {
            ssize_t length = recv(peer, buffer, MIN(sizeof(buffer), bodySize - receivedBytes), 0);
            if (length <= 0) {
                return;
            }
            receivedBytes += length;
            usleep(50000);
        }
        const char *response = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok";
        send(peer, response, strlen(response), 0);
    }] mutableCopy];
    request.HTTPMethod = @"PUT";
    request.HTTPBody = [NSMutableData dataWithLength:bodySize];
    NSTimeInterval start = [NSProcessInfo processInfo].systemUptime;
    [self startInnerRequest:request];
    [self waitForExpectationsWithTimeout:15 handler:nil];
    XCTAssertNil([self requestErrorSnapshot]);
    XCTAssertEqual(receivedBytes, bodySize);
    XCTAssertGreaterThan([self sendProgressCountSnapshot], 1);
    XCTAssertGreaterThan([NSProcessInfo processInfo].systemUptime - start, request.timeoutInterval);
    XCTAssertEqual([self callbackCountSnapshot], 1);
}

// 请求体尚未发完就停止被读取时，应在发送阶段超时并只回调一次。
- (void)testStalledUploadTimesOut {
    NSMutableURLRequest *request = [[self requestWithTimeout:1 handler:^(int peer, int listener) {
        char buffer[1024];
        recv(peer, buffer, sizeof(buffer), 0);
        usleep(3000000);
    }] mutableCopy];
    request.HTTPMethod = @"PUT";
    request.HTTPBody = [NSMutableData dataWithLength:8 * 1024 * 1024];
    [self startInnerRequest:request];
    [self waitForExpectationsWithTimeout:5 handler:nil];
    XCTAssertEqual([self requestErrorSnapshot].code, NSURLErrorTimedOut);
    XCTAssertGreaterThan([self lastBytesSentSnapshot], 0);
    XCTAssertLessThan([self lastBytesSentSnapshot], request.HTTPBody.length);
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.8]];
    XCTAssertEqual([self callbackCountSnapshot], 1);
    XCTAssertNil([self.innerClient valueForKey:@"inputStream"]);
    XCTAssertNil([self.innerClient valueForKey:@"progressTimer"]);
}

// 先正常完成后，超时检查和主动取消都不能产生第二次回调。
- (void)testSuccessStopsTimeoutTimer {
    NSURLRequest *request = [self requestWithTimeout:0.5 handler:^(int peer, int listener) {
        const char *response = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok";
        send(peer, response, strlen(response), 0);
    }];
    [self startInnerRequest:request];
    [self waitForExpectationsWithTimeout:3 handler:nil];
    [self.innerClient cancel];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.8]];
    XCTAssertNil([self requestErrorSnapshot]);
    XCTAssertEqual([self callbackCountSnapshot], 1);
    XCTAssertNil([self.innerClient valueForKey:@"progressTimer"]);
}

// 外层取消必须投递到活动线程，且之后不能再报空闲超时。
- (void)testOuterCancelCompletesOnce {
    NSURLRequest *request = [self requestWithTimeout:0.5 handler:^(int peer, int listener) {
        usleep(1500000);
    }];
    self.outerClient = [[QNCFHttpClient alloc] init];
    [self.outerClient request:request server:nil connectionProxy:@{} progress:nil complete:^(NSURLResponse *response, QNUploadSingleRequestMetrics *metrics, NSData *data, NSError *error) {
        @synchronized (self) {
            self.requestError = error;
            self.callbackCount += 1;
        }
        [self.completion fulfill];
    }];
    [self.outerClient performSelector:@selector(cancel) withObject:nil afterDelay:0.1];
    [self waitForExpectationsWithTimeout:3 handler:nil];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.8]];
    XCTAssertEqual([self requestErrorSnapshot].code, NSURLErrorCancelled);
    XCTAssertEqual([self callbackCountSnapshot], 1);
}

// 重定向后的请求应继承原始 0.5 秒闲时超时，而不是恢复默认值。
- (void)testRedirectPreservesIdleTimeout {
    NSURLRequest *request = [self requestWithTimeout:0.5 handler:^(int peer, int listener) {
        struct sockaddr_in address = {0};
        socklen_t addressLength = sizeof(address);
        getsockname(peer, (struct sockaddr *)&address, &addressLength);
        NSString *header = [NSString stringWithFormat:@"HTTP/1.1 302 Found\r\nLocation: http://127.0.0.1:%u/redirect-target\r\nContent-Length: 0\r\nConnection: close\r\n\r\n", ntohs(address.sin_port)];
        NSData *data = [header dataUsingEncoding:NSUTF8StringEncoding];
        send(peer, data.bytes, data.length, 0);
        shutdown(peer, SHUT_WR);
        fd_set readSet;
        FD_ZERO(&readSet);
        FD_SET(listener, &readSet);
        struct timeval deadline = {3, 0};
        if (select(listener + 1, &readSet, NULL, NULL, &deadline) > 0) {
            int redirectedPeer = accept(listener, NULL, NULL);
            if (redirectedPeer >= 0) {
                char buffer[4096];
                struct timeval timeout = {2, 0};
                setsockopt(redirectedPeer, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
                recv(redirectedPeer, buffer, sizeof(buffer), 0);
                usleep(2000000);
                close(redirectedPeer);
            }
        }
    }];
    self.outerClient = [[QNCFHttpClient alloc] init];
    [self.outerClient request:request server:nil connectionProxy:@{} progress:nil complete:^(NSURLResponse *response, QNUploadSingleRequestMetrics *metrics, NSData *data, NSError *error) {
        @synchronized (self) {
            self.requestError = error;
            self.callbackCount += 1;
        }
        [self.completion fulfill];
    }];
    [self waitForExpectationsWithTimeout:1.5 handler:nil];
    XCTAssertEqual([self requestErrorSnapshot].code, NSURLErrorTimedOut);
    XCTAssertEqual([self callbackCountSnapshot], 1);
}

// 记录错误终态并通知测试等待者。
- (void)onError:(NSError *)error {
    @synchronized (self) {
        self.requestError = error;
        self.callbackCount += 1;
    }
    [self.completion fulfill];
}

// 记录成功终态并通知测试等待者。
- (void)didFinish {
    @synchronized (self) {
        self.callbackCount += 1;
    }
    [self.completion fulfill];
}

// 记录实际发送进度，区分发送停滞和发完后的等待响应。
- (void)didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)expected {
    if (bytesSent > 0) {
        @synchronized (self) {
            self.sendProgressCount += 1;
            self.lastBytesSent = totalBytesSent;
        }
    }
}

// 响应头事件由真实请求流处理，本组主要核对结束结果。
- (void)onReceiveResponse:(NSURLResponse *)response httpVersion:(NSString *)version {
}

// 累计响应体，验证分段读取和超时前的已收数据。
- (void)didLoadData:(NSData *)data {
    @synchronized (self) {
        [self.receivedData appendData:data];
    }
}

// 本机服务不产生重定向。
- (void)redirectedToRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
}

@end
@implementation QNCFHttpClientTest

- (void)setUp {
    
}

- (void)tearDown {
    [super tearDown];
    
    self.client = nil;
}

- (void)testHttpGet{
    NSString *urlString = [NSString stringWithFormat:@"http://uc.qbox.me/v3/query?ak=%@&bucket=%@", ak, [QNUpToken parse:token_z0].bucket];
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    [self request:request];
}

- (void)testHttpsGet{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://uc.qbox.me/v3/query?ak=%@&bucket=%@", ak, [QNUpToken parse:token_z0].bucket]];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    [self request:request];
}

- (void)testHttpGetByIP{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://101.251.144.177/v3/query?ak=%@&bucket=%@", ak, [QNUpToken parse:token_z0].bucket]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.qn_domain = @"uc.qbox.me";
    
    [self request:request];
}

- (void)testHttpsGetByIP{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://101.251.144.177/v3/query?ak=%@&bucket=%@", ak, [QNUpToken parse:token_z0].bucket]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.qn_domain = @"uc.qbox.me";
    
    [self request:request];
}

- (void)testHttpPost{
    
    NSData *data = [@"This is a test" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *params = @{@"token" : token_na0};
    NSURLRequest *request = [self postRequest:@"http://up-na0.qiniup.com"
                                       domain:@"up-na0.qiniup.com"
                                        param:params
                                         body:data];
    [self request:request];
}

- (void)testHttpsPost{
    NSData *data = [@"This is a test" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *params = @{@"token" : token_na0};
    NSURLRequest *request = [self postRequest:@"https://up-na0.qiniup.com"
                                       domain:@"up-na0.qiniup.com"
                                        param:params
                                         body:data];
    [self request:request];
}

- (void)testHttpPostByIP{
    
    NSData *data = [@"This is a test" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *params = @{@"token" : token_na0};
    NSURLRequest *request = [self postRequest:@"http://148.153.188.136"
                                       domain:@"up-na0.qiniup.com"
                                        param:params
                                         body:data];
    [self request:request];
}

- (void)testHttpsPostByIP{
    NSData *data = [@"This is a test" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *params = @{@"token" : token_na0};
    NSURLRequest *request = [self postRequest:@"https://148.153.188.136"
                                       domain:@"up-na0.qiniup.com"
                                        param:params
                                         body:data];
    [self request:request];
}


- (NSURLRequest *)postRequest:(NSString *)urlstring
                       domain:(NSString *)domain
                        param:(NSDictionary *)params
                         body:(NSData *)data{
    
    NSURL *url = [NSURL URLWithString:urlstring];
    NSMutableData *body = [NSMutableData data];
    NSString *boundary = @"werghnvt54wef654rjuhgb56trtg34tweuyrgf";
    for (NSString *paramsKey in params) {
        NSString *pair = [NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"%@\"\r\n\r\n", boundary, paramsKey];
        [body appendData:[pair dataUsingEncoding:NSUTF8StringEncoding]];

        id value = [params objectForKey:paramsKey];
        if ([value isKindOfClass:[NSString class]]) {
            [body appendData:[value dataUsingEncoding:NSUTF8StringEncoding]];
        } else if ([value isKindOfClass:[NSData class]]) {
            [body appendData:value];
        }
        [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }
    NSString *filePair = [NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"file\"; filename=\"?\"\nContent-Type:text/plain\r\n\r\n", boundary];
    [body appendData:[filePair dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:data];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.qn_domain  = domain;
    request.HTTPMethod = @"POST";
    request.HTTPBody   = [body copy];
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    NSString *contentLength = [NSString stringWithFormat:@"%ld", (long)[body length]];
    request.allHTTPHeaderFields = @{@"Content-Type" : contentType,
                                    @"Content-Length" : contentLength};
    return [request copy];
}

//MARK: --
- (void)request:(NSURLRequest *)request{
    self.client = [[QNCFHttpClient alloc] init];
    [self.client request:request server:nil connectionProxy:@{@"HTTPSProxy":@"aaa", @"HTTPSPort":@80} progress:^(long long totalBytesWritten, long long totalBytesExpectedToWrite) {
        NSLog(@"progress written:%lld total:%lld", totalBytesWritten, totalBytesExpectedToWrite);
    } complete:^(NSURLResponse * _Nullable response, QNUploadSingleRequestMetrics * _Nullable metrics, NSData * _Nullable data, NSError * _Nullable error) {
        if (error) {
            XCTAssertTrue(error == nil, "error:%@", error);
        }
        
        NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"responseString:%@", responseString);
        XCTAssertTrue([(NSHTTPURLResponse * )response statusCode] == 200, "response:%@", response);
        QN_TEST_CASE_CONTINUE
    }];
    QN_TEST_CASE_WAIT
}


@end
