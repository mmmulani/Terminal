//
//  MMConnectRemoteWindowController.m
//  Terminal
//
//  Created by Mehdi Mulani on 7/30/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMConnectRemoteWindowController.h"
#import "MMTerminalConnection.h"
#import "MMRemoteTerminalConnection.h"
#import "MMAppDelegate.h"

@interface MMConnectRemoteWindowController ()

@property NSPipe *inputPipe;
@property MMTask *sshTask;
@property MMTerminalConnection *terminalConnection;
@property id windowController;

@end

@interface MMTerminalConnection ()

@property NSMutableDictionary *tasksByFD;

@end

@implementation MMConnectRemoteWindowController

- (id)init;
{
  self = [self initWithWindowNibName:@"MMConnectRemoteWindowController"];
  if (!self) {
    return nil;
  }

  return self;
}

- (void)windowDidLoad
{
  [super windowDidLoad];

  self.sshTextView.delegate = self;

  // Prompt for a server to connect to.
  NSAlert *alert = [NSAlert alertWithMessageText:@"Choose a server" defaultButton:@"Connect" alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@"Enter the SSH host to run this session on."];
  NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
  alert.accessoryView = input;
  NSInteger button = [alert runModal];
  if (button == NSAlertAlternateReturn) {
    return;
  }

  NSString *sshHost = input.stringValue;
  NSString *sshCommand = [NSString stringWithFormat:@"/usr/bin/ssh -T \"%@\" \"/usr/local/bin/python3.3 -u term-server/server.py", sshHost];

  // XXX: j0nx because we can't figure out NSTask.
  self.terminalConnection = [[MMTerminalConnection alloc] initWithIdentifier:9999];
  [self.terminalConnection createTerminalWindowWithState:nil completionHandler:nil];
  self.terminalConnection.terminalWindow = nil;

  double delayInSeconds = 2.0;
  dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
  dispatch_after(popTime, dispatch_get_main_queue(), ^(void){

    self.sshTask = [self.terminalConnection createAndRunTaskWithCommand:sshCommand taskDelegate:self];
    [self.sshTextView.layoutManager replaceTextStorage:self.sshTask.displayTextStorage];
  });
}

# pragma mark - MMTextView delegate

- (void)handleKeyPress:(NSEvent *)keyEvent;
{
  // Really ghetto but we assume that after they hit enter, we are done with the SSH login and can use it for our remote proxy.
  [self.sshTask handleUserInput:[keyEvent characters]];
  if ([keyEvent.characters isEqualToString:@"\r"]) {
    [((MMAppDelegate *)[NSApp delegate]).terminalConnections addObject:self.terminalConnection];

    MMRemoteTerminalConnection *remoteTerminalConnection = [[MMRemoteTerminalConnection alloc] initWithIdentifier:0];
    remoteTerminalConnection.bootstrapTerminalConnection = self.terminalConnection;
    self.terminalConnection.tasksByFD[self.terminalConnection.tasksByFD.allKeys[0]] = remoteTerminalConnection;

    [((MMAppDelegate *)[NSApp delegate]).terminalConnections addObject:remoteTerminalConnection];
    [remoteTerminalConnection createTerminalWindowWithState:nil completionHandler:nil];

    [self.window close];
  }
}

- (void)handleInput:(NSString *)input;
{
  [self.sshTask handleUserInput:input];
}

# pragma mark - MMTaskDelegate protocol

- (void)taskStarted:(MMTask *)task;
{

}

- (void)taskFinished:(MMTask *)task;
{

}

- (void)taskMovedToBackground:(MMTask *)task;
{

}

- (void)taskReceivedOutput:(MMTask *)task;
{
  
}

@end
