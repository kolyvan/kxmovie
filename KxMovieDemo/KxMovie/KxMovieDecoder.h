//
//  KxMovieDecoder.h
//  kxmovie
//
//  Created by Kolyvan on 15.10.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxmovie
//  this file is part of KxMovie
//  KxMovie is licenced under the LGPL v3, see lgpl-3.0.txt

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

extern NSString * kxmovieErrorDomain;

typedef enum {
    
    kxMovieErrorNone,
    kxMovieErrorOpenFile,
    kxMovieErrorStreamInfoNotFound,
    kxMovieErrorStreamNotFound,
    kxMovieErrorCodecNotFound,
    kxMovieErrorOpenCodec,
    kxMovieErrorAllocateFrame,
    kxMovieErroSetupScaler,
    kxMovieErroReSampler,
    kxMovieErroUnsupported,
    
} kxMovieError;

typedef enum {
    
    KxMovieFrameTypeAudio,
    KxMovieFrameTypeVideo,
    KxMovieFrameTypeArtwork,
    KxMovieFrameTypeSubtitle,
    
} KxMovieFrameType;

typedef enum {
        
    KxVideoFrameFormatRGB,
    KxVideoFrameFormatYUV,
    
} KxVideoFrameFormat;

@interface KxMovieFrame : NSObject
@property (readonly, nonatomic) KxMovieFrameType type;
@property (readonly, nonatomic) CGFloat position;
@property (readonly, nonatomic) CGFloat duration;
@end

@interface KxAudioFrame : KxMovieFrame
@property (readonly, nonatomic, strong) NSData *samples;
@end

@interface KxVideoFrame : KxMovieFrame
@property (readonly, nonatomic) KxVideoFrameFormat format;
@property (readonly, nonatomic) NSUInteger width;
@property (readonly, nonatomic) NSUInteger height;
@end

@interface KxVideoFrameRGB : KxVideoFrame
@property (readonly, nonatomic) NSUInteger linesize;
@property (readonly, nonatomic, strong) NSData *rgb;
- (UIImage *) asImage;
@end

@interface KxVideoFrameYUV : KxVideoFrame
@property (readonly, nonatomic, strong) NSData *luma;
@property (readonly, nonatomic, strong) NSData *chromaB;
@property (readonly, nonatomic, strong) NSData *chromaR;
@end

@interface KxArtworkFrame : KxMovieFrame
@property (readonly, nonatomic, strong) NSData *picture;
- (UIImage *) asImage;
@end

@interface KxSubtitleFrame : KxMovieFrame
@property (readonly, nonatomic, strong) NSString *text;
@end

typedef BOOL(^KxMovieDecoderInterruptCallback)();

@interface KxMovieDecoder : NSObject

@property (readonly, nonatomic, strong) NSString *path;
@property (readonly, nonatomic) BOOL isEOF;
@property (readwrite,nonatomic) CGFloat position;
@property (readonly, nonatomic) CGFloat duration;
@property (readonly, nonatomic) CGFloat fps;
@property (readonly, nonatomic) CGFloat sampleRate;
@property (readonly, nonatomic) NSUInteger frameWidth;
@property (readonly, nonatomic) NSUInteger frameHeight;
@property (readonly, nonatomic) NSUInteger audioStreamsCount;
@property (readwrite,nonatomic) NSInteger selectedAudioStream;
@property (readonly, nonatomic) NSUInteger subtitleStreamsCount;
@property (readwrite,nonatomic) NSInteger selectedSubtitleStream;
@property (readonly, nonatomic) BOOL validVideo;
@property (readonly, nonatomic) BOOL validAudio;
@property (readonly, nonatomic) BOOL validSubtitles;
@property (readonly, nonatomic, strong) NSDictionary *info;
@property (readonly, nonatomic, strong) NSString *videoStreamFormatName;
@property (readonly, nonatomic) BOOL isNetwork;
@property (readonly, nonatomic) CGFloat startTime;
@property (readwrite, nonatomic) BOOL disableDeinterlacing;
@property (readwrite, nonatomic, strong) KxMovieDecoderInterruptCallback interruptCallback;

+ (id) movieDecoderWithContentPath: (NSString *) path
                             error: (NSError **) perror;

- (BOOL) openFile: (NSString *) path
            error: (NSError **) perror;

-(void) closeFile;

- (BOOL) setupVideoFrameFormat: (KxVideoFrameFormat) format;

- (NSArray *) decodeFrames: (CGFloat) minDuration;

@end

@interface KxMovieSubtitleASSParser : NSObject

+ (NSArray *) parseEvents: (NSString *) events;
+ (NSArray *) parseDialogue: (NSString *) dialogue
                  numFields: (NSUInteger) numFields;
+ (NSString *) removeCommandsFromEventText: (NSString *) text;

@end