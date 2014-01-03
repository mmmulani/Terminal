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

@property NSString *directoryToStartIn;
@property NSMutableDictionary *tasksByIdentifier;
@property NSMutableArray *shellCommandTasks;
@property dispatch_queue_t outputQueue;
@property NSTask *shellTask;
@property NSPipe *shellErrorPipe;
@property NSPipe *shellInputPipe;
@property NSPipe *shellOutputPipe;
@property NSMutableDictionary *directoryData;

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
  self.terminalHeight = DEFAULT_TERM_HEIGHT;
  self.terminalWidth = DEFAULT_TERM_WIDTH;
  self.tasksByIdentifier = [NSMutableDictionary dictionary];
  self.directoryData = [NSMutableDictionary dictionary];
  self.shellCommandTasks = [NSMutableArray array];

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
  task.launchPath = @"/usr/local/bin/python3.3";
  task.arguments = @[ @"-u", @"/Users/mehdi/src/term-server/server.py" ];

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
  @autoreleasepool {
    NSMutableString *shellOutput = [NSMutableString string];
    while (YES) {
      NSData *data = [self.shellOutputPipe.fileHandleForReading availableData];
      if (data.length == 0) {
        break;
      }
      [shellOutput appendString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];

      NSRange newlineRange = [shellOutput rangeOfString:@"\n"];
      while (newlineRange.location != NSNotFound) {
        NSString *messageString = [shellOutput substringToIndex:newlineRange.location];

        NSDictionary *message = [messageString objectFromJSONString];
        if (!message) {
          NSLog(@"Server did not send JSON object!");
        }

        // A lot of the messages affect UI, so it's easier to run them all on the main thread for now.
        dispatch_async(dispatch_get_main_queue(), ^{
          [self _processShellMessage:message[@"type"] content:message[@"message"]];
        });

        shellOutput = [[shellOutput substringFromIndex:(newlineRange.location + 1)] mutableCopy];
        newlineRange = [shellOutput rangeOfString:@"\n"];
      }
    }
  }
}

- (void)_processShellMessage:(NSString *)name content:(NSDictionary *)content
{
  MMTask *task;
  if (content[@"identifier"]) {
    task = self.tasksByIdentifier[content[@"identifier"]];
  }

  if ([name isEqualToString:@"task_output"]) {
    [task handleCommandOutput:content[@"output"]];
  } else if ([name isEqualToString:@"task_done"]) {
    [task processFinished:MMProcessStatusExit data:content[@"code"]];
  } else if ([name isEqualToString:@"directory_info"]) {
    BOOL firstDirectory = [self.directoryData count] == 0;
    [self storeDirectoryInformation:content];
    if (firstDirectory) {
      [self directoryChangedTo:[content allKeys][0]];
    }
  } else if ([name isEqualToString:@"changed_directory"]) {
    [self directoryChangedTo:content[@"directory"]];
    MMTask *task = self.shellCommandTasks[0];
    [task processFinished:YES data:content[@"directory"]];
    [self.shellCommandTasks removeObjectAtIndex:0];
  } else {
    NSLog(@"Got message %@ with body %@", name, content);
  }
}

- (void)_sendShellMessage:(NSString *)name content:(NSDictionary *)content
{
  NSAssert(name, @"Must provide a message name");

  NSDictionary *message =
  @{
    @"type": name,
    @"message": content ?: @{},
    };
  [self.shellInputPipe.fileHandleForWriting writeData:[message JSONData]];
  [self.shellInputPipe.fileHandleForWriting writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)handleTerminalInput:(NSString *)input task:(MMTask *)task
{
  // Convert input to hex characters to avoid breaking JSON decoders.
  NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding];
  NSMutableString *hexString = [NSMutableString stringWithCapacity:(data.length * 2)];
  const unsigned char *stringBuffer = data.bytes;
  for (NSInteger i = 0; i < data.length; i++) {
    [hexString appendFormat:@"%02lX", (unsigned long)stringBuffer[i]];
  }
  NSDictionary *message =
  @{
    @"identifier": @(task.identifier),
    @"input": hexString,
    };
  [self _sendShellMessage:@"handle_input" content:message];
}

- (MMTask *)createAndRunTaskWithCommand:(NSString *)command taskDelegate:(id <MMTaskDelegate>)delegate
{
  MMTask *task = [[MMTask alloc] initWithTerminalConnection:self];
  task.command = [NSString stringWithString:command];
  task.startedAt = [NSDate date];
  task.delegate = delegate;
  delegate.task = task;
  ((MMTaskCellViewController *)delegate).windowController = self.terminalWindow;

  NSArray *commandGroups = task.commandGroups;

  // TODO: Support multiple commands.
  // TODO: Handle the case of no commands better. (Also detect it better.)
  if (commandGroups.count == 0 || [commandGroups[0] commands].count == 0) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [task processStarted];
      [task processFinished:MMProcessStatusError data:nil];
    });
    return task;
  }

  if (commandGroups.count > 1) {
    MMLog(@"Discarded all commands past the first in: %@", task.command);
  }

  if ([MMShellCommands isShellCommand:[commandGroups[0] commands][0]]) {
    [self.shellCommandTasks addObject:task];

    [task processStarted];

    NSDictionary *message =
    @{
      @"directory": [[commandGroups[0] commands][0] arguments][1],
      };
    [self _sendShellMessage:@"dir_change" content:message];

    return task;
  }

  self.tasksByIdentifier[@(task.identifier)] = task;

  MMCommand *commandObj = [commandGroups[0] commands][0];
  NSDictionary *message =
  @{
    @"identifier": @( task.identifier ),
    @"arguments": commandObj.arguments,
    };
  [self _sendShellMessage:@"start_task" content:message];

  [task processStarted];

  return task;
}

- (void)setPathVariable:(NSString *)pathVariable
{

}

- (void)startShellsToRunCommands:(NSInteger)numberOfCommands
{
  [self _sendShellMessage:@"startShells" content:@{ @"amount": @(numberOfCommands) }];
}

- (void)end
{
  [self _sendShellMessage:@"exit" content:@{}];
}

- (void)changeTerminalSizeToColumns:(NSInteger)columns rows:(NSInteger)rows
{
  self.terminalHeight = rows;
  self.terminalWidth = columns;

  // TODO: Send message to server.
}

- (void)storeDirectoryInformation:(NSDictionary *)information;
{
  NSString *directory = [information allKeys][0];
  self.directoryData[directory] = information[directory];
  if (!self.currentDirectory) {
    [self directoryChangedTo:directory];
  }
}

- (NSDictionary *)dataForPath:(NSString *)path;
{
  return self.directoryData[path];
}


# pragma mark - MMTerminalProxy

- (void)shellStartedWithIdentifier:(MMShellIdentifier)identifier;
{
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

@end
