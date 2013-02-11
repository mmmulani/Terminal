//
//  MMCommandTextField.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/10/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMCommandTextField.h"
#import "MMAppDelegate.h"

@implementation MMCommandTextField

- (void)keyDown:(NSEvent *)theEvent;
{
    MMAppDelegate *appDelegate = (MMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [appDelegate handleTerminalInput:[theEvent characters]];
}

- (BOOL)shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString;
{
    return NO;
}

@end
