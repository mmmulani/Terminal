//
//  MMAppDelegate.m
//  Terminal
//
//  Created by Mehdi Mulani on 1/29/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMAppDelegate.h"
#import "MMShared.h"
#import "MMTerminalConnection.h"

@implementation MMAppDelegate

- (IBAction)createNewTerminal:(id)sender;
{
    static NSInteger uniqueIdentifier = 0;
    uniqueIdentifier++;
    [[[MMTerminalConnection alloc] initWithIdentifier:uniqueIdentifier] createTerminalWindow];
}

# pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification;
{
    self.terminalAppConnection = [NSConnection serviceConnectionWithName:ConnectionTerminalName rootObject:self];

    self.debugWindow = [[MMDebugMessagesWindowController alloc] init];
    [self.debugWindow showWindow:nil];

    [self createNewTerminal:nil];
}

- (void)_logMessage:(NSString *)message;
{
    [self.debugWindow addDebugMessage:message];
}

@end
