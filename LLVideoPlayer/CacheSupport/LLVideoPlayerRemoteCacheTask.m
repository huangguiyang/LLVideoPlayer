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
#import "LLVideoPlayerInternal.h"

@interface LLVideoPlayerRemoteCacheTask () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>
{
    @private
    NSURLConnection *_connection;
    NSUInteger _offset;
    NSUInteger _requestLength;
    CFRunLoopRef _runloop;
}

@property (assign, nonatomic, getter = isExecuting) BOOL executing;
@property (assign, nonatomic, getter = isFinished) BOOL finished;

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
    [_connection cancel];
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
    [self setExecuting:NO];
    [self setFinished:YES];
}

- (void)startWithRequest:(AVAssetResourceLoadingRequest *)loadingRequest range:(NSRange)range
{
    NSMutableURLRequest *urlRequest = [loadingRequest.request mutableCopy];
    urlRequest.URL = [loadingRequest.request.URL ll_originalSchemeURL];
    urlRequest.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    _offset = 0;
    _requestLength = 0;
    
    if (nil == self.response || [self.response ll_supportRange]) {
        NSString *rangeValue = LLRangeToHTTPRangeHeader(range);
        if (rangeValue) {
            [urlRequest setValue:rangeValue forHTTPHeaderField:@"Range"];
            _offset = range.location;
            _requestLength = range.length;
        }
    }
    
    _connection = [[NSURLConnection alloc] initWithRequest:urlRequest delegate:self startImmediately:NO];
    [_connection start];
    [self startRunLoop];
}

- (void)startRunLoop
{
    _runloop = CFRunLoopGetCurrent();
    CFRunLoopRun();
}

- (void)stopRunLoop
{
    if (_runloop) {
        CFRunLoopStop(_runloop);
    }
}

- (void)syncCacheFile
{
    [_cacheFile synchronize];
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self syncCacheFile];
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
        [_cacheFile setResponse:self.response];
        [_loadingRequest ll_fillContentInformation:self.response];
    }
    
    if (NO == [self.response ll_supportRange]) {
        _offset = 0;
    }
    if (_offset == NSIntegerMax) {
        _offset = self.response.ll_contentLength - _requestLength;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (data.bytes && [_cacheFile saveData:data atOffset:_offset synchronize:NO]) {
        _offset += [data length];
        [_loadingRequest.dataRequest respondWithData:data];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self syncCacheFile];
    [self stopRunLoop];
}

@end
