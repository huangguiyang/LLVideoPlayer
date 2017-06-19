//
//  LLVideoPlayerCacheLocalTask.m
//  Pods
//
//  Created by mario on 2017/6/9.
//
//

#import "LLVideoPlayerCacheLocalTask.h"
#import "LLVideoPlayerInternal.h"
#import "NSURL+LLVideoPlayer.h"
#import "LLVideoPlayerCacheUtils.h"

@implementation LLVideoPlayerCacheLocalTask

- (void)dealloc
{
    LLLog(@"LLVideoPlayerCacheLocalTask dealloc: %p", self);
}

- (void)resume
{
    [super resume];
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSInteger offset = self.range.location;
        NSInteger lengthPerRead = 10000;
        NSError *error = nil;
        
        while (offset < NSMaxRange(self.range)) {
            if ([self isCancelled]) {
                error = [NSError errorWithDomain:@"LLVideoPlayerCacheLocalTask" code:NSURLErrorCancelled userInfo:nil];
                break;
            }
            
            error = nil;
            NSRange range = NSMakeRange(offset, MIN(NSMaxRange(self.range) - offset, lengthPerRead));
            NSData *data = [self.cacheFile dataWithRange:range error:&error];
            if (error) {
                break;
            }
            if (nil == data) {
                error = [NSError errorWithDomain:@"LLVideoPlayerCacheLocalTask" code:NSURLErrorUnknown userInfo:nil];
                break;
            }
            
            [self.loadingRequest.dataRequest respondWithData:data];
            offset = NSMaxRange(range);
        }
        
        if ([self.delegate respondsToSelector:@selector(task:didCompleteWithError:)]) {
            [self.delegate task:self didCompleteWithError:error];
        }
    });
}

@end
