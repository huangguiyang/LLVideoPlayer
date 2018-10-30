//
//  LLVideoPlayerRemoteOperation.h
//  Pods
//
//  Created by mario on 2017/8/21.
//
//

#import "LLVideoPlayerCacheFile.h"
#import "LLVideoPlayerOperationDelegate.h"
#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, LLVideoPlayerRemoteOptions) {
    LLVideoPlayerAllowInvalidSSLCertificates = 1 << 0,
};

@interface LLVideoPlayerRemoteOperation : NSOperation <NSURLSessionDataDelegate>

- (instancetype)initWithRequest:(NSURLRequest *)request cacheFile:(LLVideoPlayerCacheFile *)cacheFile;

@property (nonatomic, weak) id<LLVideoPlayerOperationDelegate> delegate;
@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, strong) LLVideoPlayerCacheFile *cacheFile;
@property (nonatomic, strong) NSURLCredential *credential;

@end
