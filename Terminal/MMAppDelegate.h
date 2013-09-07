//
//  MMAppDelegate.h
//  Terminal
//
//  Created by Mehdi Mulani on 1/29/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quincy/BWQuincyManager.h>

#import "MMTerminalWindowController.h"
#import "MMDebugMessagesWindowController.h"

@class MMFirstRunWindowController;

@interface MMAppDelegate : NSObject <BWQuincyManagerDelegate, NSApplicationDelegate, NSTextFieldDelegate, NSWindowRestoration>

@property MMFirstRunWindowController *firstRunWindowController;
@property (strong) MMDebugMessagesWindowController *debugWindow;
@property (strong) NSTextStorage *debugMessages;
@property (strong) NSConnection *terminalAppConnection;
@property (strong) NSMutableArray *terminalConnections;
@property (strong) IBOutlet NSMenuItem *windowMenu;

- (IBAction)createNewTerminal:(id)sender;
- (IBAction)createNewRemoteTerminal:(id)sender;
- (IBAction)openDebugWindow:(id)sender;

- (NSInteger)uniqueWindowShortcut;
- (void)resignWindowShortcut:(NSInteger)shortcut;
- (void)updateWindowMenu;
- (void)terminalWindowWillClose:(MMTerminalWindowController *)windowController;

@end
