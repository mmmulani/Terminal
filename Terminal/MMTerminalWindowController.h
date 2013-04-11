//
//  MMTerminalWindowController.h
//  Terminal
//
//  Created by Mehdi Mulani on 2/18/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MMTextView.h"

@interface MMTerminalWindowController : NSWindowController <NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate>

@property (strong) IBOutlet NSTextField *commandInput;
@property (strong) IBOutlet NSTableView *tableView;
@property (strong) IBOutlet NSCollectionView *directoryCollectionView;
@property (strong) IBOutlet NSTextField *currentDirectoryLabel;
@property (strong) IBOutlet NSView *commandControlsView;
@property (strong) IBOutlet NSLayoutConstraint *commandControlsLayoutConstraint;
@property (strong) NSMutableArray *tasks;
@property (strong) NSMutableArray *taskViewControllers;
@property BOOL running;
@property BOOL logAllCharacters;

- (void)handleOutput:(NSString *)message;
- (void)processFinished;
- (void)directoryChangedTo:(NSString *)newPath;

@end
