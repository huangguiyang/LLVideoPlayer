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

@interface LLVideoPlayerCacheFile ()

@property (nonatomic, strong) NSString *cacheFilePath;
@property (nonatomic, strong) NSString *indexFilePath;
@property (nonatomic, strong) NSFileHandle *readFileHandle;
@property (nonatomic, strong) NSFileHandle *writeFileHandle;
@property (nonatomic, strong) NSMutableArray *ranges;
@property (nonatomic, assign) NSUInteger fileLength;
@property (nonatomic, assign) BOOL complete;
@property (nonatomic, assign) NSUInteger readOffset;

@end

@implementation LLVideoPlayerCacheFile

- (void)dealloc
{
    [self.readFileHandle closeFile];
    [self.writeFileHandle closeFile];
}

+ (instancetype)cacheFileWithFilePath:(NSString *)filePath
{
    return [[self alloc] initWithFilePath:filePath];
}

- (instancetype)initWithFilePath:(NSString *)filePath
{
    self = [super init];
    if (self) {
        NSString *cacheFilePath = [filePath copy];
        NSString *indexFilePath = [NSString stringWithFormat:@"%@%@", filePath, [LLVideoPlayerCacheFile indexFileExtension]];
        
        BOOL cacheFileExist = [[NSFileManager defaultManager] fileExistsAtPath:cacheFilePath];
        BOOL indexFileExist = [[NSFileManager defaultManager] fileExistsAtPath:indexFilePath];
        
        BOOL fileExist = cacheFileExist && indexFileExist;
        if (NO == fileExist) {
            NSString *directory = [cacheFilePath stringByDeletingLastPathComponent];
            if (NO == [[NSFileManager defaultManager] fileExistsAtPath:directory]) {
                [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
            }
            
            fileExist = [[NSFileManager defaultManager] createFileAtPath:cacheFilePath contents:nil attributes:nil] && [[NSFileManager defaultManager] createFileAtPath:indexFilePath contents:nil attributes:nil];
        }
        
        if (NO == fileExist) {
            return nil;
        }
        
        self.cacheFilePath = cacheFilePath;
        self.indexFilePath = indexFilePath;
        self.ranges = [NSMutableArray array];
        self.readFileHandle = [NSFileHandle fileHandleForReadingAtPath:cacheFilePath];
        self.writeFileHandle = [NSFileHandle fileHandleForWritingAtPath:cacheFilePath];
        
        // sanity check
        NSString *indexStr = [NSString stringWithContentsOfFile:indexFilePath encoding:NSUTF8StringEncoding error:nil];
        NSData *indexData = [indexStr dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *indexDict = [NSJSONSerialization JSONObjectWithData:indexData options:NSJSONReadingAllowFragments | NSJSONReadingMutableContainers error:nil];
        if (NO == [self unserializeIndex:indexDict]) {
            [self truncateFileToLength:0];
        }
        
        [self checkComplete];
    }
    return self;
}

#pragma mark - Private

+ (NSString *)indexFileExtension
{
    return @".idx!";
}

- (BOOL)unserializeIndex:(NSDictionary *)dict
{
    if (NO == [dict isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    
    NSNumber *fileSize = dict[@"size"];
    if (fileSize && [fileSize isKindOfClass:[NSNumber class]]) {
        self.fileLength = [fileSize integerValue];
    }
    
    if (self.fileLength == 0) {
        return NO;
    }
    
    [self.ranges removeAllObjects];
    NSMutableArray *ranges = dict[@"ranges"];
    for (NSString *rangeStr in ranges) {
        NSRange range = NSRangeFromString(rangeStr);
        [self.ranges addObject:[NSValue valueWithRange:range]];
    }
    
    self.responseHeaders = dict[@"responseHeaders"];
    
    return YES;
}

- (NSString *)serializeIndex
{
    NSMutableArray *ranges = [NSMutableArray array];
    
    for (NSValue *range in self.ranges) {
        [ranges addObject:NSStringFromRange([range rangeValue])];
    }
    
    NSMutableDictionary *dict = [@{@"size": @(self.fileLength),
                                  @"ranges": ranges} mutableCopy];
    
    if (self.responseHeaders) {
        dict[@"responseHeaders"] = self.responseHeaders;
    }
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    if (nil == data) {
        return nil;
    }
    
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (BOOL)truncateFileToLength:(NSInteger)length
{
    if (nil == self.writeFileHandle) {
        return NO;
    }
    
    self.fileLength = length;
    @try {
        [self.writeFileHandle truncateFileAtOffset:length];
        unsigned long long end = [self.writeFileHandle seekToEndOfFile];
        if (end != length) {
            return NO;
        }
    } @catch (NSException *exception) {
        return NO;
    }
    
    return YES;
}

- (void)addRange:(NSRange)range
{
    if (range.length == 0 || range.location >= self.fileLength) {
        LLLog(@"[ERR] addRange failed: %@ (file length: %lu)", NSStringFromRange(range), self.fileLength);
        return;
    }
    
    NSInteger index = NSNotFound;
    for (int i = 0; i < self.ranges.count; i++) {
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
    
    [self mergeRanges];
    [self checkComplete];
}

- (void)mergeRanges
{
    for (int i = 0; i < self.ranges.count; i++) {
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

- (void)checkComplete
{
    if (self.ranges.count == 1) {
        NSRange range = [self.ranges[0] rangeValue];
        self.complete = range.location == 0 && range.length == self.fileLength;
    } else {
        self.complete = NO;
    }
#ifdef DEBUG
    if (self.complete) {
        NSLog(@"cache complete!!!");
    }
#endif
}

- (NSRange)cachedRangeForRange:(NSRange)range
{
    NSRange cachedRange = [self cachedRangeContainsPosition:range.location];
    NSRange ret = NSIntersectionRange(cachedRange, range);
    if (ret.length > 0) {
        return ret;
    } else {
        return LLInvalidRange;
    }
}

- (NSRange)cachedRangeContainsPosition:(NSUInteger)position
{
    if (position >= self.fileLength) {
        return LLInvalidRange;
    }
    
    for (int i = 0; i < self.ranges.count; i++) {
        NSRange range = [self.ranges[i] rangeValue];
        if (NSLocationInRange(position, range)) {
            return range;
        }
    }
    
    return LLInvalidRange;
}

- (BOOL)synchronize
{
    NSString *indexStr = [self serializeIndex];
    return [indexStr writeToFile:self.indexFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

#pragma mark - Public

- (BOOL)saveData:(NSData *)data offset:(NSUInteger)offset flags:(LLCacheFileSaveFlags)flags
{
    if (nil == self.writeFileHandle) {
        return NO;
    }
    
    @try {
        [self.writeFileHandle seekToFileOffset:offset];
        [self.writeFileHandle writeData:data];
    } @catch (NSException *exception) {
        return NO;
    }
    
    [self addRange:NSMakeRange(offset, data.length)];
    
    if (flags & LLCacheFileSaveFlagsSync) {
        [self synchronize];
    }
    
    return YES;
}

- (NSData *)readDataWithOffset:(NSUInteger)offset length:(NSUInteger)length
{
    [self seekToPosition:offset];
    NSRange range = [self cachedRangeForRange:NSMakeRange(offset, length)];
    if (NO == LLValidFileRange(range)) {
        return nil;
    }
    
#ifdef DEBUG
    if (length != range.length) {
        NSLog(@"[ERR] read length mismatch: expect %ld, but got %ld", length, range.length);
    }
#endif
    return [self.readFileHandle readDataOfLength:range.length];
}

- (NSData *)dataWithRange:(NSRange)range
{
    if (NO == LLValidFileRange(range)) {
        return nil;
    }
    
    return [self readDataWithOffset:range.location length:range.length];
}

- (NSRange)firstNotCachedRangeFromPosition:(NSUInteger)position
{
    if (position >= self.fileLength) {
        return LLInvalidRange;
    }
    
    NSUInteger start = position;
    for (int i = 0; i < self.ranges.count; i++) {
        NSRange range = [self.ranges[i] rangeValue];
        if (NSLocationInRange(start, range)) {
            start = NSMaxRange(range);
        } else {
            if (start >= NSMaxRange(range)) {
                continue;
            } else {
                return NSMakeRange(start, range.location - start);
            }
        }
    }
    
    if (start < self.fileLength) {
        return NSMakeRange(start, self.fileLength - start);
    }
    
    return LLInvalidRange;
}

- (void)removeCache
{
    [[NSFileManager defaultManager] removeItemAtPath:self.cacheFilePath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:self.indexFilePath error:nil];
}

- (NSUInteger)maxCachedLength
{
    if (self.ranges.count > 0) {
        NSRange range = [[self.ranges lastObject] rangeValue];
        return NSMaxRange(range);
    }
    return 0;
}

- (BOOL)isCompleted
{
    return self.complete;
}

- (BOOL)isEOF
{
    if (self.readOffset + 1 >= self.fileLength) {
        return YES;
    }
    return NO;
}

- (void)seekToPosition:(NSUInteger)position
{
    [self.readFileHandle seekToFileOffset:position];
    self.readOffset = self.readFileHandle.offsetInFile;
}

- (void)seekToEnd
{
    [self.readFileHandle seekToEndOfFile];
    self.readOffset = self.readFileHandle.offsetInFile;
}

- (BOOL)setResponse:(NSHTTPURLResponse *)response
{
    BOOL success = YES;
    if (self.fileLength == 0) {
        success = [self truncateFileToLength:response.ll_contentLength];
    }
    self.responseHeaders = [[response allHeaderFields] copy];
    success = success && [self synchronize];
    
    return success;
}

@end
