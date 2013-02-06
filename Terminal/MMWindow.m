//
//  MMWindow.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/6/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMWindow.h"
#import "MMAppDelegate.h"

@implementation MMWindow

- (void)keyDown:(NSEvent *)theEvent;
{
    MMAppDelegate *appDelegate = (MMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [appDelegate handleTerminalInput:[theEvent characters]];
}

@end
