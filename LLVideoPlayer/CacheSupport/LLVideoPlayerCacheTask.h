//
//  LLVideoPlayerCacheTask.h
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import <Foundation/Foundation.h>

@class LLVideoPlayerCacheFile;
@class AVAssetResourceLoadingRequest;
@class LLVideoPlayerCacheTask;

typedef void (^LLVideoPlayerCacheTaskFinishedBlock) (LLVideoPlayerCacheTask *, NSError *);

@interface LLVideoPlayerCacheTask : NSOperation
{
    @protected
    LLVideoPlayerCacheFile *_cacheFile;
    AVAssetResourceLoadingRequest *_loadingRequest;
    NSRange _range;
}

@property (nonatomic, copy) LLVideoPlayerCacheTaskFinishedBlock finishBlock;

- (instancetype)initWithCacheFilePath:(LLVideoPlayerCacheFile *)cacheFile loadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest range:(NSRange)range;

@end
