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

@end
