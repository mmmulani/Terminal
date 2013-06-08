//
//  MMTerminalConnection.h
//  Terminal
//
//  Created by Mehdi Mulani on 5/8/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MMTerminalProxy.h"

@class MMTerminalWindowController;
@class MMTask;

@interface MMTerminalConnection : NSObject <MMTerminalProxy>

@property int fd;
@property BOOL running;
@property (strong) MMTerminalWindowController *terminalWindow;
@property (strong) NSString *currentDirectory;
@property NSInteger identifier;

- (id)initWithIdentifier:(NSInteger)identifier;

- (void)createTerminalWindowWithState:(NSCoder *)state completionHandler:(void (^)(NSWindow *, NSError *))completionHandler;

- (void)handleTerminalInput:(NSString *)input;
- (void)runCommandsForTask:(MMTask *)task;
- (void)setPathVariable:(NSString *)pathVariable;

- (void)startShell;
- (void)handleOutput:(NSString *)output;

- (void)end;

- (void)changeTerminalSizeToColumns:(NSInteger)columns rows:(NSInteger)rows;

@end
