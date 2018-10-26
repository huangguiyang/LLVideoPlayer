//
//  LLVideoPlayerCacheFile.m
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import "LLVideoPlayerCacheFile.h"
#import "LLVideoPlayerCacheUtils.h"
#import "NSURLResponse+LLVideoPlayer.h"
#import "AVAssetResourceLoadingRequest+LLVideoPlayer.h"
#import "NSString+LLVideoPlayer.h"
#import <sys/stat.h>
#import <sys/mman.h>

NSString * const kLLVideoCacheFileExtensionIndex = @"idx";
NSString * const kLLVideoCacheFileExtensionPreload = @"preload";
NSString * const kLLVideoCacheFileExtensionPreloding = @"preloading";

static int MapFile(const char *filename, void **outDataPtr, size_t *outDataLength) {
    int fd;
    int outError = 0;
    struct stat statInfo;
    *outDataPtr = NULL;
    *outDataLength = 0;
    
    fd = open(filename, O_RDWR, 0);
    if (fd < 0) {
        outError = errno;
    } else {
        if (fstat(fd, &statInfo) < 0) {
            outError = errno;
        } else {
            *outDataPtr = mmap(NULL,
                               statInfo.st_size,
                               PROT_READ | PROT_WRITE,
                               MAP_FILE | MAP_SHARED, fd, 0);
            if (*outDataPtr == MAP_FAILED) {
                outError = errno;
            } else {
                *outDataLength = statInfo.st_size;
            }
        }
        
        close(fd);
    }
    
    return outError;
}

@interface LLVideoPlayerCacheFile () {
    NSUInteger _fileLength;
    void *_fileDataPtr;
    BOOL _complete;
}

@property (nonatomic, strong) NSString *cacheFilePath;
@property (nonatomic, strong) NSString *indexFilePath;
@property (nonatomic, strong) NSDictionary *allHeaderFields;
@property (nonatomic, strong) NSRecursiveLock *lock;
@property (nonatomic, strong) NSURLResponse *response;
@property (nonatomic, strong) NSMutableArray<NSValue *> *ranges;

@end

@implementation LLVideoPlayerCacheFile

- (void)dealloc
{
    if (_fileDataPtr && _fileLength > 0) {
        munmap(_fileDataPtr, _fileLength);
    }
}

+ (instancetype)cacheFileWithFilePath:(NSString *)filePath
{
    return [[self alloc] initWithFilePath:filePath];
}

- (instancetype)initWithFilePath:(NSString *)filePath
{
    self = [super init];
    if (self) {
        _lock = [[NSRecursiveLock alloc] init];
        _ranges = [NSMutableArray array];
        _cacheFilePath = [filePath copy];
        _indexFilePath = [NSString stringWithFormat:@"%@.%@", filePath, kLLVideoCacheFileExtensionIndex];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *dir = [filePath stringByDeletingLastPathComponent];
        if (NO == [fileManager fileExistsAtPath:dir] &&
            NO == [fileManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil]) {
            return nil;
        }
        
        [self loadExternalCache];
        if (NO == [self loadCacheFile]) {
            [fileManager removeItemAtPath:_indexFilePath error:nil];
            [fileManager removeItemAtPath:_cacheFilePath error:nil];
        }
        
        [self checkComplete];
    }
    return self;
}

#pragma mark - Private

- (void)loadExternalCache
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (NO == [fileManager fileExistsAtPath:_indexFilePath] || NO == [fileManager fileExistsAtPath:_cacheFilePath]) {
        NSString *data = [NSString stringWithFormat:@"%@.%@", _cacheFilePath, kLLVideoCacheFileExtensionPreload];
        NSString *index = [NSString stringWithFormat:@"%@.%@", data, kLLVideoCacheFileExtensionIndex];
        if ([fileManager fileExistsAtPath:data] && [fileManager fileExistsAtPath:index]) {
            [fileManager removeItemAtPath:_indexFilePath error:nil];
            [fileManager removeItemAtPath:_cacheFilePath error:nil];
            [fileManager moveItemAtPath:index toPath:_indexFilePath error:nil];
            [fileManager moveItemAtPath:data toPath:_cacheFilePath error:nil];
        }
    }
}

- (void)checkComplete
{
    if (_ranges.count == 1) {
        NSRange range = [_ranges[0] rangeValue];
        _complete = range.location == 0 && range.length == _fileLength;
    } else {
        _complete = NO;
    }
}

- (BOOL)loadCacheFile
{
    NSData *indexData = [NSData dataWithContentsOfFile:_indexFilePath];
    if (nil == indexData) {
        return NO;
    }
    
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:indexData options:NSJSONReadingAllowFragments | NSJSONReadingMutableContainers error:nil];
    if (nil == dict || NO == [dict isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    
    _allHeaderFields = dict[@"allHeaderFields"];
    _fileLength = [[_allHeaderFields[@"Content-Range"] ll_decodeLengthFromContentRange] integerValue];
    if (_allHeaderFields.count == 0 || _fileLength == 0) {
        return NO;
    }
    
    NSMutableArray *ranges = dict[@"ranges"];
    [_ranges removeAllObjects];
    for (NSString *rangeString in ranges) {
        NSRange range = NSRangeFromString(rangeString);
        [_ranges addObject:[NSValue valueWithRange:range]];
    }
    
    struct stat statInfo;
    const char *filename = [_cacheFilePath UTF8String];
    int r = stat(filename, &statInfo);
    if (r == 0) {
        if (statInfo.st_size > 0 && statInfo.st_size != _fileLength) {
            return NO;
        }
        if (statInfo.st_size == 0) {
            if (truncate([_cacheFilePath UTF8String], _fileLength) != 0) {
                return NO;
            }
        }
        if (MapFile(filename, &_fileDataPtr, &_fileLength) != 0) {
            return NO;
        }
    } else if (r == ENOENT) {
        if (NO == [[NSFileManager defaultManager] createFileAtPath:_cacheFilePath contents:nil attributes:nil]) {
            return NO;
        }
        if (truncate(filename, _fileLength) != 0) {
            return NO;
        }
        if (MapFile(filename, &_fileDataPtr, &_fileLength) != 0) {
            return NO;
        }
    } else {
        return NO;
    }
    
    return YES;
}

- (BOOL)saveIndexFileWithHeaders:(NSDictionary *)aHeaders andRanges:(NSArray *)aRanges
{
    NSMutableArray *ranges = [NSMutableArray array];
    
    for (NSValue *rangeValue in aRanges) {
        [ranges addObject:NSStringFromRange([rangeValue rangeValue])];
    }
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"ranges"] = ranges;
    dict[@"allHeaderFields"] = aHeaders;
    
    NSData *indexData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    if (nil == indexData) {
        return NO;
    }
    
    return [indexData writeToFile:self.indexFilePath atomically:YES];
}

- (BOOL)saveAllHeaderFields:(NSDictionary *)allHeaderFields
{
    BOOL success = [self saveIndexFileWithHeaders:allHeaderFields andRanges:self.ranges];
    if (success) {
        self.allHeaderFields = allHeaderFields;
    }
    return success;
}

- (void)makeErrorWithMessage:(NSString *)message code:(NSInteger)code forError:(NSError **)error
{
    if (error) {
        *error = [NSError errorWithDomain:@"LLVideoPlayerCacheFile"
                                     code:code
                                 userInfo:@{NSLocalizedDescriptionKey:message}];
    }
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

#pragma mark - Read/Write

- (NSData *)dataWithRange:(NSRange)range error:(NSError **)error
{
    if (NO == LLValidFileRange(range)) {
        [self makeErrorWithMessage:@"invalid file range" code:-1 forError:error];
        return nil;
    }
    
    if (NULL == _fileDataPtr) {
        [self makeErrorWithMessage:@"read file handle nil" code:-2 forError:error];
        return nil;
    }
    
    [_lock lock];
    NSRange resultRange = [self cachedRangeForRange:range];
    if (NO == LLValidFileRange(resultRange)) {
        [self makeErrorWithMessage:@"no cached found or not match" code:-3 forError:error];
        [_lock unlock];
        return nil;
    }
    
    NSData *data = [[NSData alloc] initWithBytes:(char *)_fileDataPtr + range.location length:range.length];
    if (nil == data) {
        [self makeErrorWithMessage:@"read null" code:-4 forError:error];
    }
    [_lock unlock];
    return data;
}

- (void)writeData:(NSData *)data atOffset:(NSInteger)offset
{
    if (nil == data || data.length == 0 || NULL == _fileDataPtr) {
        return;
    }
    if (offset > _fileLength) {
        return;
    }
    
    __weak typeof(self) wself = self;
    ll_run_on_non_ui_thread(^{
        __strong typeof(wself) self = wself;
        
        [self.lock lock];
        memcpy((char *)_fileDataPtr + offset, [data bytes], data.length);
        // Add Range
        [self addRange:NSMakeRange(offset, data.length)];
        [self.lock unlock];
    });
}

- (BOOL)gotFileLength:(NSUInteger)length
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:_cacheFilePath]) {
        [fileManager removeItemAtPath:_cacheFilePath error:nil];
    }
    
    if (NO == [fileManager createFileAtPath:_cacheFilePath contents:nil attributes:nil]) {
        return NO;
    }
    
    const char *filename = [_cacheFilePath UTF8String];
    
    if (truncate(filename, length) != 0) {
        return NO;
    }
    
    if (MapFile(filename, &_fileDataPtr, &_fileLength) != 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)writeResponse:(NSHTTPURLResponse *)response
{
    BOOL success = YES;
    if (_fileLength == 0) {
        success = [self gotFileLength:[response ll_totalLength]];
    }
    success = success && [self saveAllHeaderFields:[response allHeaderFields]];
    
    return success;
}

- (void)receiveResponse:(NSURLResponse *)response
{
    if (nil == response || NO == [response isKindOfClass:[NSHTTPURLResponse class]]) {
        return;
    }
    [_lock lock];
    if (nil == _response) {
        // save local
        [self writeResponse:(NSHTTPURLResponse *)response];
        _response = response;
    }
    [_lock unlock];
}

- (NSURLResponse *)constructURLResponseForURL:(NSURL *)url andRange:(NSRange)range
{
    NSHTTPURLResponse *response = nil;
    
    [_lock lock];
    if (_fileLength > 0 && _allHeaderFields.count > 0) {
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
        NSString *httpVersion = @"HTTP/1.1";
        
        response = [[NSHTTPURLResponse alloc] initWithURL:url
                                               statusCode:statusCode
                                              HTTPVersion:httpVersion
                                             headerFields:responseHeaders];
    }
    [_lock unlock];
    return response;
}

- (void)enumerateRangesWithRequestRange:(NSRange)requestRange usingBlock:(void (^)(NSRange range, BOOL cached))block
{
    NSParameterAssert(block);
    NSInteger start = requestRange.location;
    NSInteger end = requestRange.length == NSIntegerMax ? NSIntegerMax : NSMaxRange(requestRange);
    
    NSArray<NSValue *> *ranges = [self cachedRanges];
    for (NSValue *value in ranges) {
        NSRange range = [value rangeValue];
        
        if (start >= NSMaxRange(range)) {
            continue;
        }
        
        if (start < range.location) {
            NSInteger cacheEnd = MIN(range.location, end);
            block(NSMakeRange(start, cacheEnd - start), NO);
            start = cacheEnd;
            if (start == end) {
                break;
            }
        }
        
        // in range
        NSAssert(NSLocationInRange(start, range), @"Oops!!!");
        
        if (end <= NSMaxRange(range)) {
            block(NSMakeRange(start, end - start), YES);
            start = end;
            break;
        }
        
        block(NSMakeRange(start, NSMaxRange(range) - start), YES);
        start = NSMaxRange(range);
    }
    
    if (end > start && (self.fileLength == 0 || start < self.fileLength)) {
        if (end == NSIntegerMax) {
            block(NSMakeRange(start, NSIntegerMax), NO);
        } else {
            block(NSMakeRange(start, end - start), NO);
        }
    }
}

- (void)synchronize
{
    __weak typeof(self) wself = self;
    ll_run_on_non_ui_thread(^{
        __strong typeof(wself) self = wself;
        
        [self.lock lock];
        [self saveIndexFileWithHeaders:self.allHeaderFields andRanges:self.ranges];
        [self.lock unlock];
    });
}

- (BOOL)isComplete
{
    return _complete;
}

- (NSArray *)cachedRanges
{
    [_lock lock];
    NSArray *ranges = [NSArray arrayWithArray:_ranges];
    [_lock unlock];
    return ranges;
}

+ (NSString *)cacheDirectory
{
    NSString *cache = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    return [cache stringByAppendingPathComponent:@"LLVideoPlayer"];
}

@end
