//
//  MMAppDelegate.h
//  Terminal
//
//  Created by Mehdi Mulani on 1/29/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MMTerminalWindowController.h"

@interface MMAppDelegate : NSObject <NSApplicationDelegate, NSTextFieldDelegate>

@property int fd;
@property BOOL running;
@property (strong) NSConnection *terminalAppConnection;

@property (strong) MMTerminalWindowController *terminalWindow;

- (void)handleTerminalInput:(NSString *)input;
- (void)runCommand:(NSString *)command;

@end
