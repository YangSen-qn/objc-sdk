//
//  IQNURLSession.h
//  Qiniu
//
//  Created by yangsen on 2020/10/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol QNURLSessionDataTaskDelegate, IQNURLSessionConfiguration, IQNURLSessionDataTask;

@protocol IQNURLSession <NSObject>

+ (instancetype)sessionWithConfiguration:(nullable id <IQNURLSessionConfiguration>)configuration;
+ (instancetype)sessionWithConfiguration:(nullable id <IQNURLSessionConfiguration>)configuration
                                delegate:(nullable id <QNURLSessionDataTaskDelegate>)delegate
                           delegateQueue:(NSOperationQueue *)queue;

@property (nullable, readonly, strong) NSOperationQueue *delegateQueue;
@property (nullable, readonly, weak) id <QNURLSessionDataTaskDelegate> delegate;
@property (nullable, readonly, strong) id <IQNURLSessionConfiguration> configuration;

- (id <IQNURLSessionDataTask>)dataTaskWithRequest:(NSURLRequest *)request;
- (id <IQNURLSessionDataTask>)dataTaskWithURL:(NSURL *)url;

@end
NS_ASSUME_NONNULL_END
