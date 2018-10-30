//
//  LLVideoPlayerOperationDelegate.h
//  Pods
//
//  Created by mario on 2018/10/26.
//

#ifndef LLVideoPlayerOperationDelegate_h
#define LLVideoPlayerOperationDelegate_h

#import <Foundation/Foundation.h>

@protocol LLVideoPlayerOperationDelegate <NSObject>

@optional

- (void)operation:(NSOperation *)operation didCompleteWithError:(NSError *)error;
- (void)operation:(NSOperation *)operation didReceiveData:(NSData *)data;
- (void)operation:(NSOperation *)operation didReceiveResponse:(NSURLResponse *)response;

@end

#endif /* LLVideoPlayerOperationDelegate_h */
