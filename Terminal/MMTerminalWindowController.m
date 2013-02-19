//
//  MMTerminalWindowController.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/18/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMTerminalWindowController.h"
#import "MMAppDelegate.h"

@interface MMTerminalWindowController ()

@end

@implementation MMTerminalWindowController

- (id)init;
{
    self = [self initWithWindowNibName:@"MMTerminalWindow"];

    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [self.consoleText setNextResponder:self.window];

    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (void)handleOutput:(NSString *)message;
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAttributedString *attribData = [[NSAttributedString alloc] initWithString:message];
        NSTextStorage *textStorage = [self.consoleText textStorage];
        [textStorage beginEditing];
        [textStorage appendAttributedString:attribData];
        [textStorage endEditing];
        [self.consoleText didChangeText];
        [self.consoleText scrollToEndOfDocument:self];
    });
}

- (void)processFinished;
{
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
        [appDelegate runCommand:textView.string];
        [textView setString:@""];
        [self.window makeFirstResponder:self.consoleText];
        return YES;
    }

    return NO;
}

@end
