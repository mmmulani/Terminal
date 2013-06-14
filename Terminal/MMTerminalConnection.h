//
//  MMTerminalConnection.h
//  Terminal
//
//  Created by Mehdi Mulani on 5/8/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MMTerminalProxy.h"

#define DEFAULT_TERM_WIDTH 80
#define DEFAULT_TERM_HEIGHT 24

@class MMTerminalWindowController;
@class MMTask;

@interface MMTerminalConnection : NSObject <MMTerminalProxy>

@property int fd;
@property BOOL running;
@property (strong) MMTerminalWindowController *terminalWindow;
@property (strong) NSString *currentDirectory;
@property NSInteger terminalHeight;
@property NSInteger terminalWidth;
@property NSInteger identifier;

- (id)initWithIdentifier:(NSInteger)identifier;

- (void)createTerminalWindowWithState:(NSCoder *)state completionHandler:(void (^)(NSWindow *, NSError *))completionHandler;

- (void)handleTerminalInput:(NSString *)input;
- (MMTask *)createAndRunTaskWithCommand:(NSString *)command;
- (void)setPathVariable:(NSString *)pathVariable;

- (void)startShell;

- (void)end;

- (void)changeTerminalSizeToColumns:(NSInteger)columns rows:(NSInteger)rows;

@end
