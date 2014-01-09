//
//  MMRemoteTerminalConnection.m
//  Terminal
//
//  Created by Mehdi Mulani on 7/30/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMRemoteTerminalConnection.h"
#import "MMTerminalConnection.h"
#import "MMTerminalConnectionInternal.h"

@implementation MMRemoteTerminalConnection

- (void)createTerminalWindowWithState:(NSCoder *)state completionHandler:(void (^)(NSWindow *, NSError *))completionHandler;
{
  // TODO: Implement restoration.
  if (state) {
    return;
  }

  [super createTerminalWindowWithState:state completionHandler:completionHandler];
}

- (void)_startRemoteShell
{
  // Our pipes should be set up as this point.

  [self performSelectorInBackground:@selector(_readShellOutput) withObject:nil];
}

- (void)setUpRemoteTerminalConnectionWithSSHTask:(NSTask *)sshTask initialOutput:(NSString *)initialOutput
{
  self.shellTask = sshTask;
  NSAssert([sshTask.standardInput isKindOfClass:[NSPipe class]], @"Standard input should be a NSPipe");
  NSAssert([sshTask.standardOutput isKindOfClass:[NSPipe class]], @"Standard output should be a NSPipe");
  self.shellInputPipe = sshTask.standardInput;
  self.shellOutputPipe = sshTask.standardOutput;

  self.unreadInitialOutput = initialOutput;
}

@end
