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

@property (retain) IBOutlet NSWindow *window;
@property (retain) IBOutlet NSTextView *consoleText;
@property (retain) IBOutlet NSTextField *commandInput;
@property int fd;
@property BOOL running;
@property (retain) NSConnection *terminalAppConnection;

@property (retain) MMTerminalWindowController *terminalWindow;

+ (NSConnection *)shellConnection;

- (void)handleTerminalInput:(NSString *)input;

@end
