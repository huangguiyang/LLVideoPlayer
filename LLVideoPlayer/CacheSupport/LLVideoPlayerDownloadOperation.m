//
//  LLVideoPlayerDownloadOperation.m
//  Pods
//
//  Created by mario on 2017/7/26.
//
//

#import "LLVideoPlayerDownloadOperation.h"
#import "NSURLResponse+LLVideoPlayer.h"
#import "LLVideoPlayerCacheUtils.h"

@interface LLVideoPlayerDownloadOperation () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>
{
    NSURLConnection *_connection;
    NSMutableData *_mutableData;
    CFRunLoopRef _runloop;
}

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, assign) NSRange range;
@property (nonatomic, strong) LLVideoPlayerDownloadFile *downloadFile;

@end

@implementation LLVideoPlayerDownloadOperation

- (void)dealloc
{
    [_connection cancel];
}

+ (instancetype)operationWithURL:(NSURL *)url
                           range:(NSRange)range
                    downloadFile:(LLVideoPlayerDownloadFile *)downloadFile
{
    return [[self alloc] initWithURL:url range:range downloadFile:downloadFile];
}

- (instancetype)initWithURL:(NSURL *)url
                      range:(NSRange)range
               downloadFile:(LLVideoPlayerDownloadFile *)downloadFile
{
    self = [super init];
    if (self) {
        self.url = url;
        self.range = range;
        self.downloadFile = downloadFile;
    }
    return self;
}

- (void)main
{
    @autoreleasepool {
        @synchronized (self) {
            if ([self isCancelled]) {
                return;
            }
            
            [self setExecuting:YES];
            
            if ([self.downloadFile validateCache]) {
                [self setExecuting:NO];
                [self setFinished:YES];
                return;
            }
            
            // start
            [self startRequest];
        }
        
        [self startRunLoop];
        
        [self setExecuting:NO];
        [self setFinished:YES];
    }
}

- (void)cancel
{
    @synchronized (self) {
        [super cancel];
        [_connection cancel];
        _connection = nil;
    }
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
        _runloop = NULL;
    }
}

- (void)startRequest
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url
                                                           cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30];
    // NOT allowed cellular access
    request.allowsCellularAccess = NO;
    
    NSString *rangeString = LLRangeToHTTPRangeHeader(self.range);
    [request setValue:rangeString forHTTPHeaderField:@"Range"];
    
    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [_connection start];
}

- (void)failWithError:(NSError *)error
{
    [self stopRunLoop];
}

- (void)success
{
    [self stopRunLoop];
}

#pragma mark - NSURLConnectionDelegate & NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self failWithError:error];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{    
    if (nil == response || NO == [response isKindOfClass:[NSHTTPURLResponse class]]) {
        return;
    }
    
    if (NO == [(NSHTTPURLResponse *)response ll_supportRange]) {
        [connection cancel];
        [self failWithError:[NSError errorWithDomain:NSURLErrorDomain
                                                code:NSURLErrorCancelled
                                            userInfo:@{NSLocalizedDescriptionKey: @"Range not supported."}]];
        return;
    }
    
    [self.downloadFile didReceivedResponse:(NSHTTPURLResponse *)response];
    _mutableData = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_mutableData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self.downloadFile writeData:_mutableData atOffset:0];
    [self success];
}

@end
