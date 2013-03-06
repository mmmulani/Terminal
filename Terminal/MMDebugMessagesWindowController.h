//
//  MMDebugMessagesWindowController.h
//  Terminal
//
//  Created by Mehdi Mulani on 2/21/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MMDebugMessagesWindowController : NSWindowController

@property (strong) IBOutlet NSScrollView *debugScrollView;
@property (strong) IBOutlet NSTextView *debugOutput;

- (void)addDebugMessage:(NSString *)message;

@end
