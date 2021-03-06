//
//  QNComplexUploadSceneTestC.m
//  QiniuSDK
//
//  Created by yangsen on 2020/5/11.
//  Copyright © 2020 Qiniu. All rights reserved.
//
#import <XCTest/XCTest.h>
#import <AGAsyncTestHelper.h>
#import "QiniuSDK.h"
#import "QNTempFile.h"
#import "QNTestConfig.h"

@interface QNComplexUploadSceneTest : XCTestCase
@property QNUploadManager *upManager;
@end
@implementation QNComplexUploadSceneTest

- (void)setUp {
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.useConcurrentResumeUpload = YES;
        builder.concurrentTaskCount = 3;
    }];
    _upManager = [[QNUploadManager alloc] initWithConfiguration:config];
}

- (void)tearDown {
    _upManager = nil;
}

- (void)testMutiUpload{
    int maxCount = 10;
    __block int completeCount = 0;
    __block int successCount = 0;
    for (int i=0; i<maxCount; i++) {
        [self template:(i + 1) * 100 complete:^(BOOL isSuccess){
            @synchronized (self) {
                if (isSuccess) {
                    successCount += 1;
                }
                completeCount += 1;
            }
        }];
    }
    
    AGWW_WAIT_WHILE(completeCount != maxCount, 60 * 30);
    
    NSLog(@"complex_upload successCount: %d", successCount);
    XCTAssert(successCount == maxCount, @"Pass");
}

- (void)template:(int)size complete:(void(^)(BOOL isSuccess))complete{
    NSString *keyUp = [NSString stringWithFormat:@"complex_upload_%dk", size];
    QNTempFile *tempFile = [QNTempFile createTempfileWithSize:size * 1024 identifier:keyUp];
    QNUploadOption *opt = [[QNUploadOption alloc] initWithProgressHandler:^(NSString *key, float percent) {
        NSLog(@"progress %f", percent);
    }];
    [_upManager putFile:tempFile.fileUrl.path key:keyUp token:token_na0 complete:^(QNResponseInfo *i, NSString *k, NSDictionary *resp) {
        
        if (i.isOK && i.reqId && [keyUp isEqualToString:k] && [tempFile.fileHash isEqualToString:resp[@"hash"]]) {
            complete(YES);
        } else {
            NSLog(@"complex_upload info: %@", resp);
            complete(NO);
        }
        [tempFile remove];
        
    } option:opt];
    
}
@end
