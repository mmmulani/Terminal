//
//  MMTerminalWindowController.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/18/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMTerminalWindowController.h"

@interface MMTerminalWindowController ()

@end

@implementation MMTerminalWindowController

- (id)init;
{
    self = [self initWithWindowNibName:@"MMTerminalWindow"];

    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [self.consoleText setNextResponder:self.window];

    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

@end
