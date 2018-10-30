//
//  LLVideoPlayerDownloadRequest.h
//  LLVideoPlayer
//
//  Created by mario on 2018/10/26.
//

#import "LLVideoPlayerCacheFile.h"
#import <Foundation/Foundation.h>

@interface LLVideoPlayerDownloadRequest : NSObject

@property (nonatomic, strong, readonly) NSURLRequest *request;
@property (nonatomic, copy) void (^completedBlock)(NSError *error);

- (instancetype)initWithRequest:(NSURLRequest *)request cacheFile:(LLVideoPlayerCacheFile *)cacheFile;

- (void)resume;
- (void)cancel;

@end
