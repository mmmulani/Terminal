//
//  MMDebugMessagesWindowController.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/21/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMDebugMessagesWindowController.h"
#import "MMAppDelegate.h"
#import "MMTerminalConnection.h"

@interface MMDebugMessagesWindowController ()

@end

@implementation MMDebugMessagesWindowController

- (id)init;
{
  self = [self initWithWindowNibName:@"MMDebugMessagesPanel"];
  if (!self) {
    return nil;
  }

  return self;
}

- (void)windowDidLoad
{
  [super windowDidLoad];

  [self.debugOutput.layoutManager replaceTextStorage:[[NSApp delegate] debugMessages]];

  [self.window setLevel:NSNormalWindowLevel];
}

- (void)updateOutput;
{
  CGFloat distanceFromBottom = [(NSView *)self.debugScrollView.documentView frame].size.height - (self.debugScrollView.contentView.bounds.origin.y + self.debugScrollView.contentView.bounds.size.height);

  if (distanceFromBottom < 0.5) {
    [self.debugOutput scrollToEndOfDocument:self];
  }
}

@end
