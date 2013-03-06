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

    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [self.window setLevel:NSNormalWindowLevel];
}

- (void)addDebugMessage:(NSString *)message;
{
    CGFloat distanceFromBottom = [(NSView *)self.debugScrollView.documentView frame].size.height - (self.debugScrollView.contentView.bounds.origin.y + self.debugScrollView.contentView.bounds.size.height);

    NSString *messageWithNewline = [message stringByAppendingString:@"\n"];

    static NSDictionary *attributes = nil;
    if (!attributes) {
        NSFont *font = [NSFont fontWithName:@"Lucida Console" size:12.0f];
        attributes =
        @{
          NSFontAttributeName: font,
          };
    }

    [self.debugOutput.textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:messageWithNewline attributes:attributes]];

    if (distanceFromBottom < 0.5) {
        [self.debugOutput scrollToEndOfDocument:self];
    }
}

@end
