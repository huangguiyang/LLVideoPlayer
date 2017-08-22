//
//  LLVideoPlayerCacheLocalTask.m
//  Pods
//
//  Created by mario on 2017/8/21.
//
//

#import "LLVideoPlayerCacheLocalTask.h"

@implementation LLVideoPlayerCacheLocalTask

- (void)resume
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            if ([self isCancelled]) {
                return;
            }
            
            NSInteger offset = self.range.location;
            NSInteger lengthPerRead = 8192;
            NSError *error = nil;
            
            while (offset < NSMaxRange(self.range)) {
                @autoreleasepool {
                    if ([self isCancelled]) {
                        return;
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
            }
            
            if (error) {
                if ([self.delegate respondsToSelector:@selector(task:didFailWithError:)]) {
                    [self.delegate task:self didFailWithError:error];
                }
            } else {
                if ([self.delegate respondsToSelector:@selector(taskDidFinish:)]) {
                    [self.delegate taskDidFinish:self];
                }
            }
        }
    });
}

@end
