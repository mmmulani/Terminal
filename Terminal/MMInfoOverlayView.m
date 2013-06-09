//
//  MMInfoOverlayView.m
//  Terminal
//
//  Created by Mehdi Mulani on 6/9/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMInfoOverlayView.h"

@implementation MMInfoOverlayView

- (id)initWithFrame:(NSRect)frame;
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    return self;
}

- (void)drawRect:(NSRect)dirtyRect;
{
    NSColor *backgroundColor = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:0.4];
    [backgroundColor set];
    [NSBezierPath fillRect:self.bounds];

    NSFont *font = [[NSFontManager sharedFontManager] convertFont:[NSFont systemFontOfSize:22.0] toHaveTrait:NSBoldFontMask];
    NSDictionary *attributes =
    @{
      NSFontAttributeName: font,
      NSForegroundColorAttributeName: [NSColor whiteColor],
    };
    NSSize size = [self.displayText sizeWithAttributes:attributes];
    [self.displayText drawAtPoint:NSMakePoint((self.bounds.size.width - size.width) / 2, (self.bounds.size.height - size.height) / 2) withAttributes:attributes];
}

@end
