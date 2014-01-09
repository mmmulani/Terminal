//
//  MMConnectRemoteWindowController.m
//  Terminal
//
//  Created by Mehdi Mulani on 7/30/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMAppDelegate.h"
#import "MMConnectRemoteWindowController.h"
#import "MMRemoteTerminalConnection.h"
#import "MMTextView.h"

@interface MMConnectRemoteWindowController ()

@property NSPipe *sshErrorPipe;
@property NSPipe *sshInputPipe;
@property NSPipe *sshOutputPipe;
@property NSTask *sshTask;
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

  NSTask *task = [[NSTask alloc] init];
  self.sshTask = task;
  task.launchPath = @"/usr/bin/script";
  NSString *sshHost = input.stringValue;
  task.arguments = @[ @"-q", @"/dev/null", @"/usr/bin/ssh", @"-T", sshHost, @"/usr/local/bin/python3.3 -u term-server/server.py remote" ];

  self.sshErrorPipe = [NSPipe pipe];
  self.sshInputPipe = [NSPipe pipe];
  self.sshOutputPipe = [NSPipe pipe];
  //task.standardError = self.sshErrorPipe;
  task.standardInput = self.sshInputPipe;
  task.standardOutput = self.sshOutputPipe;

  task.terminationHandler = ^(NSTask *task) {
    [self.window close];
  };

  [self performSelectorInBackground:@selector(_readSSHOutput) withObject:nil];

  [task launch];
}

- (void)_readSSHOutput
{
  @autoreleasepool {
    while (YES) {
      NSData *data = [self.sshOutputPipe.fileHandleForReading availableData];
      if (data.length == 0) {
        break;
      }
      NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

      NSRange flagRange = [output rangeOfString:@"☃"];
      if (flagRange.location != NSNotFound) {
        NSString *initialOutput = [output substringFromIndex:(flagRange.location + 1)];
        dispatch_async(dispatch_get_main_queue(), ^{
          [self shellStartedWithInitialOutput:initialOutput];
        });
        break;
      }

      dispatch_async(dispatch_get_main_queue(), ^{
        [self.sshTextView.textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:output]];
      });
    }
  }
}

- (void)shellStartedWithInitialOutput:(NSString *)initialOutput
{
  self.sshTask.terminationHandler = nil;
  [((MMAppDelegate *)[NSApp delegate]) createNewRemoteTerminalWindowWithSSHTask:self.sshTask initialOutput:initialOutput];
  [self.window close];
}

# pragma mark - MMTextView delegate

- (void)handleKeyPress:(NSEvent *)keyEvent
{
  NSString *input = [keyEvent characters];
  [self handleInput:input];
}

- (void)handleInput:(NSString *)input
{
  [self.sshInputPipe.fileHandleForWriting writeData:[input dataUsingEncoding:NSUTF8StringEncoding]];
}

@end
