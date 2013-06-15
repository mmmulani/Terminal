//
//  MMFirstRunWindowController.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/30/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMFirstRunWindowController.h"
#import "MMAppDelegate.h"

@implementation MMFirstRunWindowController

- (id)init;
{
    self = [self initWithWindowNibName:@"MMFirstRunWindowController"];
    if (!self) {
        return nil;
    }

    return self;
}

- (void)windowDidLoad;
{
    [super windowDidLoad];

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    BOOL restoresWindowsUponReopening = [userDefaults boolForKey:@"NSQuitAlwaysKeepsWindows"];
    if (!restoresWindowsUponReopening) {
        [self.window.contentView addSubview:self.restoreWindowsWarning];
        NSRect newFrame = self.restoreWindowsWarning.frame;
        newFrame.origin = NSMakePoint(20, -20);
        self.restoreWindowsWarning.frame = newFrame;

        CGFloat warningHeight = self.restoreWindowsWarning.frame.size.height;
        [self.window setFrame:NSMakeRect(self.window.frame.origin.x, self.window.frame.origin.y, self.window.frame.size.width, self.window.frame.size.height + warningHeight + 20) display:YES];
    }
}

- (IBAction)donePressed:(id)sender;
{
    [self close];

    [(MMAppDelegate *)[NSApp delegate] showMainApplicationWindow];
}

@end
