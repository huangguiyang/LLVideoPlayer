//
//  LLVideoPlayerDownloadOperation.h
//  Pods
//
//  Created by mario on 2017/7/26.
//
//

#import <Foundation/Foundation.h>
#import "LLVideoPlayerBasicOperation.h"
#import "LLVideoPlayerDownloadFile.h"

@interface LLVideoPlayerDownloadOperation : LLVideoPlayerBasicOperation

- (instancetype)initWithURL:(NSURL *)url downloadFile:(LLVideoPlayerDownloadFile *)downloadFile;

+ (instancetype)operationWithURL:(NSURL *)url downloadFile:(LLVideoPlayerDownloadFile *)downloadFile;

@property (nonatomic, strong, readonly) NSURL *url;
@property (nonatomic, strong) NSError *error;

@end
