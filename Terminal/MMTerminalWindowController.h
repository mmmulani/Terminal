//
//  MMTerminalWindowController.h
//  Terminal
//
//  Created by Mehdi Mulani on 2/18/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MMTextView.h"
#import "MMTerminalProxy.h"

@class MMTerminalConnection;
@class MMCommandsTextView;
@class MMTask;
@class MMInfoOverlayView;
@class MMTaskCellViewController;

@interface MMTerminalWindowController : NSWindowController <NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate>

@property (strong) IBOutlet MMCommandsTextView *commandInput;
@property (strong) IBOutlet NSTableView *tableView;
@property (strong) IBOutlet NSCollectionView *directoryCollectionView;
@property (strong) IBOutlet NSTextField *currentDirectoryLabel;
@property (strong) IBOutlet NSView *commandControlsView;
@property (strong) IBOutlet NSLayoutConstraint *commandControlsLayoutConstraint;
@property (strong) IBOutlet MMInfoOverlayView *infoOverlayView;
@property (strong) NSMutableArray *tasks;
@property (strong) NSMutableArray *taskViewControllers;
@property (weak) MMTerminalConnection *terminalConnection;
@property (readonly) NSInteger keyboardShortcut;

- (id)initWithTerminalConnection:(MMTerminalConnection *)terminalConnection withState:(NSCoder *)state completionHandler:(void (^)(NSWindow *, NSError *))completionHandler;

- (void)directoryChangedTo:(NSString *)newPath;

- (void)noteHeightChangeForTask:(MMTaskCellViewController *)taskViewController;

- (void)resizeWindowForTerminalScreenSizeOfColumns:(NSInteger)columns rows:(NSInteger)rows;

- (void)taskStarted:(MMTaskCellViewController *)taskController;
- (void)taskFinished:(MMTaskCellViewController *)taskController;
- (void)taskRunsInBackground:(MMTaskCellViewController *)taskController;

@end
