//
//  MMTerminalWindowController.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/18/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMTerminalWindowController.h"
#import "MMAppDelegate.h"
#import "MMTask.h"
#import "MMTaskCellViewController.h"

@interface MMTerminalWindowController ()

@end

@implementation MMTerminalWindowController

- (id)init;
{
    self = [self initWithWindowNibName:@"MMTerminalWindow"];

    self.tasks = [NSMutableArray array];

    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [self.consoleText setNextResponder:self.window];
}

- (void)handleOutput:(NSString *)message;
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAttributedString *attribData = [[NSAttributedString alloc] initWithString:message];
        MMTask *lastTask = [self.tasks lastObject];
        [lastTask.output appendAttributedString:attribData];

        [self.tableView reloadData];
    });
}

- (void)processFinished;
{
    MMTask *task = [self.tasks lastObject];
    task.finishedAt = [NSDate date];
    self.running = NO;

    [self.window makeFirstResponder:self.commandInput];
}

# pragma mark - NSTextFieldDelegate

- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor;
{
    if (self.running) {
        [self.window makeFirstResponder:self.consoleText];
    }
    return !self.running;
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector;
{
    if (commandSelector == @selector(insertNewline:)) {
        MMAppDelegate *appDelegate = (MMAppDelegate *)[[NSApplication sharedApplication] delegate];
        MMTask *newTask = [MMTask new];
        newTask.command = textView.string;
        newTask.startedAt = [NSDate date];
        [self.tasks addObject:newTask];
        [appDelegate runCommand:newTask.command];
        [textView setString:@""];
        [self.window makeFirstResponder:self.consoleText];
        return YES;
    }

    return NO;
}

# pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
{
    return [self.tasks count];
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row;
{
    return 100.0f;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
{
    MMTaskCellViewController *cellViewController = [[MMTaskCellViewController alloc] initWithTask:self.tasks[row]];
    return [cellViewController view];
}

@end
