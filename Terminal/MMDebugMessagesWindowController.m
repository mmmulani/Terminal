//
//  MMDebugMessagesWindowController.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/21/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMDebugMessagesWindowController.h"

@interface MMDebugMessagesWindowController ()

@end

@implementation MMDebugMessagesWindowController

- (id)init;
{
    self = [self initWithWindowNibName:@"MMDebugMessagesPanel"];
    if (!self) {
        return nil;
    }

    self.debugMessages = [NSMutableArray arrayWithCapacity:256];

    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
}

- (void)addDebugMessage:(NSString *)message;
{
    [self.debugMessages addObject:message];
    [self.tableView noteNumberOfRowsChanged];

    static NSDictionary *attributes;
    if (!attributes) {
        attributes = [[self.tableColumn.dataCell attributedStringValue] attributesAtIndex:0 effectiveRange:NULL];
    }
    CGFloat messageWidth = [message sizeWithAttributes:attributes].width + 2.0f;
    if (messageWidth > self.tableColumn.width) {
        [self.tableColumn setWidth:messageWidth];
    }
}

# pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
{
    return [self.debugMessages count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
{
    return self.debugMessages[row];
}

@end
