//
//  MMOutputScrollView.m
//  Terminal
//
//  Created by Mehdi Mulani on 6/16/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMOutputScrollView.h"

@implementation MMOutputScrollView

- (void)drawRect:(NSRect)rect;
{
    [super drawRect:rect];

    if (self.window.firstResponder == self.documentView) {
        NSSetFocusRingStyle(NSFocusRingOnly);
        NSRectFill(self.bounds);
    }
}

@end
