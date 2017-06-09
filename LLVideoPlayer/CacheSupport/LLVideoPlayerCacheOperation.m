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
#import "AVAssetResourceLoadingRequest+LLVideoPlayer.h"
#import "LLVideoPlayerCacheUtils.h"

@interface LLVideoPlayerCacheOperation () <NSURLConnectionDelegate, NSURLConnectionDataDelegate> {
    CFRunLoopRef _runloop;
}

@property (nonatomic, getter = isFinished, readwrite)  BOOL finished;
@property (nonatomic, getter = isExecuting, readwrite) BOOL executing;
@property (nonatomic, strong) LLVideoPlayerCacheFile *cacheFile;
@property (nonatomic, strong) NSURLConnection *connection;

@end

@implementation LLVideoPlayerCacheOperation
@synthesize executing = _executing;
@synthesize finished = _finished;

- (void)dealloc
{
    LLLog(@"LLVideoPlayerCacheOperation dealloc");
}

- (instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                             cacheFile:(LLVideoPlayerCacheFile *)cacheFile
{
    self = [super init];
    if (self) {
        _loadingRequest = loadingRequest;
        _cacheFile = cacheFile;
    }
    return self;
}

+ (instancetype)operationWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                                  cacheFile:(LLVideoPlayerCacheFile *)cacheFile
{
    return [[self alloc] initWithLoadingRequest:loadingRequest cacheFile:cacheFile];
}

- (void)main
{
    LLLog(@"main: %@", [NSThread currentThread]);
    
    @autoreleasepool {
        if ([self isCancelled]) {
            [self completeOperation];
            return;
        }
        
        self.executing = YES;
        [self startOperation];
        [self completeOperation];
    }
}

- (void)completeOperation
{
    LLLog(@"operation will complete...");
    self.executing = NO;
    self.finished = YES;
    LLLog(@"operation complete!!!");
}

#pragma mark - Cancel

- (void)cancel
{
    LLLog(@"LLVideoPlayerCacheOperation cancel");
    [self.connection cancel];
    self.connection = nil;
    [super cancel];
}

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

#pragma mark - RunLoop

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

#pragma mark - Connection

- (void)startOperation
{
    NSMutableURLRequest *request = [self.loadingRequest.request mutableCopy];
    request.URL = [self.loadingRequest.request.URL ll_originalSchemeURL];
    request.cachePolicy = NSURLRequestReloadIgnoringCacheData;  // very important
    
    // range
    NSRange range;
    if ([self.loadingRequest.dataRequest respondsToSelector:@selector(requestsAllDataToEndOfResource)] &&
        self.loadingRequest.dataRequest.requestsAllDataToEndOfResource) {
        range = NSMakeRange(self.loadingRequest.dataRequest.requestedOffset, NSIntegerMax);
    } else {
        range = NSMakeRange(self.loadingRequest.dataRequest.requestedOffset, self.loadingRequest.dataRequest.requestedLength);
    }
    NSString *rangeString = LLRangeToHTTPRangeHeader(range);
    [request setValue:rangeString forHTTPHeaderField:@"Range"];
    
    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [self.connection start];
    [self startRunLoop];
}

- (void)requestDidFinishWithResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error
{
    LLLog(@"Request Complete: %@, %@, %ld", response, error, data.length);
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (nil == error) {
            [self.loadingRequest ll_fillContentInformation:response];
            [self.loadingRequest.dataRequest respondWithData:data];
            [self.loadingRequest finishLoading];
        } else {
            [self.loadingRequest finishLoadingWithError:error];
        }
    });
}

#pragma mark - NSURLConnectionDelegate && NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    LLLog(@"didFailWithError: %@", error);
    [self.loadingRequest finishLoadingWithError:error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    LLLog(@"connectionDidFinishLoading");
    [self.loadingRequest finishLoading];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [self.loadingRequest ll_fillContentInformation:response];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.loadingRequest.dataRequest respondWithData:data];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
    self.loadingRequest.redirect = request;
    return request;
}

@end
