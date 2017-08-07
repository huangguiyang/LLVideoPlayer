//
//  LLVideoPlayerCacheFile.m
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import "LLVideoPlayerCacheFile.h"
#import "LLVideoPlayerCacheUtils.h"
#import "NSHTTPURLResponse+LLVideoPlayer.h"
#import "LLVideoPlayerInternal.h"
#import "AVAssetResourceLoadingRequest+LLVideoPlayer.h"
#import "LLVideoPlayerCacheFile+CachePolicy.h"
#import "NSString+LLVideoPlayer.h"
#import "LLVideoPlayerDownloader.h"

@interface LLVideoPlayerCacheFile () {
    NSInteger _fileLength;
    NSURLResponse *_response;
    BOOL _complete;
}

@property (nonatomic, strong) LLVideoPlayerCachePolicy *cachePolicy;
@property (nonatomic, strong) NSString *cacheFilePath;
@property (nonatomic, strong) NSString *indexFilePath;
@property (nonatomic, strong) NSMutableArray<NSValue *> *ranges;
@property (nonatomic, strong) NSDictionary *allHeaderFields;
@property (nonatomic, strong) NSFileHandle *writeFileHandle;
@property (nonatomic, strong) NSFileHandle *readFileHandle;

@end

@implementation LLVideoPlayerCacheFile

+ (NSString *)cacheDirectory
{
    NSString *cache = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    return [cache stringByAppendingPathComponent:@"LLVideoPlayer"];
}

+ (NSString *)indexFileExtension
{
    return @".idx";
}

- (void)dealloc
{
    [self.writeFileHandle closeFile];
    [self.readFileHandle closeFile];
}

+ (instancetype)cacheFileWithFilePath:(NSString *)filePath cachePolicy:(LLVideoPlayerCachePolicy *)cachePolicy
{
    return [[self alloc] initWithFilePath:filePath cachePolicy:cachePolicy];
}

- (instancetype)initWithFilePath:(NSString *)filePath cachePolicy:(LLVideoPlayerCachePolicy *)cachePolicy
{
    self = [super init];
    if (self) {
        // Check first
        [LLVideoPlayerCacheFile checkCacheDirectoryWithCachePolicy:cachePolicy];
        
        self.ranges = [NSMutableArray array];
        self.cachePolicy = cachePolicy;
        self.cacheFilePath = filePath;
        self.indexFilePath = [NSString stringWithFormat:@"%@%@", filePath, [LLVideoPlayerCacheFile indexFileExtension]];
        
        NSString *dir = [filePath stringByDeletingLastPathComponent];
        if (NO == [[NSFileManager defaultManager] fileExistsAtPath:dir] &&
            NO == [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil]) {
            LLLog(@"[ERROR] Cannot create cache directory: %@", dir);
            return nil;
        }
        
        if (NO == [[NSFileManager defaultManager] fileExistsAtPath:self.cacheFilePath] &&
            NO == [[NSFileManager defaultManager] createFileAtPath:self.cacheFilePath contents:nil attributes:nil]) {
            LLLog(@"[ERROR] Cannot create cache file: %@", self.cacheFilePath);
            return nil;
        }
        
        if (NO == [[NSFileManager defaultManager] fileExistsAtPath:self.indexFilePath] &&
            NO == [[NSFileManager defaultManager] createFileAtPath:self.indexFilePath contents:nil attributes:nil]) {
            LLLog(@"[ERROR] Cannot create index file: %@", self.cacheFilePath);
            return nil;
        }
        
        self.readFileHandle = [NSFileHandle fileHandleForReadingAtPath:self.cacheFilePath];
        self.writeFileHandle = [NSFileHandle fileHandleForWritingAtPath:self.cacheFilePath];
        
        [self loadIndexFileAtStartup];
        [self loadExternalCache];
        [self checkComplete];
        
        LLLog(@"[LocalCache] {fileLength: %lu, ranges: %@, headers: %@}",
              _fileLength, self.ranges, self.allHeaderFields);
    }
    return self;
}

#pragma mark - Private

- (void)loadExternalCache
{
    LLVideoPlayerDownloadFile *downloadFile = [LLVideoPlayerDownloader getExternalDownloadFileWithName:[self.cacheFilePath lastPathComponent]];
    if (nil == downloadFile) {
        return;
    }
    NSDictionary *dict = [downloadFile readCache];
    if (nil == dict) {
        return;
    }
    
    LLLog(@"Read Download Cache OK.");
    BOOL needToSave = NO;
    
    if (nil == _allHeaderFields) {
        _allHeaderFields = dict[@"headers"];
        _fileLength = [[_allHeaderFields[@"Content-Range"] ll_decodeLengthFromContentRange] integerValue];
        needToSave = YES;
    }

    NSRange range = NSRangeFromString(dict[@"range"]);
    NSRange cache = [self cachedRangeForRange:range];
    if (NO == LLValidFileRange(cache)) {
        [self writeData:dict[@"data"] atOffset:range.location];
        needToSave = YES;
    } else {
        LLLog(@"Range: %@ already cached.", NSStringFromRange(range));
    }
    
    if (needToSave) {
        [self synchronize];
    }
}

- (void)checkComplete
{
    if (self.ranges.count == 1) {
        NSRange range = [self.ranges[0] rangeValue];
        _complete = range.location == 0 && range.length == _fileLength;
    } else {
        _complete = NO;
    }
#ifdef DEBUG
    if (_complete) {
        LLLog(@"Cache Complete!!!");
    }
#endif
}

- (void)loadIndexFileAtStartup
{
    // load index data
    if (NO == [self loadIndexFile]) {
        [self truncateFileToLength:0];
    }
}

- (BOOL)loadIndexFile
{
    NSError *error = nil;
    NSData *indexData = [NSData dataWithContentsOfFile:self.indexFilePath];
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:indexData options:NSJSONReadingAllowFragments | NSJSONReadingMutableContainers error:&error];
    if (error) {
        LLLog(@"load index file failed: %@", error);
        return NO;
    }
    if (nil == dict || NO == [dict isKindOfClass:[NSDictionary class]]) {
        LLLog(@"empty/invalid data: %@", dict);
        return NO;
    }
    
    NSMutableArray *ranges = dict[@"ranges"];
    [self.ranges removeAllObjects];
    for (NSString *rangeString in ranges) {
        NSRange range = NSRangeFromString(rangeString);
        [self.ranges addObject:[NSValue valueWithRange:range]];
    }
    
    _allHeaderFields = dict[@"allHeaderFields"];
    _fileLength = [[_allHeaderFields[@"Content-Range"] ll_decodeLengthFromContentRange] integerValue];
    
    return YES;
}

- (BOOL)saveIndexFileWithHeaders:(NSDictionary *)headers
{
    NSMutableArray *ranges = [NSMutableArray array];
    
    for (NSValue *rangeValue in self.ranges) {
        [ranges addObject:NSStringFromRange([rangeValue rangeValue])];
    }
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"ranges"] = ranges;
    dict[@"allHeaderFields"] = headers;
    
    NSData *indexData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    if (nil == indexData) {
        return NO;
    }
    
    return [indexData writeToFile:self.indexFilePath atomically:YES];
}

- (BOOL)saveIndexFile
{
    return [self saveIndexFileWithHeaders:self.allHeaderFields];
}

- (BOOL)saveAllHeaderFields:(NSDictionary *)allHeaderFields
{
    BOOL success = [self saveIndexFileWithHeaders:allHeaderFields];
    if (success) {
        self.allHeaderFields = allHeaderFields;
    }
    return success;
}

- (BOOL)truncateFileToLength:(NSInteger)length
{
    if (nil == self.writeFileHandle) {
        return NO;
    }
    
    [self.writeFileHandle truncateFileAtOffset:length];
    @try {
        unsigned long long end = [self.writeFileHandle seekToEndOfFile];
        if (end != length) {
            return NO;
        }
        _fileLength = length;
    } @catch (NSException *exception) {
        return NO;
    }
    
    return YES;
}

- (void)makeErrorWithMessage:(NSString *)message code:(NSInteger)code forError:(NSError **)error
{
    if (error) {
        *error = [NSError errorWithDomain:@"LLVideoPlayerCacheFile"
                                     code:code
                                 userInfo:@{NSLocalizedDescriptionKey:message}];
    }
    LLLog(@"[ERROR] can't read range: %@", message);
}

- (void)addRange:(NSRange)range
{
    NSInteger index = NSNotFound;
    for (NSInteger i = 0; i < self.ranges.count; i++) {
        NSRange r = [self.ranges[i] rangeValue];
        if (r.location >= range.location) {
            index = i;
            break;
        }
    }
    
    if (index == NSNotFound) {
        [self.ranges addObject:[NSValue valueWithRange:range]];
    } else {
        [self.ranges insertObject:[NSValue valueWithRange:range] atIndex:index];
    }
    
    // merge ranges if possible
    for (NSInteger i = 0; i < self.ranges.count; i++) {
        if ((i + 1) < self.ranges.count) {
            NSRange currentRange = [self.ranges[i] rangeValue];
            NSRange nextRange = [self.ranges[i+1] rangeValue];
            if (LLRangeCanMerge(currentRange, nextRange)) {
                [self.ranges removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(i, 2)]];
                [self.ranges insertObject:[NSValue valueWithRange:NSUnionRange(currentRange, nextRange)] atIndex:i];
                i -= 1;
            }
        }
    }
    
    [self checkComplete];
}


- (NSRange)cachedRangeForRange:(NSRange)requestRange
{
    if (requestRange.location >= _fileLength) {
        return LLInvalidRange;
    }
    
    NSRange foundRange = LLInvalidRange;
    for (NSValue *rangeValue in self.ranges) {
        NSRange range = [rangeValue rangeValue];
        if (NSLocationInRange(requestRange.location, range)) {
            foundRange = range;
            break;
        }
    }
    
    if (NSEqualRanges(foundRange, LLInvalidRange)) {
        return LLInvalidRange;
    }
    
    NSRange resultRange = NSIntersectionRange(foundRange, requestRange);
    if (NSEqualRanges(resultRange, requestRange)) {
        return resultRange;
    } else {
        return LLInvalidRange;
    }
}

- (BOOL)hasCachedHTTPURLResponse
{
    return _fileLength > 0 && self.allHeaderFields.count > 0;
}

- (NSData *)readDataWithRange:(NSRange)range
{
    @try {
        [self.readFileHandle seekToFileOffset:range.location];
        return [self.readFileHandle readDataOfLength:range.length];
    } @catch (NSException *exception) {
        LLLog(@"read exception: %@", exception);
        return nil;
    }
}

#pragma mark - Read/Write

- (NSInteger)fileLength
{
    @synchronized (self) {
        return _fileLength;
    }
}

- (NSArray<NSValue *> *)cachedRanges
{
    @synchronized (self) {
        return [NSArray arrayWithArray:_ranges];
    }
}

- (NSData *)dataWithRange:(NSRange)range error:(NSError **)error
{
    if (NO == LLValidFileRange(range)) {
        [self makeErrorWithMessage:@"invalid file range" code:-1 forError:error];
        return nil;
    }
    
    if (nil == self.readFileHandle) {
        [self makeErrorWithMessage:@"read file handle nil" code:-2 forError:error];
        return nil;
    }
    
    @synchronized (self) {
        NSRange resultRange = [self cachedRangeForRange:range];
        if (NO == LLValidFileRange(resultRange)) {
            [self makeErrorWithMessage:@"no cached found or not match" code:-3 forError:error];
            return nil;
        }
        
        NSData *data = [self readDataWithRange:range];
        if (nil == data) {
            [self makeErrorWithMessage:@"read null" code:-4 forError:error];
        }
        
        return data;
    }
}

- (void)writeData:(NSData *)data atOffset:(NSInteger)offset
{
    if (nil == data || data.length == 0 || nil == self.writeFileHandle) {
        LLLog(@"[ERROR] write data nil");
        return;
    }
    if (offset > [self fileLength]) {
        LLLog(@"[ERROR] write data overflow: %ld > %ld", offset, [self fileLength]);
        return;
    }
        
    @synchronized (self) {
        @try {
            [self.writeFileHandle seekToFileOffset:offset];
            [self.writeFileHandle writeData:data];
        } @catch (NSException *exception) {
            LLLog(@"write exception: %@", exception);
            return;
        }
                
        // Add Range
        [self addRange:NSMakeRange(offset, data.length)];
    }
}

- (BOOL)writeResponse:(NSHTTPURLResponse *)response
{
    BOOL success = YES;
    if (_fileLength == 0) {
        success = [self truncateFileToLength:[response ll_totalLength]];
    }
    success = success && [self saveAllHeaderFields:[response allHeaderFields]];
    
    return success;
}

- (NSHTTPURLResponse *)constructHTTPURLResponseForURL:(NSURL *)url andRange:(NSRange)range
{
    if (NO == [self hasCachedHTTPURLResponse]) {
        return nil;
    }
    
    if (range.length == NSIntegerMax) {
        range.length = _fileLength - range.location;
    }
    
    NSMutableDictionary *responseHeaders = [self.allHeaderFields mutableCopy];
    NSString *contentRangeKey = @"Content-Range";
    BOOL supportRange = responseHeaders[contentRangeKey] != nil;
    
    if (supportRange && LLValidByteRange(range)) {
        responseHeaders[contentRangeKey] = LLRangeToHTTPRangeResponseHeader(range, _fileLength);
    } else {
        [responseHeaders removeObjectForKey:contentRangeKey];
    }
    
    responseHeaders[@"Content-Length"] = [NSString stringWithFormat:@"%tu", range.length];
    NSInteger statusCode = supportRange ? 206 : 200;
    
    return [[NSHTTPURLResponse alloc] initWithURL:url
                                       statusCode:statusCode
                                      HTTPVersion:@"HTTP/1.1"
                                     headerFields:responseHeaders];
}

- (void)receivedResponse:(NSHTTPURLResponse *)response forLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    @synchronized (self) {
        if (nil == _response) {
            [loadingRequest ll_fillContentInformation:response];
            // save local
            [self writeResponse:(NSHTTPURLResponse *)response];
            _response = response;
        }
    }
}

- (void)tryResponseForLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest withRange:(NSRange)requestRange
{
    @synchronized (self) {
        if (nil == _response && [self hasCachedHTTPURLResponse]) {
            NSHTTPURLResponse *respone = [self constructHTTPURLResponseForURL:loadingRequest.request.URL
                                                                     andRange:requestRange];
            if (respone) {
                [loadingRequest ll_fillContentInformation:respone];
                _response = respone;
            }
        }
    }
}

- (void)synchronize
{
    @synchronized (self) {
        [self saveIndexFile];
        LLLog(@"[Synchronize] {fileLength: %lu, ranges: %@, headers: %@}",
              _fileLength, self.ranges, self.allHeaderFields);
    }
}

- (void)clear
{
    @synchronized (self) {
        _fileLength = 0;
        _response = nil;
        self.allHeaderFields = nil;
        [self.ranges removeAllObjects];
        [[NSFileManager defaultManager] removeItemAtPath:self.indexFilePath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:self.cacheFilePath error:nil];
    }
}

- (BOOL)isComplete
{
    @synchronized (self) {
        return _complete;
    }
}

@end
