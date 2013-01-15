//
//  ViewController.m
//  kxmovieapp
//
//  Created by Kolyvan on 11.10.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxmovie
//  this file is part of KxMovie
//  KxMovie is licenced under the LGPL v3, see lgpl-3.0.txt

#import "KxMovieViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import "KxMovieDecoder.h"
#import "KxAudioManager.h"
#import "KxMovieGLView.h"

const int kFirstFrameTsNotSet = -1;

////////////////////////////////////////////////////////////////////////////////

static NSString * formatTimeInterval(CGFloat seconds, BOOL isLeft)
{
    NSInteger s = seconds;
    NSInteger m = s / 60;
    NSInteger h = m / 60;
    
    s = s % 60;
    m = m % 60;
    
    return [NSString stringWithFormat:@"%@%d:%0.2d:%0.2d", isLeft ? @"-" : @"", h,m,s];
}

////////////////////////////////////////////////////////////////////////////////

@interface HudView : UIView
@end

@implementation HudView

- (void)layoutSubviews
{
    NSArray * layers = self.layer.sublayers;
    if (layers.count > 0) {        
        CALayer *layer = layers[0];
        layer.frame = self.bounds;
    }
}
@end

////////////////////////////////////////////////////////////////////////////////

enum {

    KxMovieInfoSectionGeneral,
    KxMovieInfoSectionVideo,
    KxMovieInfoSectionAudio,
    KxMovieInfoSectionMetadata,    
    KxMovieInfoSectionCount,
};

enum {

    KxMovieInfoGeneralFormat,
    KxMovieInfoGeneralBitrate,
    KxMovieInfoGeneralCount,
};

////////////////////////////////////////////////////////////////////////////////

static NSMutableDictionary * gHistory;

#define DEFAULT_DECODE_DURATION   0.1
#define NETWORK_BUFFERED_DURATION 2.0

@interface KxMovieViewController () {

    KxMovieDecoder      *_decoder;    
    dispatch_queue_t    _dispatchQueue;
    NSMutableArray      *_videoFrames;
    NSMutableArray      *_audioFrames;
    NSData              *_currentAudioFrame;
    NSUInteger          _currentAudioFramePos;
    CGFloat             _moviePosition;
    CGFloat             _firstFrameTs;
    BOOL                _disableUpdateHUD;
    NSInteger           _scheduledDecode;
    NSLock              *_scheduledLock;
    NSTimeInterval      _startTime;
    BOOL                _fullscreen;
    BOOL                _hiddenHUD;
    BOOL                _fitMode;
    BOOL                _infoMode;
    BOOL                _restoreIdleTimer;

    KxMovieGLView       *_glView;
    UIImageView         *_imageView;
    HudView             *_topHUD;
    UIView              *_bottomHUD;
    UISlider            *_progressSlider;
    MPVolumeView        *_volumeSlider;
    UIButton            *_playButton;
    UIButton            *_rewindButton;
    UIButton            *_forwardButton;
    UIButton            *_doneButton;
    UILabel             *_progressLabel;
    UILabel             *_leftLabel;
    UIButton            *_infoButton;
    UITableView         *_tableView;
    UIActivityIndicatorView *_activityIndicatorView;
    
    UITapGestureRecognizer *_tapGestureRecognizer;
    UITapGestureRecognizer *_doubleTapGestureRecognizer;
    UIPanGestureRecognizer *_panGestureRecognizer;
        
#ifdef DEBUG
    UILabel             *_messageLabel;
#endif

    CGFloat             _decodeDuration;
    CGFloat             _bufferedDuration;
    CGFloat             _minBufferedDuration;
}

@property (readwrite) BOOL playing;
@property (readonly) CGFloat actualMoviePosition;
@end

@implementation KxMovieViewController

+ (void)initialize
{
    if (!gHistory)
        gHistory = [NSMutableDictionary dictionary];
}

+ (id) movieViewControllerWithContentPath: (NSString *) path
{
    id<KxAudioManager> audioManager = [KxAudioManager audioManager];
    [audioManager activateAudioSession];    
    return [[KxMovieViewController alloc] initWithContentPath: path];
}

- (id) initWithContentPath: (NSString *) path
{
    NSAssert(path.length > 0, @"empty path");
    
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        
        _moviePosition = 0;
        _startTime = -1;
        _firstFrameTs = kFirstFrameTsNotSet;
        self.wantsFullScreenLayout = YES;
        
        __weak KxMovieViewController *weakSelf = self;
        
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
    
            NSError *error;
            KxMovieDecoder *decoder;
            decoder = [KxMovieDecoder movieDecoderWithContentPath:path error:&error];
            
            NSLog(@"movie loaded");
            
            __strong KxMovieViewController *strongSelf = weakSelf;
            if (strongSelf) {
                
                dispatch_sync(dispatch_get_main_queue(), ^{
                    
                    [strongSelf setMovieDecoder:decoder withError:error];                    
                });
            }
        });
    }
    return self;
}

- (void) dealloc
{
    // NSLog(@"%@ dealloc", self);
    
    [self pause];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (_dispatchQueue) {
        dispatch_release(_dispatchQueue);
        _dispatchQueue = NULL;
    }
}

- (void)loadView
{
    // NSLog(@"loadView");
    
    CGRect bounds = [[UIScreen mainScreen] applicationFrame];
    
    self.view = [[UIView alloc] initWithFrame:bounds];
    self.view.backgroundColor = [UIColor blackColor];
    
    _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle: UIActivityIndicatorViewStyleWhiteLarge];
    _activityIndicatorView.center = self.view.center;
    _activityIndicatorView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    
    [self.view addSubview:_activityIndicatorView];
    
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;
    
#ifdef DEBUG
    _messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(20,40,width-40,40)];
    _messageLabel.backgroundColor = [UIColor clearColor];
    _messageLabel.textColor = [UIColor redColor];
    _messageLabel.font = [UIFont systemFontOfSize:14];
    _messageLabel.numberOfLines = 2;
    _messageLabel.textAlignment = NSTextAlignmentCenter;
    _messageLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:_messageLabel];
#endif
    
    _topHUD      = [[HudView alloc] initWithFrame:CGRectMake(0,0,0,0)];
    _bottomHUD   = [[UIView alloc] initWithFrame:CGRectMake(0,0,0,0)];
    
    _topHUD.opaque = NO;
    _bottomHUD.opaque = NO;
    
    _topHUD.frame = CGRectMake(0,0,width,30);
    _bottomHUD.frame = CGRectMake(30,height-(75+15),width-(30*2),75);
    
    _topHUD.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _bottomHUD.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin;
    
    [self.view addSubview:_topHUD];
    [self.view addSubview:_bottomHUD];
    
    // top hud
    
    _doneButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _doneButton.frame = CGRectMake(0,4,50,24);
    _doneButton.backgroundColor = [UIColor clearColor];
    [_doneButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_doneButton setTitle:NSLocalizedString(@"Done", nil) forState:UIControlStateNormal];
    _doneButton.titleLabel.font = [UIFont systemFontOfSize:12];
    _doneButton.showsTouchWhenHighlighted = YES;
    [_doneButton addTarget:self action:@selector(doneDidTouch:) forControlEvents:UIControlEventTouchUpInside];
    
    _progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(48,5,45,20)];
    _progressLabel.backgroundColor = [UIColor clearColor];
    _progressLabel.opaque = NO;
    _progressLabel.adjustsFontSizeToFitWidth = NO;
    _progressLabel.textAlignment = UITextAlignmentRight;
    _progressLabel.textColor = [UIColor whiteColor];
    _progressLabel.text = @"0:00:00";
    _progressLabel.font = [UIFont systemFontOfSize:12];
    
    _progressSlider = [[UISlider alloc] initWithFrame:CGRectMake(95,4,width-175,20)];
    _progressSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _progressSlider.continuous = NO;
    _progressSlider.value = 0;
    [_progressSlider addTarget:self
                        action:@selector(progressDidChange:)
              forControlEvents:UIControlEventValueChanged];
    [_progressSlider setThumbImage:[UIImage imageNamed:@"kxmovie.bundle/sliderthumb"]
                          forState:UIControlStateNormal];
    
    _leftLabel = [[UILabel alloc] initWithFrame:CGRectMake(width-78,5,50,20)];
    _leftLabel.backgroundColor = [UIColor clearColor];
    _leftLabel.opaque = NO;
    _leftLabel.adjustsFontSizeToFitWidth = NO;
    _leftLabel.textAlignment = UITextAlignmentLeft;
    _leftLabel.textColor = [UIColor whiteColor];
    _leftLabel.text = @"-99:59:59";
    _leftLabel.font = [UIFont systemFontOfSize:12];
    _leftLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    
    _infoButton = [UIButton buttonWithType:UIButtonTypeInfoDark];
    _infoButton.frame = CGRectMake(width-25,5,20,20);
    _infoButton.showsTouchWhenHighlighted = YES;
    _infoButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_infoButton addTarget:self action:@selector(infoDidTouch:) forControlEvents:UIControlEventTouchUpInside];
    
    [_topHUD addSubview:_doneButton];
    [_topHUD addSubview:_progressLabel];
    [_topHUD addSubview:_progressSlider];
    [_topHUD addSubview:_leftLabel];
    [_topHUD addSubview:_infoButton];
    
    // bottom hud
    
    width = _bottomHUD.bounds.size.width;
    
    _rewindButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _rewindButton.frame = CGRectMake(width * 0.5 - 65, 5, 40, 40);
    _rewindButton.backgroundColor = [UIColor clearColor];
    _rewindButton.showsTouchWhenHighlighted = YES;
    [_rewindButton setImage:[UIImage imageNamed:@"kxmovie.bundle/playback_rew"] forState:UIControlStateNormal];
    [_rewindButton addTarget:self action:@selector(rewindDidTouch:) forControlEvents:UIControlEventTouchUpInside];
    
    _playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _playButton.frame = CGRectMake(width * 0.5 - 20, 5, 40, 40);
    _playButton.backgroundColor = [UIColor clearColor];
    _playButton.showsTouchWhenHighlighted = YES;
    [_playButton setImage:[UIImage imageNamed:@"kxmovie.bundle/playback_play"] forState:UIControlStateNormal];
    [_playButton addTarget:self action:@selector(playDidTouch:) forControlEvents:UIControlEventTouchUpInside];
    
    _forwardButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _forwardButton.frame = CGRectMake(width * 0.5 + 25, 5, 40, 40);
    _forwardButton.backgroundColor = [UIColor clearColor];
    _forwardButton.showsTouchWhenHighlighted = YES;
    [_forwardButton setImage:[UIImage imageNamed:@"kxmovie.bundle/playback_ff"] forState:UIControlStateNormal];
    [_forwardButton addTarget:self action:@selector(forwardDidTouch:) forControlEvents:UIControlEventTouchUpInside];
    
    _volumeSlider = [[MPVolumeView alloc] initWithFrame:CGRectMake(5, 50, width-(5 * 2), 20)];
    _volumeSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _volumeSlider.showsRouteButton = NO;
    _volumeSlider.showsVolumeSlider = YES;
    
    [_bottomHUD addSubview:_rewindButton];
    [_bottomHUD addSubview:_playButton];
    [_bottomHUD addSubview:_forwardButton];
    [_bottomHUD addSubview:_volumeSlider];
    
    // gradients
    
    CAGradientLayer *gradient;
    
    gradient = [CAGradientLayer layer];
    gradient.frame = _bottomHUD.bounds;
    gradient.cornerRadius = 5;
    gradient.masksToBounds = YES;
    gradient.borderColor = [UIColor darkGrayColor].CGColor;
    gradient.borderWidth = 1.0f;
    gradient.colors = [NSArray arrayWithObjects:
                       (id)[[UIColor whiteColor] colorWithAlphaComponent:0.4].CGColor,
                       (id)[[UIColor lightGrayColor] colorWithAlphaComponent:0.4].CGColor,
                       (id)[[UIColor darkGrayColor] colorWithAlphaComponent:0.4].CGColor,
                       (id)[[UIColor blackColor] colorWithAlphaComponent:0.4].CGColor,
                       nil];
    gradient.locations = [NSArray arrayWithObjects:
                          [NSNumber numberWithFloat:0.0f],
                          [NSNumber numberWithFloat:0.1f],
                          [NSNumber numberWithFloat:0.5],
                          [NSNumber numberWithFloat:0.9],
                          nil];
    [_bottomHUD.layer insertSublayer:gradient atIndex:0];
    
    
    gradient = [CAGradientLayer layer];
    gradient.frame = _topHUD.bounds;
    gradient.colors = [NSArray arrayWithObjects:
                       (id)[[UIColor lightGrayColor] colorWithAlphaComponent:0.7].CGColor,
                       (id)[[UIColor darkGrayColor] colorWithAlphaComponent:0.7].CGColor,
                       nil];
    gradient.locations = [NSArray arrayWithObjects:
                          [NSNumber numberWithFloat:0.0f],
                          [NSNumber numberWithFloat:0.5],
                          nil];
    [_topHUD.layer insertSublayer:gradient atIndex:0];
    
    if (_decoder) {
        
        [self setupPresentView];
        
    } else {
        
        _bottomHUD.hidden = YES;
        _progressLabel.hidden = YES;
        _progressSlider.hidden = YES;
        _leftLabel.hidden = YES;
        _infoButton.hidden = YES;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // [self setupUserInteraction];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];    
}

- (void) viewDidAppear:(BOOL)animated
{
    // NSLog(@"viewDidAppear");
    
    [super viewDidAppear:animated];
    
    if (self.presentingViewController)
        [self fullscreenMode:YES];
    
    if (_infoMode)
        [self showInfoView:NO animated:NO];
    
    [self showHUD: YES];
    
    if (_decoder) {
        
        [self restorePlay];
        
    } else {

        [_activityIndicatorView startAnimating];
    }
   
        
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:[UIApplication sharedApplication]];
}

- (void) viewWillDisappear:(BOOL)animated
{    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super viewWillDisappear:animated];
    
    [_activityIndicatorView stopAnimating];
    
    if (_decoder) {
        
        [self pause];
        
        if (_moviePosition == 0 || _decoder.isEOF)
            [gHistory removeObjectForKey:_decoder.path];
        else
            [gHistory setValue:[NSNumber numberWithFloat:_moviePosition]
                        forKey:_decoder.path];
    }
    
    if (_fullscreen)
        [self fullscreenMode:NO];
    
    if (_hiddenHUD)
        [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void) applicationWillResignActive: (NSNotification *)notification
{
    [self showHUD:YES];
    [self pause];
    
    NSLog(@"applicationWillResignActive");    
}

#pragma mark - gesture recognizer

- (void) handleTap: (UITapGestureRecognizer *) sender
{
    if (sender.state == UIGestureRecognizerStateEnded) {
        
        if (sender == _tapGestureRecognizer) {

            [self showHUD: _hiddenHUD];
            
        } else if (sender == _doubleTapGestureRecognizer) {
                
            UIView *frameView = [self frameView];
            
            if (frameView.contentMode == UIViewContentModeScaleAspectFit)
                frameView.contentMode = UIViewContentModeScaleAspectFill;
            else
                frameView.contentMode = UIViewContentModeScaleAspectFit;
            
        }        
    }
}

- (void) handlePan: (UIPanGestureRecognizer *) sender
{
    if (sender.state == UIGestureRecognizerStateEnded) {
        
        const CGPoint vt = [sender velocityInView:self.view];
        const CGPoint pt = [sender translationInView:self.view];
        const CGFloat sp = MAX(0.1, log10(fabsf(vt.x)) - 1.0);
        const CGFloat sc = fabsf(pt.x) * 0.33 * sp;
        if (sc > 10) {
            
            const CGFloat ff = pt.x > 0 ? 1.0 : -1.0;            
            [self setMoviePosition: _moviePosition + ff * MIN(sc, 600.0)];
        }
        //NSLog(@"pan %.2f %.2f %.2f sec", pt.x, vt.x, sc);
    }
}

#pragma mark - public

-(void) play
{
    if (self.playing)
        return;
    
    if (!_decoder.validVideo &&
        !_decoder.validAudio) {
        
        return;
    }
        
    self.playing = YES;
    _startTime = -1;
    _disableUpdateHUD = NO;
    
    [self decodeFrames];
    [self scheduleDecodeFrames];
    [self updatePlayButton];
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self tick];
    });
        
    NSLog(@"movie play");    
}

- (void) pause
{
    if (!self.playing)
        return;
        
    self.playing = NO;
   // [_decoder pause];
    [self enableAudio:NO];
    [self updatePlayButton];
    NSLog(@"movie pause");
}

- (void) setMoviePosition: (CGFloat) position
{
    BOOL playMode = self.playing;
    
    self.playing = NO;
    _disableUpdateHUD = YES;
    [self enableAudio:NO];
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){

        [self updatePosition:position playMode:playMode];
    });
    
    /*
    [self->isa cancelPreviousPerformRequestsWithTarget:self
                                              selector:@selector(updatePosition:)
                                                object:nil];
     
    
    [self performSelector:@selector(updatePosition:)
               withObject:[NSNumber numberWithFloat:position]
               afterDelay:0.1];
   */
}

#pragma mark - actions

- (void) doneDidTouch: (id) sender
{
    if (self.presentingViewController || !self.navigationController)
        [self dismissViewControllerAnimated:YES completion:nil];
    else
        [self.navigationController popViewControllerAnimated:YES];
}

- (void) infoDidTouch: (id) sender
{
    [self showInfoView: !_infoMode animated:YES];
}

- (void) playDidTouch: (id) sender
{
    if (self.playing)
        [self pause];
    else
        [self play];
}

- (void) forwardDidTouch: (id) sender
{
    [self setMoviePosition: _moviePosition + 10];
}

- (void) rewindDidTouch: (id) sender
{
    [self setMoviePosition: _moviePosition - 10];
}

- (void) progressDidChange: (id) sender
{    
    UISlider *slider = sender;
    [self setMoviePosition:slider.value * _decoder.duration];
}

#pragma mark - private

- (void) setMovieDecoder: (KxMovieDecoder *) decoder
               withError: (NSError *) error
{
    NSLog(@"setMovieDecoder");
    
    if (decoder) {
        
        _decoder        = decoder;
        _dispatchQueue  = dispatch_queue_create("KxMovie", DISPATCH_QUEUE_SERIAL);
        _videoFrames    = [NSMutableArray array];
        _audioFrames    = [NSMutableArray array];
        _scheduledLock  = [[NSLock alloc] init];
        
        _decodeDuration = DEFAULT_DECODE_DURATION;
        _minBufferedDuration = _decoder.isNetwork ? NETWORK_BUFFERED_DURATION : DEFAULT_DECODE_DURATION;
        
        if (!_decoder.validVideo) {
            
            _decodeDuration *= 10.0;
            _minBufferedDuration *= 10.0;
        }
        
        if (self.isViewLoaded) {
            
            [self setupPresentView];
            
            _bottomHUD.hidden       = NO;
            _progressLabel.hidden   = NO;
            _progressSlider.hidden  = NO;
            _leftLabel.hidden       = NO;
            _infoButton.hidden      = NO;
            
            if (_activityIndicatorView.isAnimating) {
                
                [_activityIndicatorView stopAnimating];
                // if (self.view.window)
                [self restorePlay];
            }
        }
        
    } else {
        
         if (self.isViewLoaded && self.view.window) {
        
             [self handleDecoderMovieError: error];
         }
    }
}

- (void) restorePlay
{
    // NSLog(@"restorePlay");
    
    NSNumber *n = [gHistory valueForKey:_decoder.path];
    if (n)
        [self updatePosition:n.floatValue playMode:YES];
    else
        [self play];    
}

- (void) setupPresentView
{
    // NSLog(@"setupPresentView");
    
    CGRect bounds = self.view.bounds;
    
    if (_decoder.validVideo) {
        _glView = [[KxMovieGLView alloc] initWithFrame:bounds decoder:_decoder];
    }
    
    if (!_glView) {
        
        NSLog(@"fallback to use RGB video frame and UIKit");
        [_decoder setupVideoFrameFormat:KxVideoFrameFormatRGB];
        _imageView = [[UIImageView alloc] initWithFrame:bounds];
    }
    
    UIView *frameView = [self frameView];
    frameView.contentMode = UIViewContentModeScaleAspectFit;
    frameView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    
    [self.view insertSubview:frameView atIndex:0];
        
    if (_decoder.validVideo) {
    
        [self setupUserInteraction];
    
    } else {
        
        _imageView.image = [UIImage imageNamed:@"kxmovie.bundle/music_icon.png"];
        _imageView.contentMode = UIViewContentModeCenter;
    }
    
    self.view.backgroundColor = [UIColor clearColor];
}

- (void) setupUserInteraction
{
    UIView * view = [self frameView];
    view.userInteractionEnabled = YES;
    
    _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    _tapGestureRecognizer.numberOfTapsRequired = 1;
    
    _doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    _doubleTapGestureRecognizer.numberOfTapsRequired = 2;
    
    [_tapGestureRecognizer requireGestureRecognizerToFail: _doubleTapGestureRecognizer];
    
    [view addGestureRecognizer:_doubleTapGestureRecognizer];
    [view addGestureRecognizer:_tapGestureRecognizer];
    
    _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    _panGestureRecognizer.enabled = NO;
    
    [view addGestureRecognizer:_panGestureRecognizer];
}

- (UIView *) frameView
{
    return _glView ? _glView : _imageView;
}

- (void) audioCallbackFillData: (float *) outData
                     numFrames: (UInt32) numFrames
                   numChannels: (UInt32) numChannels
{
    //fillSignalF(outData,numFrames,numChannels);
    //return;
        
    @autoreleasepool {
        
        while (numFrames > 0) {
            
            if (!_currentAudioFrame) {
                
                @synchronized(_audioFrames) {
                    
                    NSUInteger count = _audioFrames.count;
                    
                    if (count > 0) {
                        
                        KxAudioFrame *frame = _audioFrames[0];
                        
                        if (_decoder.validVideo) {
                        
                            const CGFloat delta = _moviePosition - frame.position;
                            
                            if (delta < -2.0) {
                                
                                NSLog(@"desync audio (outrun) wait %.4f %.4f", _moviePosition, frame.position);
                                memset(outData, 0, numFrames * numChannels * sizeof(float));
                                break; // silence and exit
                            }
                            
                            [_audioFrames removeObjectAtIndex:0];
                            
                            if (delta > 2.0 && count > 1) {
                                
                                NSLog(@"desync audio (lags) skip %.4f %.4f", _moviePosition, frame.position);
                                continue;
                            }
                            
                        } else {
                            
                            [_audioFrames removeObjectAtIndex:0];
                            _moviePosition = frame.position;
                            _bufferedDuration -= frame.duration;
                        }
                        
                        _currentAudioFramePos = 0;
                        _currentAudioFrame = frame.samples;
                    }
                }
            }
            
            if (_currentAudioFrame) {
                
                const void *bytes = (Byte *)_currentAudioFrame.bytes + _currentAudioFramePos;
                const NSUInteger bytesLeft = (_currentAudioFrame.length - _currentAudioFramePos);
                const NSUInteger frameSizeOf = numChannels * sizeof(float);
                const NSUInteger bytesToCopy = MIN(numFrames * frameSizeOf, bytesLeft);
                const NSUInteger framesToCopy = bytesToCopy / frameSizeOf;
                
                memcpy(outData, bytes, bytesToCopy);
                numFrames -= framesToCopy;
                outData += framesToCopy * numChannels;
                
                if (bytesToCopy < bytesLeft)
                    _currentAudioFramePos += bytesToCopy;
                else
                    _currentAudioFrame = nil;                
                
            } else {
                
                memset(outData, 0, numFrames * numChannels * sizeof(float));
                //NSLog(@"silence audio");
                break;
            }
        }
    }
}

- (void) enableAudio: (BOOL) on
{
    id<KxAudioManager> audioManager = [KxAudioManager audioManager];
            
    if (on && _decoder.validAudio) {
                
        audioManager.outputBlock = ^(float *outData, UInt32 numFrames, UInt32 numChannels) {
            
            [self audioCallbackFillData: outData numFrames:numFrames numChannels:numChannels];
        };
        
        [audioManager play];
        
        NSLog(@"audio device smr: %d fmt: %d chn: %d",
              (int)audioManager.samplingRate,
              (int)audioManager.numBytesPerSample,
              (int)audioManager.numOutputChannels);
        
    } else {
        
        [audioManager pause];
        audioManager.outputBlock = nil;
    }
}

- (void) decodeFrames
{
    NSArray *frames = nil;
    
    if (_decoder.validVideo ||
        _decoder.validAudio) {
        
        @synchronized (_decoder) {
            frames = [_decoder decodeFrames: _decodeDuration];
        }
    }
    
    if (frames.count == 0)
        return;
    
    if (_decoder.validVideo) {
        
        @synchronized(_videoFrames) {
            
            for (KxMovieFrame *frame in frames)
                if (frame.type == KxMovieFrameTypeVideo) {
                    [_videoFrames addObject:frame];
                    _bufferedDuration += frame.duration;
                    if (_firstFrameTs == kFirstFrameTsNotSet) {
                        _firstFrameTs = (int)frame.position;
                    }
                }
        }
    }
    
    if (_decoder.validAudio) {
        
        @synchronized(_audioFrames) {
            
            // for preventing OOM, skip an overplus audio
            
            if (_audioFrames.count < 1024) {
                
                for (KxMovieFrame *frame in frames)
                    if (frame.type == KxMovieFrameTypeAudio) {
                        [_audioFrames addObject:frame];
                        if (!_decoder.validVideo)
                            _bufferedDuration += frame.duration;
                    }
            }
        }
    }    
}

- (void) scheduleDecodeFrames
{    
    BOOL canSchedule = NO;
    
    [_scheduledLock lock];
    if (_scheduledDecode < 1) {
        
        canSchedule = YES;
        ++_scheduledDecode;
    }    
    [_scheduledLock unlock];
    
    if (canSchedule) {
        
        dispatch_async(_dispatchQueue, ^{
            
            if (self.playing)
                [self decodeFrames];
            
            [_scheduledLock lock];
            _scheduledDecode--;
            [_scheduledLock unlock];
        });
    }
}

- (void) tick
{
    if (!self.playing)
        return;
    
    CGFloat interval = [self presentFrame];
    
    const NSUInteger leftFrames =
        (_decoder.validVideo ? _videoFrames.count : 0) +
        (_decoder.validAudio ? _audioFrames.count : 0);
    
    if (0 == leftFrames) {
    
        if (_decoder.isEOF) {
            
            [self pause];
            [self updateHUD];
            return;
        } 
    }
    
    if (_bufferedDuration < _minBufferedDuration) {
        
        [self scheduleDecodeFrames];
    }
    
    NSTimeInterval destTime = _startTime + _moviePosition + interval;
    NSTimeInterval diffTime = destTime - [NSDate timeIntervalSinceReferenceDate];
    diffTime = MAX(diffTime, 0.02);
    //NSLog(@"next tick %f", diffTime);
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, diffTime * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self tick];
    });
        
    [self updateHUD];
}

- (CGFloat) presentFrame
{
    CGFloat interval = 0;
    
    if (_decoder.validVideo) {
        
        KxVideoFrame *frame;
        
        @synchronized(_videoFrames) {
            
            if (_videoFrames.count > 0) {
                
                frame = _videoFrames[0];
                [_videoFrames removeObjectAtIndex:0];
                _bufferedDuration -= frame.duration;
            }
        }
        
        if (frame)
            interval = [self presentVideoFrame:frame];
        
    } else {

        //interval = _bufferedDuration * 0.5;
    }
    
    if (self.playing && _startTime < 0) {
        _startTime = [NSDate timeIntervalSinceReferenceDate] - _moviePosition;
        if (_decoder.validAudio)
            [self enableAudio:YES];
    }
    
    return interval;
}

- (CGFloat) presentVideoFrame: (KxVideoFrame *) frame
{
    if (_glView) {
        
        [_glView render:frame];
        
    } else {
        
        KxVideoFrameRGB *rgbFrame = (KxVideoFrameRGB *)frame;
        
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)(rgbFrame.rgb));
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGImageRef cgImage = CGImageCreate(frame.width,
                                           frame.height,
                                           8,
                                           24,
                                           rgbFrame.linesize,
                                           colorSpace,
                                           kCGBitmapByteOrderDefault,
                                           provider,
                                           NULL,
                                           YES, // NO
                                           kCGRenderingIntentDefault);
        CGColorSpaceRelease(colorSpace);
        CGDataProviderRelease(provider);
        UIImage *image = [UIImage imageWithCGImage:cgImage];
        CGImageRelease(cgImage);
        _imageView.image = image;
        
    }
    
    _moviePosition = frame.position;
        
    return frame.duration;
}

- (void) updatePlayButton
{
    [_playButton setImage:[UIImage imageNamed:self.playing ? @"kxmovie.bundle/playback_pause" : @"kxmovie.bundle/playback_play"]
                 forState:UIControlStateNormal];
}

- (void) updateHUD
{
    if (_disableUpdateHUD)
        return;
    
    CGFloat duration = _decoder.duration;
    if (_progressSlider.state == UIControlStateNormal)
        _progressSlider.value = self.actualMoviePosition / duration;
    _progressLabel.text = formatTimeInterval(self.actualMoviePosition, NO);
    _leftLabel.text = formatTimeInterval(duration - self.actualMoviePosition, YES);
            
#ifdef DEBUG
    _messageLabel.text = [NSString stringWithFormat:@"%d %d %d - %@ %@",
                          _videoFrames.count,
                          _audioFrames.count,
                          _scheduledDecode,
                          formatTimeInterval([NSDate timeIntervalSinceReferenceDate] - _startTime, NO),
                          _decoder.isEOF ? @"- END" : @""];
#endif
    
    
}

- (void) showHUD: (BOOL) show
{
    _hiddenHUD = !show;    
    _panGestureRecognizer.enabled = _hiddenHUD;
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:_hiddenHUD];
    
    [UIView animateWithDuration:0.2
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionNone
                     animations:^{
                         
                         CGFloat alpha = _hiddenHUD ? 0 : 1;
                         _topHUD.alpha = alpha;
                         _bottomHUD.alpha = alpha;
                     }
                     completion:nil];
    
}

- (void) fullscreenMode: (BOOL) on
{
    _fullscreen = on;
    UIApplication *app = [UIApplication sharedApplication];
    [app setStatusBarHidden:on withAnimation:UIStatusBarAnimationNone];
    // if (!self.presentingViewController) {
    //[self.navigationController setNavigationBarHidden:on animated:YES];
    //[self.tabBarController setTabBarHidden:on animated:YES];
    // }
}

- (void) updatePosition: (CGFloat) position
               playMode: (BOOL) playMode
{
    @synchronized(_videoFrames) {
        [_videoFrames removeAllObjects];
    }
    
    @synchronized(_audioFrames) {
        
        [_audioFrames removeAllObjects];
        _currentAudioFrame = nil;
    }
    
    _bufferedDuration = 0;
    
    position = MIN(_decoder.duration - 1, MAX(0, position));
    position += _firstFrameTs;
    
    @synchronized (_decoder) {
        _decoder.position = position;
        _moviePosition = _decoder.position;
    }
    
    if (playMode) {
        
        [self play];
        
    } else {
        
        [self decodeFrames];
        [self presentFrame];
        _disableUpdateHUD = NO;
        [self updateHUD];
    }
    
    NSLog(@"movie.position = %.1f", position);
}

- (void) showInfoView: (BOOL) showInfo animated: (BOOL)animated
{
    if (!_tableView)
        [self createTableView];

    [self pause];
    
    CGSize size = self.view.bounds.size;
    CGFloat Y = _topHUD.bounds.size.height;
    
    if (showInfo) {
        
        _tableView.hidden = NO;
        
        if (animated) {
        
            [UIView animateWithDuration:0.4
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionNone
                             animations:^{
                                 
                                 _tableView.frame = CGRectMake(0,Y,size.width,size.height - Y);
                             }
                             completion:nil];
        } else {
            
            _tableView.frame = CGRectMake(0,Y,size.width,size.height - Y);
        }
    
    } else {
        
        if (animated) {
            
            [UIView animateWithDuration:0.4
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionNone
                             animations:^{
                                 
                                 _tableView.frame = CGRectMake(0,size.height,size.width,size.height - Y);
                                 
                             }
                             completion:^(BOOL f){
                                 
                                 if (f) {
                                     _tableView.hidden = YES;
                                 }
                             }];
        } else {
        
            _tableView.frame = CGRectMake(0,size.height,size.width,size.height - Y);
            _tableView.hidden = YES;
        }
    }
    
    _infoMode = showInfo;    
}

- (void) createTableView
{    
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth |UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.hidden = YES;
    
    CGSize size = self.view.bounds.size;
    CGFloat Y = _topHUD.bounds.size.height;
    _tableView.frame = CGRectMake(0,size.height,size.width,size.height - Y);
    
    [self.view addSubview:_tableView];   
}

- (void) handleDecoderMovieError: (NSError *) error
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failure", nil)
                                                        message:[error description]
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"Ok", nil)
                                              otherButtonTitles:nil];
    
    [alertView show];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return KxMovieInfoSectionCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case KxMovieInfoSectionGeneral:     return NSLocalizedString(@"General", nil);
        case KxMovieInfoSectionMetadata:    return NSLocalizedString(@"Metadata", nil);
        case KxMovieInfoSectionVideo:       return NSLocalizedString(@"Video", nil);
        case KxMovieInfoSectionAudio:       return NSLocalizedString(@"Audio", nil);
    }
    return @"";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case KxMovieInfoSectionGeneral:
            return KxMovieInfoGeneralCount;
            
        case KxMovieInfoSectionMetadata: {
            NSDictionary *d = [_decoder.info valueForKey:@"metadata"];
            return d.count;
        }
            
        case KxMovieInfoSectionVideo: {
            NSArray *a = [_decoder.info valueForKey:@"video"];
            return a.count;
        }
            
        case KxMovieInfoSectionAudio: {
            NSArray *a = [_decoder.info valueForKey:@"audio"];
            return a.count;
        }
            
        default:
            return 0;
    }
}

- (id) mkCell: (NSString *) cellIdentifier
    withStyle: (UITableViewCellStyle) style
{
    UITableViewCell *cell = [_tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:cellIdentifier];
    }
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    
    if (indexPath.section == KxMovieInfoSectionGeneral) {
    
        if (indexPath.row == KxMovieInfoGeneralBitrate) {
            
            int bitrate = [[_decoder.info valueForKey:@"bitrate"] intValue];
            cell = [self mkCell:@"ValueCell" withStyle:UITableViewCellStyleValue1];
            cell.textLabel.text = NSLocalizedString(@"Bitrate", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%d kb/s",bitrate / 1000];
            
        } else if (indexPath.row == KxMovieInfoGeneralFormat) {

            NSString *format = [_decoder.info valueForKey:@"format"];            
            cell = [self mkCell:@"ValueCell" withStyle:UITableViewCellStyleValue1];
            cell.textLabel.text = NSLocalizedString(@"Format", nil);
            cell.detailTextLabel.text = format ? format : @"-";
        }
        
    } else if (indexPath.section == KxMovieInfoSectionMetadata) {
      
        NSDictionary *d = [_decoder.info valueForKey:@"metadata"];
        NSString *key = d.allKeys[indexPath.row];
        cell = [self mkCell:@"ValueCell" withStyle:UITableViewCellStyleValue1];
        cell.textLabel.text = key.capitalizedString;
        cell.detailTextLabel.text = [d valueForKey:key];
        
    } else if (indexPath.section == KxMovieInfoSectionVideo) {
        
        NSArray *a = [_decoder.info valueForKey:@"video"];
        cell = [self mkCell:@"VideoCell" withStyle:UITableViewCellStyleValue1];
        cell.textLabel.text = a[indexPath.row];
        cell.textLabel.font = [UIFont systemFontOfSize:14];
        cell.textLabel.numberOfLines = 2;
        
    } else if (indexPath.section == KxMovieInfoSectionAudio) {
        
        NSArray *a = [_decoder.info valueForKey:@"audio"];
        cell = [self mkCell:@"AudioCell" withStyle:UITableViewCellStyleValue1];
        cell.textLabel.text = a[indexPath.row];
        cell.textLabel.font = [UIFont systemFontOfSize:14];
        cell.textLabel.numberOfLines = 2;
        BOOL selected = _decoder.selectedAudioStream == indexPath.row;
        cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    }
    
     cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == KxMovieInfoSectionAudio) {
        
        NSInteger selected = _decoder.selectedAudioStream;
        
        if (selected != indexPath.row) {

            _decoder.selectedAudioStream = indexPath.row;
            NSInteger now = _decoder.selectedAudioStream;
            
            if (now == indexPath.row) {
            
                UITableViewCell *cell;
                
                cell = [_tableView cellForRowAtIndexPath:indexPath];
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
                
                indexPath = [NSIndexPath indexPathForRow:selected inSection:KxMovieInfoSectionAudio];
                cell = [_tableView cellForRowAtIndexPath:indexPath];
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
    }
}

-(CGFloat)actualMoviePosition {
    return _moviePosition - _firstFrameTs;
}

@end

