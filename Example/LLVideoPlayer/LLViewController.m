//
//  LLViewController.m
//  LLVideoPlayer
//
//  Created by mario on 12/23/2016.
//  Copyright (c) 2016 mario. All rights reserved.
//

#import "LLViewController.h"
#import "LLVideoPlayer.h"
#import "Masonry.h"

#define kTestVideoURL [NSURL URLWithString:@"http://mycdn.seeyouyima.com/news/vod/1b389b8678066924d8f493866d4e84f5.mp4"]

@interface LLViewController () <LLVideoPlayerDelegate>

@property (nonatomic, strong) LLVideoPlayer *player;
@property (nonatomic, strong) UILabel *stateLabel;
@property (nonatomic, strong) UILabel *currentTimeLabel;
@property (nonatomic, strong) UILabel *totalTimeLabel;
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) UISwitch *cacheSwitch;
//@property (nonatomic, strong) LLVideoPlayerCacheLoader *resourceLoader;
//@property (nonatomic, strong) AVURLAsset *asset;

@end

@implementation LLViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [self createPlayer];
    {
        self.cacheSwitch = [UISwitch new];
        [self.view addSubview:self.cacheSwitch];
        self.cacheSwitch.frame = CGRectMake(10, 30, self.cacheSwitch.frame.size.width, self.cacheSwitch.frame.size.height);
        self.cacheSwitch.on = YES;
    }
    
    {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [button setTitle:@"preload" forState:UIControlStateNormal];
        [self.view addSubview:button];
        button.frame = CGRectMake(100, 30, 80, 40);
        [button addTarget:self action:@selector(preloadAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [button setTitle:@"clear" forState:UIControlStateNormal];
        [self.view addSubview:button];
        button.frame = CGRectMake(200, 30, 80, 40);
        [button addTarget:self action:@selector(clearAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    {
        self.stateLabel = [UILabel new];
        self.stateLabel.backgroundColor = [UIColor clearColor];
        self.stateLabel.font = [UIFont systemFontOfSize:14];
        self.stateLabel.textColor = [UIColor redColor];
        [self.view addSubview:self.stateLabel];
        self.stateLabel.frame = CGRectMake(10, 300, 300, 20);
        
        self.stateLabel.text = [LLVideoPlayerHelper playerStateToString:self.player.state];
    }
    
    {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [button setTitle:@"load" forState:UIControlStateNormal];
        [self.view addSubview:button];
        button.frame = CGRectMake(10, 340, 50, 40);
        [button addTarget:self action:@selector(loadAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [button setTitle:@"play" forState:UIControlStateNormal];
        [self.view addSubview:button];
        button.frame = CGRectMake(70, 340, 50, 40);
        [button addTarget:self action:@selector(playAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [button setTitle:@"pause" forState:UIControlStateNormal];
        [self.view addSubview:button];
        button.frame = CGRectMake(130, 340, 50, 40);
        [button addTarget:self action:@selector(pauseAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [button setTitle:@"dismiss" forState:UIControlStateNormal];
        [self.view addSubview:button];
        button.frame = CGRectMake(190, 340, 60, 40);
        [button addTarget:self action:@selector(dismissAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    {
        self.currentTimeLabel = [UILabel new];
        self.currentTimeLabel.backgroundColor = [UIColor clearColor];
        self.currentTimeLabel.font = [UIFont systemFontOfSize:14];
        [self.view addSubview:self.currentTimeLabel];
        self.currentTimeLabel.frame = CGRectMake(10, 400, 60, 30);
        
        self.slider = [[UISlider alloc] init];
        [self.view addSubview:self.slider];
        self.slider.frame = CGRectMake(60, 405, 200, 20);
        [self.slider addTarget:self action:@selector(sliderTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
        
        self.totalTimeLabel = [UILabel new];
        self.totalTimeLabel.backgroundColor = [UIColor clearColor];
        self.totalTimeLabel.font = [UIFont systemFontOfSize:14];
        [self.view addSubview:self.totalTimeLabel];
        self.totalTimeLabel.frame = CGRectMake(270, 400, 60, 30);
        
        self.currentTimeLabel.text = [LLVideoPlayerHelper timeStringFromSecondsValue:0];
        self.totalTimeLabel.text = [LLVideoPlayerHelper timeStringFromSecondsValue:0];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)createPlayer
{
    if (self.player) {
        self.player.delegate = nil;
        [self.player.view removeFromSuperview];
        self.player = nil;
    }
    
    self.player = [[LLVideoPlayer alloc] init];
    [self.view addSubview:self.player.view];
    self.player.view.frame = CGRectMake(10, 80, 300, 200);
    self.player.delegate = self;
    self.player.cacheSupportEnabled = YES;
    LLVideoPlayerCachePolicy *policy = [LLVideoPlayerCachePolicy defaultPolicy];
    policy.enablePreload = YES;
    self.player.cachePolicy = policy;
}

- (void)loadAction:(id)sender
{
    NSLog(@"[PRESS] loadAction");
    self.player.cacheSupportEnabled = self.cacheSwitch.on;
    [self.player loadVideoWithStreamURL:kTestVideoURL];
    //    LLVideoTrack *track = [[LLVideoTrack alloc] initWithStreamURL:url];
    //    track.lastWatchedDuration = @(40);
    //    [self.player loadVideoWithTrack:track];
}

- (void)playAction:(id)sender
{
    [self.player playContent];
}

- (void)pauseAction:(id)sender
{
    [self.player pauseContent];
}

- (void)dismissAction:(id)sender
{
    [self.player dismissContent];
    
    [self createPlayer];
}

- (void)sliderTouchUpInside:(UISlider *)sender
{
    float sec = [self.player.track.totalDuration floatValue] * sender.value;
    
    [self.player pauseContent:YES completionHandler:^{
        [self.player seekToTimeInSecond:sec userAction:YES completionHandler:^(BOOL finished) {
            [self.player playContent];
        }];
    }];
}

- (void)clearAction:(id)sender
{
    [LLVideoPlayerCacheHelper clearAllCache];
    NSLog(@"Claear Cache.");
}

- (void)preloadAction:(id)sender
{
//    [LLVideoPlayerCacheHelper preloadWithURL:kTestVideoURL bytes:1024*20];
    
//    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[kTestVideoURL ll_customSchemeURL] options:nil];
//    self.resourceLoader = [LLVideoPlayerCacheLoader loaderWithURL:kTestVideoURL cachePolicy:nil];
//    [asset.resourceLoader setDelegate:self.resourceLoader queue:dispatch_get_main_queue()];
//    
//    [asset loadValuesAsynchronouslyForKeys:@[@"playable", @"tracks"] completionHandler:^{
//        NSLog(@"AVURLAsset loaded. [OK]");
//    }];
//    
//    self.asset = asset;
}

#pragma mark - LLVideoPlayerDelegate

#pragma mark - State Changed
- (BOOL)shouldVideoPlayer:(LLVideoPlayer *)videoPlayer changeStateTo:(LLVideoPlayerState)state
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    return YES;
}

- (void)videoPlayer:(LLVideoPlayer *)videoPlayer willChangeStateTo:(LLVideoPlayerState)state
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

- (void)videoPlayer:(LLVideoPlayer *)videoPlayer didChangeStateFrom:(LLVideoPlayerState)state
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    self.stateLabel.text = [LLVideoPlayerHelper playerStateToString:self.player.state];
}

#pragma mark - Play Control
- (BOOL)shouldVideoPlayer:(LLVideoPlayer *)videoPlayer startVideo:(LLVideoTrack *)track
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    return YES;
}

- (void)videoPlayer:(LLVideoPlayer *)videoPlayer willStartVideo:(LLVideoTrack *)track
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

- (void)videoPlayer:(LLVideoPlayer *)videoPlayer didStartVideo:(LLVideoTrack *)track
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    self.totalTimeLabel.text = [LLVideoPlayerHelper timeStringFromSecondsValue:[track.totalDuration floatValue]];
}

- (void)videoPlayer:(LLVideoPlayer *)videoPlayer didPlayFrame:(LLVideoTrack *)track time:(NSTimeInterval)time
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
    self.currentTimeLabel.text = [LLVideoPlayerHelper timeStringFromSecondsValue:time];
    self.totalTimeLabel.text = [LLVideoPlayerHelper timeStringFromSecondsValue:[track.totalDuration floatValue]];
    self.slider.value = time / [track.totalDuration doubleValue];
}

- (void)videoPlayer:(LLVideoPlayer *)videoPlayer loadedTimeRanges:(NSArray<NSValue *> *)ranges track:(LLVideoTrack *)track
{
    if (track.isCacheComplete) {
        NSLog(@"::Cache Complete!!!");
    }
}

- (void)videoPlayer:(LLVideoPlayer *)videoPlayer didPlayToEnd:(LLVideoTrack *)track
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

#pragma mark - Error
- (void)videoPlayer:(LLVideoPlayer *)videoPlayer didFailWithError:(NSError *)error track:(LLVideoTrack *)track
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

@end
