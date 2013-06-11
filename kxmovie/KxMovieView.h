//
//  KxMovieView.h
//  kxmovie
//
//  Created by Thiago Alencar on 3/30/13.
//
//

#import <UIKit/UIKit.h>
#import "HudView.h"

@class KxMovieDecoder;

extern NSString * const KxMovieParameterMinBufferedDuration;    // Float
extern NSString * const KxMovieParameterMaxBufferedDuration;    // Float
extern NSString * const KxMovieParameterDisableDeinterlacing;   // BOOL

@interface KxMovieView : UIView<UITableViewDataSource, UITableViewDelegate>
{
    CGRect viewBounds;
}

+ (id) movieViewControllerWithContentPath: (NSString *) path
                               parameters: (NSDictionary *) parameters
withFrame: (CGRect) frameBounds;

@property (readonly) BOOL playing;

- (void) play;
- (void) pause;

- (void) viewDidAppear:(BOOL)animated;
- (void)loadView;
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;
- (void) viewWillDisappear:(BOOL)animated;
- (void) applicationWillResignActive;
-(void) applicationDidEnterBackground;


@end
