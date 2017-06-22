//
//  LLVideoPlayerCacheOperation.m
//  Pods
//
//  Created by mario on 2017/6/8.
//
//

#import "LLVideoPlayerCacheOperation.h"
#import "LLVideoPlayerInternal.h"
#import "NSURL+LLVideoPlayer.h"
#import "LLVideoPlayerCacheUtils.h"
#import "NSHTTPURLResponse+LLVideoPlayer.h"
#import "AVAssetResourceLoadingRequest+LLVideoPlayer.h"

@interface LLVideoPlayerCacheOperation () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>
{
    CFRunLoopRef _runLoop;
}

@property (nonatomic, getter = isFinished, readwrite)  BOOL finished;
@property (nonatomic, getter = isExecuting, readwrite) BOOL executing;
@property (nonatomic, strong) AVAssetResourceLoadingRequest *loadingRequest;
@property (nonatomic, strong) LLVideoPlayerCacheFile *cacheFile;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSURLResponse *response;

@end

@implementation LLVideoPlayerCacheOperation
@synthesize executing = _executing;
@synthesize finished = _finished;

#pragma mark - Executing && Finished

- (BOOL)isExecuting
{
    @synchronized (self) {
        return _executing;
    }
}

- (BOOL)isFinished
{
    @synchronized (self) {
        return _finished;
    }
}

- (void)setExecuting:(BOOL)executing
{
    if (executing != _executing) {
        [self willChangeValueForKey:@"isExecuting"];
        @synchronized (self) {
            _executing = executing;
        }
        [self didChangeValueForKey:@"isExecuting"];
    }
}

- (void)setFinished:(BOOL)finished
{
    if (finished != _finished) {
        [self willChangeValueForKey:@"isFinished"];
        @synchronized (self) {
            _finished = finished;
        }
        [self didChangeValueForKey:@"isFinished"];
    }
}

- (instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                             cacheFile:(LLVideoPlayerCacheFile *)cacheFile
{
    self = [super init];
    if (self) {
        self.loadingRequest = loadingRequest;
        self.cacheFile = cacheFile;
    }
    return self;
}

+ (instancetype)operationWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                                  cacheFile:(LLVideoPlayerCacheFile *)cacheFile
{
    return [[self alloc] initWithLoadingRequest:loadingRequest cacheFile:cacheFile];
}

#pragma mark - Start/Cancel/Main

- (void)dealloc
{
    [_connection cancel];
    LLLog(@"LLVideoPlayerCacheOperation dealloc... %p", self);
}

- (void)main
{
    LLLog(@"operation main: %@: %@", [NSThread currentThread], LLLoadingRequestToString(self.loadingRequest));
    
    @autoreleasepool {
        if ([self isCancelled]) {
            [self complete];
            return;
        }
        
        self.executing = YES;
        [self startOperation];
        
        [self startRunLoop];
        [self complete];
    }
}

- (void)cancel
{
    [self.connection cancel];
    self.connection = nil;
    [super cancel];
    LLLog(@"operation cancelled: %p", self);
}

- (void)complete
{
    self.executing = NO;
    self.finished = YES;
    LLLog(@"operation complete: %p", self);
}

- (void)startRunLoop
{
    NSRunLoop *runloop = [NSRunLoop currentRunLoop];
    [runloop addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
    _runLoop = runloop.getCFRunLoop;
    CFRunLoopRun();
}

- (void)stopRunLoop
{
    if (_runLoop) {
        CFRunLoopStop(_runLoop);
        _runLoop = NULL;
    }
}

#pragma mark - Operations

- (void)startOperation
{
    // range
    NSRange range;
    if ([self.loadingRequest.dataRequest respondsToSelector:@selector(requestsAllDataToEndOfResource)] &&
        self.loadingRequest.dataRequest.requestsAllDataToEndOfResource) {
        range = NSMakeRange(self.loadingRequest.dataRequest.requestedOffset, NSIntegerMax);
    } else {
        range = NSMakeRange(self.loadingRequest.dataRequest.requestedOffset,
                            self.loadingRequest.dataRequest.requestedLength);
    }
    
    NSURLResponse *response = [self.cacheFile constructHTTPURLResponseForURL:self.loadingRequest.request.URL
                                                                    andRange:range];
    if (response) {
        [self.loadingRequest ll_fillContentInformation:response];
        self.response = response;
        LLLog(@"construct response: %@", response);
    }
    
    [self startRemoteWithRange:range];
}

- (void)finishOperationWithError:(NSError *)error
{
    LLLog(@"[FINISH] %@, error: %@", LLLoadingRequestToString(self.loadingRequest), error);
    if (error) {
        [self.loadingRequest finishLoadingWithError:error];
    } else {
        [self.loadingRequest finishLoading];
    }
    
    [self stopRunLoop];
}

#pragma mark - LLVideoPlayerCacheTaskDelegate

- (void)startRemoteWithRange:(NSRange)range
{
    NSMutableURLRequest *request = [self.loadingRequest.request mutableCopy];
    request.URL = [self.loadingRequest.request.URL ll_originalSchemeURL];
    request.cachePolicy = NSURLRequestReloadIgnoringCacheData;  // very important
    
    NSString *rangeString = LLRangeToHTTPRangeHeader(range);
    if (rangeString) {
        [request setValue:rangeString forHTTPHeaderField:@"Range"];
    }
    
    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [self.connection start];
}

#pragma mark - NSURLConnectionDelegate && NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self finishOperationWithError:error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self finishOperationWithError:nil];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if (nil == response || NO == [response isKindOfClass:[NSHTTPURLResponse class]]) {
        return;
    }
    if (self.response) {
        return;
    }
    
    LLLog(@"didReceiveResponse: %@", response);
    [self.loadingRequest ll_fillContentInformation:response];
    [self.cacheFile writeResponse:(NSHTTPURLResponse *)response];
    self.response = response;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.loadingRequest.dataRequest respondWithData:data];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
    if (response) {
        self.loadingRequest.redirect = request;
    }
    
    return request;
}

@end
