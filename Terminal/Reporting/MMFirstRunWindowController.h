//
//  MMFirstRunWindowController.h
//  Terminal
//
//  Created by Mehdi Mulani on 5/30/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MMFirstRunWindowController : NSWindowController

@property (strong) IBOutlet NSTextField *restoreWindowsWarning;

- (IBAction)donePressed:(id)sender;

@end
