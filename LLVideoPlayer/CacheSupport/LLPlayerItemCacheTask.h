//
//  LLPlayerItemCacheTask.h
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import <Foundation/Foundation.h>

@class LLPlayerItemCacheFile;
@class AVAssetResourceLoadingRequest;
@class LLPlayerItemCacheTask;

typedef void (^LLPlayerItemCacheTaskFinishedBlock) (LLPlayerItemCacheTask *, NSError *);

@interface LLPlayerItemCacheTask : NSOperation
{
    @protected
    LLPlayerItemCacheFile *_cacheFile;
    AVAssetResourceLoadingRequest *_loadingRequest;
    NSRange _range;
}

@property (nonatomic, copy) LLPlayerItemCacheTaskFinishedBlock finishBlock;

- (instancetype)initWithCacheFilePath:(LLPlayerItemCacheFile *)cacheFile loadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest range:(NSRange)range;

@end
