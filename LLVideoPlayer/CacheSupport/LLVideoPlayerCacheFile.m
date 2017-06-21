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

#define MAX_MEM_DATA_SIZE (5 * 1024 * 1024)

@interface LLOffsetData : NSObject

@property (nonatomic, assign) NSInteger offset;
@property (nonatomic, strong) NSData *data;

+ (instancetype)dataWithData:(NSData *)data atOffset:(NSInteger)offset;
- (instancetype)initWithData:(NSData *)data atOffset:(NSInteger)offset;

@end

@implementation LLOffsetData

+ (instancetype)dataWithData:(NSData *)data atOffset:(NSInteger)offset
{
    return [[self alloc] initWithData:data atOffset:offset];
}

- (instancetype)initWithData:(NSData *)data atOffset:(NSInteger)offset
{
    self = [super init];
    if (self) {
        self.data = data;
        self.offset = offset;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ %@",
            NSStringFromClass([self class]),
            NSStringFromRange(NSMakeRange(self.offset, self.data.length))];
}

@end

// ================================================================

@interface LLVideoPlayerCacheFile () {
    NSInteger _fileLength;
    NSURLResponse *_response;
}

@property (nonatomic, strong) LLVideoPlayerCachePolicy *cachePolicy;
@property (nonatomic, strong) NSString *cacheFilePath;
@property (nonatomic, strong) NSString *indexFilePath;
@property (nonatomic, strong) NSMutableArray<NSValue *> *ranges;
@property (nonatomic, strong) NSMutableArray<LLOffsetData *> *data;
@property (nonatomic, assign) NSInteger memDataSize;
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
        self.ranges = [NSMutableArray array];
        self.data = [NSMutableArray array];
        self.cachePolicy = cachePolicy;
        self.cacheFilePath = filePath;
        self.indexFilePath = [NSString stringWithFormat:@"%@%@", filePath, [LLVideoPlayerCacheFile indexFileExtension]];
        
        NSString *dir = [filePath stringByDeletingLastPathComponent];
        if (NO == [[NSFileManager defaultManager] fileExistsAtPath:dir]) {
            if (NO == [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                                withIntermediateDirectories:YES attributes:nil error:nil]) {
                LLLog(@"cannot create directory: %@", dir);
                return nil;
            }
        }
        
        if (NO == [[NSFileManager defaultManager] fileExistsAtPath:self.cacheFilePath]) {
            if (NO == [[NSFileManager defaultManager] createFileAtPath:self.cacheFilePath contents:nil attributes:nil]) {
                return nil;
            }
        }
        
        if (NO == [[NSFileManager defaultManager] fileExistsAtPath:self.indexFilePath]) {
            if (NO == [[NSFileManager defaultManager] createFileAtPath:self.indexFilePath contents:nil attributes:nil]) {
                return nil;
            }
        }
        
        self.readFileHandle = [NSFileHandle fileHandleForReadingAtPath:self.cacheFilePath];
        self.writeFileHandle = [NSFileHandle fileHandleForWritingAtPath:self.cacheFilePath];
        
        [self loadIndexFileAtStartup];
        [LLVideoPlayerCacheFile checkCacheWithFile:self.cacheFilePath policy:self.cachePolicy];
        LLLog(@"[CacheSupport] cache file path: %@", filePath);
        LLLog(@"[LocalCache] {fileLength: %lu, ranges: %@, headers: %@, data: %@}",
              _fileLength, self.ranges, self.allHeaderFields, self.data);
    }
    return self;
}

#pragma mark - Private

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
    
    _fileLength = [dict[@"size"] integerValue];
    
    NSMutableArray *ranges = dict[@"ranges"];
    [self.ranges removeAllObjects];
    for (NSString *rangeString in ranges) {
        NSRange range = NSRangeFromString(rangeString);
        [self.ranges addObject:[NSValue valueWithRange:range]];
    }
    
    self.allHeaderFields = dict[@"allHeaderFields"];
    
    return YES;
}

- (BOOL)saveIndexFile
{
    return [self saveIndexFileWithHeaders:self.allHeaderFields];
}

- (BOOL)saveIndexFileWithHeaders:(NSDictionary *)headers
{
    NSMutableArray *ranges = [NSMutableArray array];
    
    for (NSValue *rangeValue in self.ranges) {
        [ranges addObject:NSStringFromRange([rangeValue rangeValue])];
    }
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"size"] = @(_fileLength);
    dict[@"ranges"] = ranges;
    dict[@"allHeaderFields"] = headers;
    
    NSData *indexData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    if (nil == indexData) {
        return NO;
    }
    
    return [indexData writeToFile:self.indexFilePath atomically:YES];
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
    LLLog(@"{fileLength: %lu, ranges: %@, headers: %@}",
          _fileLength, self.ranges, self.allHeaderFields);
}

- (void)addRange:(NSRange)range
{
    NSInteger index = NSNotFound;
    for (NSInteger i = self.ranges.count - 1; i >= 0; i--) {
        NSRange r = [self.ranges[i] rangeValue];
        if (r.location < range.location) {
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
    if (resultRange.length > 0) {
        return resultRange;
    } else {
        return LLInvalidRange;
    }
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

- (BOOL)hasCachedHTTPURLResponse
{
    return _fileLength > 0 && self.allHeaderFields.count > 0;
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

- (void)appendMemData:(NSData *)data atOffset:(NSInteger)offset
{
    NSInteger index = NSNotFound;
    for (NSInteger i = self.data.count - 1; i >= 0; i--) {
        LLOffsetData *data = self.data[i];
        if (offset < data.offset) {
            index = i;
            break;
        }
    }
    
    LLOffsetData *offsetData = [LLOffsetData dataWithData:data atOffset:offset];
    
    if (index == NSNotFound) {
        [self.data addObject:offsetData];
    } else {
        [self.data insertObject:offsetData atIndex:index];
    }
    
    self.memDataSize += data.length;
    
    // merge ranges if possible
    for (NSUInteger i = 0; i < self.data.count; i++) {
        if ((i + 1) < self.data.count) {
            NSInteger currentOffset = self.data[i].offset;
            NSInteger currentLength = self.data[i].data.length;
            NSInteger nextOffset = self.data[i+1].offset;
            if (currentOffset + currentLength == nextOffset) {
                if ([self.data[i] isKindOfClass:[NSMutableData class]]) {
                    NSMutableData *mutableData = (NSMutableData *)self.data[i].data;
                    [mutableData appendData:self.data[i+1].data];
                } else {
                    NSMutableData *mutableData = [NSMutableData data];
                    [mutableData appendData:self.data[i].data];
                    [mutableData appendData:self.data[i+1].data];
                    self.data[i].data = mutableData;
                }
                [self.data removeObjectAtIndex:(i+1)];
                i -= 1;
            }
        }
    }
}

- (void)syncMemData
{
    if (nil == self.writeFileHandle) {
        return;
    }
    
    LLLog(@"Synchronizing mem data... #%lu, %lu bytes", self.data.count, self.memDataSize);

    NSArray *array = [NSArray arrayWithArray:self.data];
    for (LLOffsetData *data in array) {
        @try {
            [self.writeFileHandle seekToFileOffset:data.offset];
            [self.writeFileHandle writeData:data.data];
            
            // Add/Remove
            [self addRange:NSMakeRange(data.offset, data.data.length)];
            [self.data removeObject:data];
            self.memDataSize -= data.data.length;
        } @catch (NSException *exception) {
            LLLog(@"write exception: %@", exception);
        }
    }
    
    LLLog(@"Synchronized. #%lu, %lu bytes", self.data.count, self.memDataSize);
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
            [self makeErrorWithMessage:@"no cached found" code:-3 forError:error];
            return nil;
        }
        
        if (NO == NSEqualRanges(resultRange, range)) {
            [self makeErrorWithMessage:@"range not matched" code:-4 forError:error];
            return nil;
        }
        
        NSData *data = [self readDataWithRange:range];
        if (nil == data) {
            [self makeErrorWithMessage:@"read null" code:-5 forError:error];
        }
        
        return data;
    }
}

- (void)writeData:(NSData *)data atOffset:(NSInteger)offset
{
    if (nil == self.writeFileHandle) {
        return;
    }
    if (nil == data) {
        return;
    }
        
    @synchronized (self) {
        if (offset >= _fileLength) {
            LLLog(@"[ERR] write data overflow: %ld (file length: %ld)", offset, _fileLength);
            return;
        }
        
        [self appendMemData:data atOffset:offset];
        
        if (self.memDataSize >= MAX_MEM_DATA_SIZE) {
            [self syncMemData];
        }
    }
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
        [self syncMemData];
        [self saveIndexFile];
        LLLog(@"[Synchronize] {fileLength: %lu, ranges: %@, headers: %@, data: %@}",
              _fileLength, self.ranges, self.allHeaderFields, self.data);
    }
}

@end
