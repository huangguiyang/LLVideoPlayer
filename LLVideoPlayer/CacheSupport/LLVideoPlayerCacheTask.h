//
//  LLVideoPlayerCacheTask.h
//  Pods
//
//  Created by mario on 2017/6/9.
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface LLVideoPlayerCacheTask : NSObject

- (instancetype)initWithRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          range:(NSRange)range
                       userInfo:(NSDictionary *)userInfo;

+ (instancetype)taskWithRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                          range:(NSRange)range
                       userInfo:(NSDictionary *)userInfo;

@property (nonatomic, strong) NSDictionary *userInfo;
@property (nonatomic, assign) NSRange range;
@property (nonatomic, strong) AVAssetResourceLoadingRequest *loadingRequest;
@property (nonatomic, copy) void (^completionBlock)(LLVideoPlayerCacheTask *task, NSError *error);
@property (nonatomic, copy) void (^didReceiveResponseBlock)(LLVideoPlayerCacheTask *task, NSURLResponse *response);

- (void)resume;
- (void)cancel;

@end
