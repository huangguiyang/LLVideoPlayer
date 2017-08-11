//
//  LLVideoPlayerCacheLocalTask.m
//  Pods
//
//  Created by mario on 2017/6/23.
//
//

#import "LLVideoPlayerCacheLocalTask.h"
#import "LLVideoPlayerInternal.h"

@implementation LLVideoPlayerCacheLocalTask

- (void)main
{
    @autoreleasepool {
        if ([self isCancelled]) {
            return;
        }
        
        [self setExecuting:YES];
        
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
        
        self.error = error;
        [self setExecuting:NO];
        [self setFinished:YES];
    }
}

@end
