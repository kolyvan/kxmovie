//
//  HudView.m
//  kxmovie
//
//  Created by Thiago F. Alencar on 5/22/13.
//
//

#import "HudView.h"

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
