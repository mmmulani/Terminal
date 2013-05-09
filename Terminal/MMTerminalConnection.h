//
//  MMTerminalConnection.h
//  Terminal
//
//  Created by Mehdi Mulani on 5/8/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MMTerminalWindowController;

@interface MMTerminalConnection : NSObject

@property int fd;
@property BOOL running;
@property (strong) MMTerminalWindowController *terminalWindow;
@property NSInteger identifier;

- (id)initWithIdentifier:(NSInteger)identifier;

- (void)createTerminalWindow;

- (void)handleTerminalInput:(NSString *)input;
- (void)runCommands:(NSString *)commandsText;

- (void)startShell;
- (void)handleOutput:(NSString *)output;
- (void)directoryChangedTo:(NSString *)newPath;
- (void)processFinished;

@end
