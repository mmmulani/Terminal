//
//  MMAppDelegate.h
//  Terminal
//
//  Created by Mehdi Mulani on 1/29/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MMTerminalWindowController.h"
#import "MMDebugMessagesWindowController.h"

@interface MMAppDelegate : NSObject <NSApplicationDelegate, NSTextFieldDelegate>

@property (strong) MMDebugMessagesWindowController *debugWindow;
@property (strong) NSConnection *terminalAppConnection;
@property (strong) NSMutableArray *terminalConnections;

- (IBAction)createNewTerminal:(id)sender;

@end
