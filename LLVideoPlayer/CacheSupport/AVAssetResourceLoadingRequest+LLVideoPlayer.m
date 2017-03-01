//
//  AVAssetResourceLoadingRequest+LLVideoPlayer.m
//  Pods
//
//  Created by mario on 2017/2/23.
//
//

#import "AVAssetResourceLoadingRequest+LLVideoPlayer.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "NSHTTPURLResponse+LLVideoPlayer.h"

@implementation AVAssetResourceLoadingRequest (LLVideoPlayer)

- (void)ll_fillContentInfomation:(NSHTTPURLResponse *)response
{
    if (nil == response) {
        return;
    }
    
    self.response = response;
    
    if (nil == self.contentInformationRequest) {
        return;
    }
    
    NSString *mimeType = [response MIMEType];
    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(mimeType), NULL);
    self.contentInformationRequest.byteRangeAccessSupported = [response ll_supportRange];
    self.contentInformationRequest.contentType = CFBridgingRelease(contentType);
    self.contentInformationRequest.contentLength = [response ll_contentLength];
}

@end
