//
//  ESGLView.h
//  kxmovie
//
//  Created by Kolyvan on 22.10.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxmovie
//  this file is part of KxMovie
//  KxMovie is licenced under the LGPL v3, see lgpl-3.0.txt

#import <UIKit/UIKit.h>

@class KxVideoFrame;
@class KxMovieDecoder;

@interface KxMovieGLView : UIView

- (id) initWithFrame:(CGRect)frame
             decoder: (KxMovieDecoder *) decoder;

- (void) render: (KxVideoFrame *) frame;

@end
