//
//  MMDebugMessagesWindowController.h
//  Terminal
//
//  Created by Mehdi Mulani on 2/21/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MMDebugMessagesWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>

@property (strong) IBOutlet NSTableView *tableView;
@property (strong) IBOutlet NSTableColumn *tableColumn;
@property (strong) NSMutableArray *debugMessages;

- (void)addDebugMessage:(NSString *)message;

@end
