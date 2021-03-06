//
//  QNAutoZoneTest.m
//  QiniuSDK
//
//  Created by 白顺龙 on 2016/10/11.
//  Copyright © 2016年 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <XCTest/XCTest.h>

#import <AGAsyncTestHelper.h>

#import "QNResponseInfo.h"
#import "QNSessionManager.h"

#import "QNAutoZone.h"
#import "QNConfiguration.h"

#import "QNTestConfig.h"
#import "QNUpToken.h"

@interface QNAutoZoneTest : XCTestCase
@property QNAutoZone* autozone;

@end

@implementation QNAutoZoneTest

- (void)setUp {
    [super setUp];
    _autozone = [[QNAutoZone alloc] init];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testHttp {
    QNAutoZone* autoZone = [[QNAutoZone alloc] init];
    QNUpToken* tok = [QNUpToken parse:token_na0];
    __block int x = 0;
    __block int c = 0;
    [autoZone preQuery:tok on:^(int code, QNResponseInfo *info, QNUploadRegionRequestMetrics *metrics) {
        x = 1;
        c = code;
    }];
    AGWW_WAIT_WHILE(x == 0, 100.0);
    XCTAssertEqual(0, c, @"Pass");
}

- (void)testMutiHttp{
    for (int i=0; i<5; i++) {
        [self testHttp];
    }
}

@end
