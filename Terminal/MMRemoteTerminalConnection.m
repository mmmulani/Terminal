//
//  MMRemoteTerminalConnection.m
//  Terminal
//
//  Created by Mehdi Mulani on 7/30/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMRemoteTerminalConnection.h"
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

@interface MMRemoteTerminalConnection ()

@property NSMutableDictionary *directoryData;
@property NSString *outputBuffer;
@property NSMutableDictionary *taskByIdentifier;

@end

@interface MMTerminalConnection ()

- (void)ghettoFunctionByRemote;
@property dispatch_queue_t outputQueue;

@end

@implementation MMRemoteTerminalConnection

- (void)createTerminalWindowWithState:(NSCoder *)state completionHandler:(void (^)(NSWindow *, NSError *))completionHandler;
{
  self.directoryData = [NSMutableDictionary dictionary];
  self.taskByIdentifier = [NSMutableDictionary dictionary];
    
  // TODO: Implement restoration.
  if (state) {
    return;
  }
  
  self.terminalWindow = [[MMTerminalWindowController alloc] initWithTerminalConnection:self withState:state completionHandler:completionHandler];
  [self.terminalWindow showWindow:nil];
  
  [self.bootstrapTerminalConnection ghettoFunctionByRemote];
}

- (MMTask *)createAndRunTaskWithCommand:(NSString *)command taskDelegate:(id <MMTaskDelegate>)delegate;
{
  MMTask *task = [[MMTask alloc] initWithTerminalConnection:self];
  task.command = [NSString stringWithString:command];
  task.startedAt = [NSDate date];
  task.delegate = delegate;
  [delegate setTask:task];
  ((MMTaskCellViewController *)delegate).windowController = self.terminalWindow;
  
  NSArray *commandGroups = task.commandGroups;
  
  self.taskByIdentifier[@(task.identifier)] = task;
  
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
    [task processStarted];
    
    NSArray *arguments = [[commandGroups[0] commands][0] arguments];
    if ([arguments[0] isEqualToString:@"cd"]) {
      [self changeDirectoryTo:arguments[1] task:task];
    } else if ([arguments[0] isEqualToString:@"cat_"]) {
      [self catImage:arguments[1] task:task];
    }
    
    return task;
  }
  
  [task processStarted];
  
  NSDictionary *attachment = @{ @"arguments": [[commandGroups[0] commands][0] arguments], @"identifier": @(task.identifier) };
  
  [self sendMessage:@"start_task" withAttachment:attachment];
  
  return task;
}

- (void)setPathVariable:(NSString *)pathVariable;
{
  
}

- (void)startShellsToRunCommands:(NSInteger)numberOfCommands;
{
  [self sendMessage:@"make_enough_terms" withAttachment:@(numberOfCommands)];
}

- (void)startShell;
{
  
}

- (void)end;
{
  
}

- (void)changeTerminalSizeToColumns:(NSInteger)columns rows:(NSInteger)rows;
{
  self.terminalHeight = rows;
  self.terminalWidth = columns;
  
  [self sendMessage:@"resize_term" withAttachment:@{ @"columns": @(columns), @"rows": @(rows) }];
}

- (void)changeDirectoryTo:(NSString *)directory task:(MMTask *)task;
{
  [self sendMessage:@"dir_change" withAttachment:@{ @"directory": directory, @"identifier": @(task.identifier) }];
}

- (void)catImage:(NSString *)path task:(MMTask *)task;
{
  [self sendMessage:@"cat_image" withAttachment:@{ @"image": path, @"identifier": @(task.identifier) }];
}

- (void)sendMessage:(NSString *)type withAttachment:(id)attachment;
{
  NSDictionary *jsonObject = @{ @"type": type, @"message": attachment };
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonObject options:0 error:nil];
  NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
  
  NSLog(@"JSON string: %@", jsonString);
  
  [self writeString:[jsonString stringByAppendingString:@"\n"]];
}

- (void)handleOutput:(NSString *)output forFD:(int)fd;
{
  dispatch_async(self.outputQueue, ^{
    [self.taskByIdentifier[@(fd)] handleCommandOutput:output];
  });
}

- (void)handleTerminalInput:(NSString *)input task:(MMTask *)task;
{  
  // Convert input to hex characters to avoid breaking JSON decoders.
  NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding];
  NSMutableString *hexString = [NSMutableString stringWithCapacity:(data.length * 2)];
  const unsigned char *stringBuffer = data.bytes;
  for (NSInteger i = 0; i < data.length; i++) {
    [hexString appendFormat:@"%02lX", (unsigned long)stringBuffer[i]];
  }
  [self sendMessage:@"handle_input" withAttachment:@{ @"input": hexString, @"identifier": @(task.identifier) }];
}

- (void)handleTaskDone:(NSDictionary *)status;
{
  MMProcessStatus method = [status[@"method"] isEqualToString:@"exit"] ? MMProcessStatusExit : MMProcessStatusSignal;
  [self.taskByIdentifier[status[@"identifier"]] processFinished:method data:status[@"code"]];
//  [self.taskByIdentifier removeObjectForKey:status[@"identifier"]];
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

# pragma mark - MMTask faking

- (void)handleCommandOutput:(NSString *)output;
{
  NSLog(@"Got output from server: %@", output);
  
  dispatch_async(dispatch_get_main_queue(), ^{
    NSString *_output = output;
    if (self.outputBuffer) {
      _output = [self.outputBuffer stringByAppendingString:output];
    }
    
    NSRange newlineRange = [_output rangeOfString:@"\n"];
    while (newlineRange.location != NSNotFound) {
      NSString *jsonExcerpt = [_output substringWithRange:NSMakeRange(0, newlineRange.location)];
      _output = [_output substringFromIndex:(newlineRange.location + 1)];

      NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:[jsonExcerpt dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
      NSString *type = jsonObject[@"type"];
      id attachment = jsonObject[@"message"];
      if ([type isEqualToString:@"task_output"]) {
        [self handleOutput:attachment[@"output"] forFD:[attachment[@"identifier"] intValue]];
      } else if ([type isEqualToString:@"task_done"]) {
        [self handleTaskDone:attachment];
      } else if ([type isEqualToString:@"directory_info"]) {
        [self storeDirectoryInformation:attachment];
      } else if ([type isEqualToString:@"changed_directory"]) {
        MMTask *task = self.taskByIdentifier[attachment[@"identifier"]];
        if (!task.isFinished) {
          [task processFinished:MMProcessStatusExit data:attachment[@"directory"]];
        }
        [self directoryChangedTo:attachment[@"directory"]];
      } else if ([type isEqualToString:@"dir_change_fail"]) {
        MMTask *task = self.taskByIdentifier[attachment[@"identifier"]];
        if (!task.isFinished) {
          [task processFinished:MMProcessStatusError data:attachment[@"directory"]];
        }
      } else if ([type isEqualToString:@"got_image"]) {
        MMTask *task = self.taskByIdentifier[attachment[@"identifier"]];
        [task processFinished:MMProcessStatusExit data:attachment];
      }
      
      newlineRange = [_output rangeOfString:@"\n"];
    }
    
    self.outputBuffer = _output;
  });
}

- (void)writeString:(NSString *)input;
{
  [self.bootstrapTerminalConnection handleTerminalInput:input task:(MMTask *)self];
}

- (NSInteger)identifier;
{
  return 0;
}

@end
