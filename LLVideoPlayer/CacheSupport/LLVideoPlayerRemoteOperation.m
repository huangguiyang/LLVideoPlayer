//
//  LLVideoPlayerRemoteOperation.m
//  Pods
//
//  Created by mario on 2017/8/21.
//
//

#import "LLVideoPlayerRemoteOperation.h"
#import "NSURL+LLVideoPlayer.h"
#import "LLVideoPlayerCacheUtils.h"
#import "NSURLResponse+LLVideoPlayer.h"
#import "LLVideoPlayerCacheManager.h"

@interface LLVideoPlayerRemoteOperation ()

@property (assign, nonatomic, getter=isExecuting) BOOL executing;
@property (assign, nonatomic, getter=isFinished) BOOL finished;

@property (nonatomic, weak) NSURLSession *unownedSession;
@property (nonatomic, strong) NSURLSession *ownedSession;
@property (nonatomic, strong) NSURLSessionDataTask *dataTask;
@property (nonatomic, assign) LLVideoPlayerRemoteOptions options;
@property (nonatomic, assign) NSUInteger offset;

@end

@implementation LLVideoPlayerRemoteOperation
@synthesize executing = _executing;
@synthesize finished = _finished;

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> %@", NSStringFromClass(self.class), self, [self.request valueForHTTPHeaderField:@"Range"]];
}

- (instancetype)initWithRequest:(NSURLRequest *)request cacheFile:(LLVideoPlayerCacheFile *)cacheFile
{
    self = [super init];
    if (self) {
        _request = request;
        _cacheFile = cacheFile;
        _unownedSession = [LLVideoPlayerCacheManager defaultManager].session;
        _options = 0;
    }
    return self;
}

- (void)reset
{
    self.delegate = nil;
    self.dataTask = nil;
    if (self.ownedSession) {
        [self.ownedSession invalidateAndCancel];
        self.ownedSession = nil;
    }
}

- (void)finish
{
    self.finished = YES;
    self.executing = NO;
    [self reset];
}

- (void)start
{
    @synchronized (self) {
        if ([self isCancelled]) {
            [self finish];
            return;
        }

        self.executing = YES;
        
        NSURLSession *session = self.unownedSession;
        if (nil == self.unownedSession) {
            NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
            self.ownedSession = [NSURLSession sessionWithConfiguration:sessionConfig
                                                              delegate:self
                                                         delegateQueue:nil];
            session = self.ownedSession;
        }
        
        NSRange range = LLHTTPRangeHeaderToRange([self.request valueForHTTPHeaderField:@"Range"]);
        self.offset = range.location;
        
        if (session == [LLVideoPlayerCacheManager defaultManager].session) {
            self.dataTask = [[LLVideoPlayerCacheManager defaultManager] createDataTaskWithRequest:self.request delegate:self];
        } else {
            self.dataTask = [session dataTaskWithRequest:self.request];
        }
        
        [self.dataTask resume];
    }
}

- (void)cancel
{
    @synchronized (self) {
        if ([self isFinished] || [self isCancelled]) {
            return;
        }
        
        [super cancel];
        
        [self.cacheFile synchronize];
        
        if ([self.delegate respondsToSelector:@selector(operation:didCompleteWithError:)]) {
            [self.delegate operation:self didCompleteWithError:
             [NSError errorWithDomain:@"LLVideoPlayerCacheTask" code:NSURLErrorCancelled userInfo:nil]];
        }

        if (self.dataTask) {
            [self.dataTask cancel];
            
            if (self.isExecuting) {
                self.executing = NO;
            }
            if (NO == self.isFinished) {
                self.finished = YES;
            }
        }
        
        [self reset];
    }
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    [self.cacheFile synchronize];
    
    if ([self.delegate respondsToSelector:@selector(operation:didCompleteWithError:)]) {
        [self.delegate operation:self didCompleteWithError:error];
    }
    
    [self finish];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    if (![response respondsToSelector:@selector(statusCode)] || ([((NSHTTPURLResponse *)response) statusCode] < 400 && [((NSHTTPURLResponse *)response) statusCode] != 304)) {
        [self.cacheFile receiveResponse:response];
        if ([self.delegate respondsToSelector:@selector(operation:didReceiveResponse:)]) {
            [self.delegate operation:self didReceiveResponse:response];
        }
    } else {
        NSUInteger code = [((NSHTTPURLResponse *)response) statusCode];
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:code userInfo:nil];
        
        [self.dataTask cancel];
        
        if ([self.delegate respondsToSelector:@selector(operation:didCompleteWithError:)]) {
            [self.delegate operation:self didCompleteWithError:error];
        }
        
        [self finish];
    }
    
    if (completionHandler) {
        completionHandler(NSURLSessionResponseAllow);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    [self.cacheFile writeData:data atOffset:self.offset];
    self.offset += data.length;
    if ([self.delegate respondsToSelector:@selector(operation:didReceiveData:)]) {
        [self.delegate operation:self didReceiveData:data];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler
{
    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    __block NSURLCredential *credential = nil;
    
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        if (!(self.options & LLVideoPlayerAllowInvalidSSLCertificates)) {
            disposition = NSURLSessionAuthChallengePerformDefaultHandling;
        } else {
            credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            disposition = NSURLSessionAuthChallengeUseCredential;
        }
    } else {
        if ([challenge previousFailureCount] == 0) {
            if (self.credential) {
                credential = self.credential;
                disposition = NSURLSessionAuthChallengeUseCredential;
            } else {
                disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
            }
        } else {
            disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
        }
    }
    
    if (completionHandler) {
        completionHandler(disposition, credential);
    }
}

- (void)setExecuting:(BOOL)executing {
    if (executing != _executing) {
        [self willChangeValueForKey:@"isExecuting"];
        _executing = executing;
        [self didChangeValueForKey:@"isExecuting"];
    }
}

- (void)setFinished:(BOOL)finished {
    if (finished != _finished) {
        [self willChangeValueForKey:@"isFinished"];
        _finished = finished;
        [self didChangeValueForKey:@"isFinished"];
    }
}

- (BOOL)isConcurrent {
    return YES;
}

- (BOOL)isAsynchronous {
    return YES;
}

@end
