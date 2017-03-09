//
//  AVAssetResourceLoadingRequest+LLVideoPlayer.h
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import <AVFoundation/AVFoundation.h>

@interface AVAssetResourceLoadingRequest (LLVideoPlayer)

- (void)ll_fillContentInformation:(NSHTTPURLResponse *)response;

@end
