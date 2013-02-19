//
//  MMTerminalWindowController.h
//  Terminal
//
//  Created by Mehdi Mulani on 2/18/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MMTextView.h"

@interface MMTerminalWindowController : NSWindowController

@property (retain) IBOutlet MMTextView *consoleText;
@property (retain) IBOutlet NSTextField *commandInput;

@end
