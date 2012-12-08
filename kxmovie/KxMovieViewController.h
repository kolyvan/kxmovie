//
//  ViewController.h
//  kxmovieapp
//
//  Created by Kolyvan on 11.10.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxmovie
//  this file is part of KxMovie
//  KxMovie is licenced under the LGPL v3, see lgpl-3.0.txt

#import <UIKit/UIKit.h>

@class KxMovieDecoder;


@interface KxMovieViewController : UIViewController<UITableViewDataSource, UITableViewDelegate>

+ (id) movieViewControllerWithContentPath: (NSString *) path;

@property (readonly) BOOL playing;
@property (readwrite) BOOL isFullscreen;
@property (readwrite) BOOL hasProcessbar;
@property (nonatomic, retain) NSString *name;

- (void) play;
- (void) pause;
- (void) fullscreenMode: (BOOL) on;

@end
