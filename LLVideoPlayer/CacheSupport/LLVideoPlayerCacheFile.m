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

static int mapfile(const char *filename, void **out_data_ptr, size_t *out_data_length)
{
    int fd;
    int error = 0;
    struct stat statInfo;
    *out_data_ptr = NULL;
    *out_data_length = 0;
    
    fd = open(filename, O_RDWR, 0);
    if (fd < 0) {
        error = errno;
    } else {
        if (fstat(fd, &statInfo) < 0) {
            error = errno;
        } else {
            *out_data_ptr = mmap(NULL,
                                 statInfo.st_size,
                                 PROT_READ | PROT_WRITE,
                                 MAP_FILE | MAP_SHARED, fd, 0);
            if (*out_data_ptr == MAP_FAILED) {
                error = errno;
            } else {
                *out_data_length = statInfo.st_size;
            }
        }
        
        close(fd);
    }
    
    return error;
}

@interface LLVideoPlayerCacheFile () {
    NSUInteger _fileLength;
    void *_fileDataPtr;
    BOOL _complete;
}

@property (nonatomic, strong) NSString *cacheFilePath;
@property (nonatomic, strong) NSString *indexFilePath;
@property (nonatomic, strong) NSDictionary *allHeaderFields;
@property (nonatomic, strong) NSLock *lock;
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

- (instancetype)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self) {
        _lock = [[NSLock alloc] init];
        _ranges = [NSMutableArray array];
        _cacheFilePath = [LLVideoPlayerCacheFile cacheFilePathWithURL:url];
        _indexFilePath = [NSString stringWithFormat:@"%@.%@", _cacheFilePath, kLLVideoCacheFileExtensionIndex];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *dir = [_cacheFilePath stringByDeletingLastPathComponent];
        if (NO == [fileManager fileExistsAtPath:dir] &&
            NO == [fileManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil]) {
            return nil;
        }
        
        [self loadCacheFile];
        [self checkComplete];
    }
    return self;
}

#pragma mark - Private

- (void)checkComplete
{
    if (_ranges.count == 1) {
        NSRange range = [_ranges[0] rangeValue];
        _complete = range.location == 0 && range.length == _fileLength;
    } else {
        _complete = NO;
    }
}

- (void)loadCacheFile
{
    if (NO == [self tryloadCacheFile]) {
        // reset index
        _fileLength = 0;
        _fileDataPtr = NULL;
        _allHeaderFields = nil;
        [_ranges removeAllObjects];
        [[NSFileManager defaultManager] removeItemAtPath:_indexFilePath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:_cacheFilePath error:nil];
    }
}

- (BOOL)tryloadCacheFile
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
    NSString *contentRange = LLValueForHTTPHeaderField(_allHeaderFields, @"Content-Range");
    _fileLength = [[contentRange ll_decodeLengthFromContentRange] integerValue];
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
        if (mapfile(filename, &_fileDataPtr, &_fileLength) != 0) {
            return NO;
        }
    } else if (r == ENOENT) {
        if (NO == [[NSFileManager defaultManager] createFileAtPath:_cacheFilePath contents:nil attributes:nil]) {
            return NO;
        }
        if (truncate(filename, _fileLength) != 0) {
            return NO;
        }
        if (mapfile(filename, &_fileDataPtr, &_fileLength) != 0) {
            return NO;
        }
    } else {
        return NO;
    }
    
    return YES;
}

- (BOOL)saveIndexFile
{
    NSMutableArray *ranges = [NSMutableArray array];
    
    for (NSValue *rangeValue in self.ranges) {
        [ranges addObject:NSStringFromRange([rangeValue rangeValue])];
    }
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"ranges"] = ranges;
    dict[@"allHeaderFields"] = self.allHeaderFields;
    
    NSData *indexData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    if (nil == indexData) {
        return NO;
    }
    
    return [indexData writeToFile:self.indexFilePath atomically:YES];
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

- (NSData *)dataWithRange:(NSRange)range
{
    if (NO == LLValidFileRange(range)) {
        return nil;
    }
    
    if (NULL == _fileDataPtr) {
        return nil;
    }
    
    NSData *data = nil;
    
    [self.lock lock];
    NSRange resultRange = [self cachedRangeForRange:range];
    if (LLValidFileRange(resultRange)) {
        data = [[NSData alloc] initWithBytes:(char *)_fileDataPtr + range.location length:range.length];
    }
    [self.lock unlock];
    
    return data;
}

- (void)writeData:(NSData *)data atOffset:(NSUInteger)offset
{
    if (nil == data || data.length == 0 || NULL == _fileDataPtr) {
        return;
    }
    if (offset > _fileLength) {
        return;
    }
    
    [self.lock lock];
    memcpy((char *)_fileDataPtr + offset, [data bytes], data.length);
    // Add Range
    [self addRange:NSMakeRange(offset, data.length)];
    [self.lock unlock];
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
    
    void *dataPtr = NULL;
    size_t dataLength = 0;
    
    if (mapfile(filename, &dataPtr, &dataLength) != 0) {
        return NO;
    }
    
    _fileDataPtr = dataPtr;
    _fileLength = dataLength;
    
    return YES;
}

- (void)receiveResponse:(NSURLResponse *)response
{
    if (nil == response || NO == [response isKindOfClass:[NSHTTPURLResponse class]]) {
        return;
    }
    [self.lock lock];
    if (nil == _response) {
        // save local
        _response = response;
        if (_fileLength == 0) {
            [self gotFileLength:[response ll_totalLength]];
        }
        if (nil == _allHeaderFields) {
            _allHeaderFields = [(NSHTTPURLResponse *)response allHeaderFields];
            [self saveIndexFile];
        }
    }
    [self.lock unlock];
}

- (NSURLResponse *)constructURLResponseForURL:(NSURL *)url andRange:(NSRange)range
{
    NSHTTPURLResponse *response = nil;
    
    [self.lock lock];
    if (_fileLength > 0 && _allHeaderFields.count > 0) {
        if (range.length == NSIntegerMax) {
            range.length = _fileLength - range.location;
        }
        
        NSMutableDictionary *responseHeaders = [self.allHeaderFields mutableCopy];
        NSString *contentRangeKey = @"Content-Range";
        BOOL supportRange = LLValueForHTTPHeaderField(responseHeaders, contentRangeKey) != nil;
        
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
    [self.lock unlock];
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
    [self.lock lock];
    [self saveIndexFile];
    [self.lock unlock];
}

- (BOOL)isComplete
{
    return _complete;
}

- (NSArray *)cachedRanges
{
    [self.lock lock];
    NSArray *ranges = [NSArray arrayWithArray:_ranges];
    [self.lock unlock];
    return ranges;
}

+ (NSString *)cacheDirectory
{
    NSString *cache = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    return [cache stringByAppendingPathComponent:@"LLVideoPlayer"];
}

+ (NSString *)cacheFilePathWithURL:(NSURL *)url
{
    NSString *name = [url.absoluteString ll_md5];
    NSString *dir = [self cacheDirectory];
    return [dir stringByAppendingPathComponent:name];
}

@end
