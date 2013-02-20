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

@property (strong) IBOutlet MMTextView *consoleText;
@property (strong) IBOutlet NSTextField *commandInput;
@property (strong) IBOutlet NSTableView *tableView;
@property (strong) NSMutableArray *tasks;
@property BOOL running;

- (void)handleOutput:(NSString *)message;
- (void)processFinished;

@end
