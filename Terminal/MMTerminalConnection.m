//
//  MMTerminalConnection.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/8/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#include <termios.h>
#include <util.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <syslog.h>
#include "iconv.h"

#import "JSONKit.h"
#import "MMTerminalConnection.h"
#import "MMTerminalWindowController.h"
#import "MMShared.h"
#import "MMCommandLineArgumentsParser.h"
#import "MMCommandGroup.h"
#import "MMTask.h"
#import "MMShellCommands.h"
#import "MMUtilities.h"
#import "MMShellProxy.h"
#import "MMTaskCellViewController.h"

@interface MMTerminalConnection ()

+ (NSInteger)uniqueShellIdentifier;

@property NSConnection *connectionToSelf;
@property NSString *directoryToStartIn;
@property NSMutableDictionary *tasksByFD;
@property NSMutableArray *unusedShells;
@property NSMutableArray *busyShells;
@property NSMutableDictionary *shellIdentifierToFD;
@property NSMutableDictionary *shellIdentifierToProxy;
@property NSMutableArray *shellCommandTasks;
@property dispatch_queue_t outputQueue;
@property NSTask *shellTask;
@property NSPipe *shellErrorPipe;
@property NSPipe *shellInputPipe;
@property NSPipe *shellOutputPipe;

- (MMShellIdentifier)unusedShell;
- (NSProxy<MMShellProxy> *)proxyForShellIdentifier:(MMShellIdentifier)identifier;
- (int)fdForTask:(MMTask *)task;

@end

@implementation MMTerminalConnection

+ (MMShellIdentifier)uniqueShellIdentifier;
{
  static NSInteger uniqueIdentifier = 0;
  uniqueIdentifier++;

  return uniqueIdentifier;
}

- (id)initWithIdentifier:(NSInteger)identifier
{
  if (!(self = [super init])) {
    return nil;
  }

  self.terminalIdentifier = identifier;

  return self;
}

- (void)createTerminalWindowWithState:(NSCoder *)state completionHandler:(void (^)(NSWindow *, NSError *))completionHandler
{
  self.terminalWindow = [[MMTerminalWindowController alloc] initWithTerminalConnection:self withState:nil completionHandler:completionHandler];
  [self.terminalWindow showWindow:nil];

  [self _startRemoteShell];
}

- (void)_startRemoteShell
{
  NSTask *task = [[NSTask alloc] init];
  self.shellTask = task;
  task.launchPath = @"/usr/bin/runhaskell";
  task.arguments = @[ @"/Users/mehdi/Development/hs-shell/main.hs" ];

  self.shellErrorPipe = [NSPipe pipe];
  self.shellInputPipe = [NSPipe pipe];
  self.shellOutputPipe = [NSPipe pipe];
  //task.standardError = self.shellErrorPipe;
  task.standardInput = self.shellInputPipe;
  task.standardOutput = self.shellOutputPipe;

  [self performSelectorInBackground:@selector(_readShellOutput) withObject:nil];

  NSLog(@"starting");
  [task launch];
}

- (void)_readShellOutput
{
  NSMutableString *shellOutput = [NSMutableString string];
  while (YES) {
    NSData *data = [self.shellOutputPipe.fileHandleForReading availableData];
    [shellOutput appendString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];

    NSRange newlineRange = [shellOutput rangeOfString:@"\n"];
    while (newlineRange.location != NSNotFound) {
      NSString *messageString = [shellOutput substringToIndex:newlineRange.location];

      NSDictionary *message = [messageString objectFromJSONString];
      if (!message) {
        NSLog(@"Server did not send JSON object!");
      }

      [self _processShellMessage:message[@"name"] extra:message[@"extra"]];

      shellOutput = [[shellOutput substringFromIndex:(newlineRange.location + 1)] mutableCopy];
      newlineRange = [shellOutput rangeOfString:@"\n"];
    }
  }
}

- (void)_processShellMessage:(NSString *)name extra:(NSArray *)extra
{

}

- (void)_sendShellMessage:(NSString *)name extra:(NSArray *)extra
{
  NSAssert(name, @"Must provide a message name");

  NSDictionary *message =
  @{
    @"name": name,
    @"extra": extra ?: @[],
    };
  [self.shellInputPipe.fileHandleForWriting writeData:[message JSONData]];
}

- (void)handleTerminalInput:(NSString *)input task:(MMTask *)task
{

}

- (MMTask *)createAndRunTaskWithCommand:(NSString *)command taskDelegate:(id <MMTaskDelegate>)delegate
{
  [self _sendShellMessage:@"runCommand" extra:@[ command ]];

  return nil;
}

- (void)setPathVariable:(NSString *)pathVariable
{

}

- (void)startShellsToRunCommands:(NSInteger)numberOfCommands
{
  NSArray *extra = @[ @(numberOfCommands) ];
  [self _sendShellMessage:@"startShells" extra:extra];
}

- (void)end
{

}

- (void)changeTerminalSizeToColumns:(NSInteger)columns rows:(NSInteger)rows
{

}

# pragma mark - MMTerminalProxy

- (void)shellStartedWithIdentifier:(MMShellIdentifier)identifier;
{
  NSProxy *shellProxy = [[NSConnection connectionWithRegisteredName:[ConnectionShellName stringByAppendingFormat:@".%ld.%ld", self.terminalIdentifier, identifier] host:nil] rootProxy];
  self.shellIdentifierToProxy[@(identifier)] = shellProxy;
  [self.unusedShells addObject:@(identifier)];
}

- (void)taskFinished:(MMTaskIdentifier)taskIdentifier status:(MMProcessStatus)status data:(id)data;
{
}

- (void)directoryChangedTo:(NSString *)newPath;
{
  self.currentDirectory = newPath;
  [self.terminalWindow directoryChangedTo:newPath];
}

- (void)taskFinished:(MMTaskIdentifier)taskIdentifier shellCommand:(MMShellCommand)command succesful:(BOOL)success attachment:(id)attachment;
{
  MMTask *task;
  for (MMTask *possibleTask in self.shellCommandTasks) {
    if (possibleTask.identifier == taskIdentifier) {
      task = possibleTask;
      break;
    }
  }

  [self.shellCommandTasks removeObject:task];
  dispatch_async(dispatch_get_main_queue(), ^{
    [task processFinished:success data:attachment];
  });
}

# pragma mark - Shell identifier organization

- (int)fdForTask:(MMTask *)task;
{
  return [[self.tasksByFD allKeysForObject:task][0] intValue];
}

- (int)fdForTaskIdentifier:(MMTaskIdentifier)taskIdentifier;
{
  NSSet *tasksForFD = [self.tasksByFD keysOfEntriesPassingTest:^BOOL(NSNumber *fd, MMTask *task, BOOL *stop) {
    if (task.identifier == taskIdentifier) {
      *stop = YES;
      return YES;
    }

    return NO;
  }];

  if (tasksForFD.count == 0) {
    return 0;
  }

  return [tasksForFD.allObjects[0] intValue];
}

- (MMShellIdentifier)shellIdentifierForFD:(int)fd;
{
  return [[self.shellIdentifierToFD allKeysForObject:@(fd)][0] integerValue];
}

- (NSProxy<MMShellProxy> *)proxyForShellIdentifier:(MMShellIdentifier)identifier;
{
  return self.shellIdentifierToProxy[@(identifier)];
}

- (MMShellIdentifier)unusedShell;
{
  if (self.unusedShells.count == 0) {
    return 0;
  }

  return [self.unusedShells[0] integerValue];
}

@end
