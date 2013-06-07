//
//  MMTerminalWindowController.h
//  Terminal
//
//  Created by Mehdi Mulani on 2/18/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MMTextView.h"

@class MMTerminalConnection;
@class MMCommandsTextView;
@class MMTask;

@interface MMTerminalWindowController : NSWindowController <NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate>

@property (strong) IBOutlet MMCommandsTextView *commandInput;
@property (strong) IBOutlet NSTableView *tableView;
@property (strong) IBOutlet NSCollectionView *directoryCollectionView;
@property (strong) IBOutlet NSTextField *currentDirectoryLabel;
@property (strong) IBOutlet NSView *commandControlsView;
@property (strong) IBOutlet NSLayoutConstraint *commandControlsLayoutConstraint;
@property (strong) NSMutableArray *tasks;
@property (strong) NSMutableArray *taskViewControllers;
@property (weak) MMTerminalConnection *terminalConnection;
@property BOOL running;
@property (readonly) NSInteger keyboardShortcut;

- (id)initWithTerminalConnection:(MMTerminalConnection *)terminalConnection withState:(NSCoder *)state completionHandler:(void (^)(NSWindow *, NSError *))completionHandler;

- (void)handleOutput:(NSString *)message;
- (void)processFinished;
- (void)directoryChangedTo:(NSString *)newPath;
- (void)shellCommandFinished;
- (MMTask *)lastTask;

@end
