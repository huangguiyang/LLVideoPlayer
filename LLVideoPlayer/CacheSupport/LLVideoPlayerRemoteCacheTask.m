//
//  LLVideoPlayerRemoteCacheTask.m
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import "LLVideoPlayerRemoteCacheTask.h"
#import <AVFoundation/AVFoundation.h>
#import "NSURL+LLVideoPlayer.h"
#import "LLVideoPlayerCacheFile.h"
#import "NSHTTPURLResponse+LLVideoPlayer.h"
#import "AVAssetResourceLoadingRequest+LLVideoPlayer.h"
#import "LLVideoPlayerCacheUtils.h"

@interface LLVideoPlayerRemoteCacheTask () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSURLConnection *connection;
@property (assign, nonatomic, getter = isExecuting) BOOL executing;
@property (assign, nonatomic, getter = isFinished) BOOL finished;
@property (nonatomic, assign) NSUInteger offset;
@property (nonatomic, assign) NSUInteger requestLength;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, assign) CFRunLoopRef runloop;

@end

@implementation LLVideoPlayerRemoteCacheTask
@synthesize executing = _executing;
@synthesize finished = _finished;

- (void)main
{
    @autoreleasepool {
        if ([self isCancelled]) {
            [self handleFinished];
            return;
        }
        
        [self setFinished:NO];
        [self setExecuting:YES];
        [self startWithRequest:_loadingRequest range:_range];
        [self handleFinished];
    }
}

- (void)cancel
{
    [super cancel];
    [self.connection cancel];
}

- (void)setFinished:(BOOL)finished
{
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing
{
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)handleFinished
{
    if (self.finishBlock) {
        self.finishBlock(self, self.error);
    }
    [self setExecuting:NO];
    [self setFinished:YES];
}

- (void)startWithRequest:(AVAssetResourceLoadingRequest *)loadingRequest range:(NSRange)range
{
    NSMutableURLRequest *urlRequest = [loadingRequest.request mutableCopy];
    urlRequest.URL = [loadingRequest.request.URL ll_originalSchemeURL];
    urlRequest.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    self.offset = 0;
    self.requestLength = 0;
    
    if (nil == self.response || [self.response ll_supportRange]) {
        NSString *rangeValue = LLRangeToHTTPRangeHeader(range);
        if (rangeValue) {
            [urlRequest setValue:rangeValue forHTTPHeaderField:@"Range"];
            self.offset = range.location;
            self.requestLength = range.length;
        }
    }
    
    self.connection = [[NSURLConnection alloc] initWithRequest:urlRequest delegate:self startImmediately:NO];
    [self.connection start];
    [self startRunLoop];
}

- (void)startRunLoop
{
    self.runloop = CFRunLoopGetCurrent();
    CFRunLoopRun();
}

- (void)stopRunLoop
{
    if (self.runloop) {
        CFRunLoopStop(self.runloop);
    }
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.error = error;
    [self stopRunLoop];
}

#pragma mark - NSURLConnectionDataDelegate

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
    if (response) {
        _loadingRequest.redirect = request;
    }
    
    return request;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if (nil == response || self.response) {
        return;
    }
    
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        self.response = (NSHTTPURLResponse *)response;
        [_loadingRequest ll_fillContentInformation:self.response];
    }
    
    if (NO == [self.response ll_supportRange]) {
        self.offset = 0;
    }
    if (self.offset == NSUIntegerMax) {
        self.offset = self.response.ll_contentLength - self.requestLength;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (data.bytes && [_cacheFile saveData:data offset:self.offset flags:0]) {
        self.offset += [data length];
        [_loadingRequest.dataRequest respondWithData:data];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self stopRunLoop];
}

@end
