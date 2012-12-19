//
//  KxAudioSpectrumView.h
//  kxmovie
//
//  Created by Kolyvan on 19.12.12.
//
//

#import <UIKit/UIKit.h>

@interface KxAudioSpectrumView : UIView

- (void) renderSamples: (float *) samples
             numFrames: (UInt32) numFrames
           numChannels: (UInt32) numChannels;

@end
