//
//  MMTextView.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/8/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMTextView.h"

@implementation MMTextView

- (void)keyDown:(NSEvent *)theEvent;
{
    [self.delegate handleKeyPress:theEvent];
}

- (void)paste:(id)sender;
{
    NSString *pasteboardString = [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString];
    [self.delegate handleInput:pasteboardString];
}

- (BOOL)shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString;
{
    return NO;
}

- (BOOL)becomeFirstResponder;
{
    [self.window addObserver:self forKeyPath:@"firstResponder" options:NSKeyValueObservingOptionInitial context:NULL];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateFocusRing) name:NSWindowDidResignKeyNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateFocusRing) name:NSWindowDidBecomeKeyNotification object:nil];

    return [super becomeFirstResponder];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context;
{
    if ([keyPath isEqualToString:@"firstResponder"]) {
        [self updateFocusRing];

        if (![self.window.firstResponder isEqual:self]) {
            [self.window removeObserver:self forKeyPath:@"firstResponder"];
            [[NSNotificationCenter defaultCenter] removeObserver:self];
        }
    }
}

- (void)updateFocusRing;
{
    [self.enclosingScrollView setKeyboardFocusRingNeedsDisplayInRect:self.enclosingScrollView.bounds];
}

@end
