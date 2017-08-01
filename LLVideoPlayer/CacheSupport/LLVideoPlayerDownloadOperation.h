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

- (instancetype)initWithURL:(NSURL *)url
                      range:(NSRange)range
               downloadFile:(LLVideoPlayerDownloadFile *)downloadFile;

+ (instancetype)operationWithURL:(NSURL *)url
                           range:(NSRange)range
                    downloadFile:(LLVideoPlayerDownloadFile *)downloadFile;

@property (nonatomic, strong, readonly) NSURL *url;

@end
