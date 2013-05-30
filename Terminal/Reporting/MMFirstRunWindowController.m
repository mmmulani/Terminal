//
//  MMFirstRunWindowController.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/30/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMFirstRunWindowController.h"

@implementation MMFirstRunWindowController

- (id)init;
{
    self = [self initWithWindowNibName:@"MMFirstRunWindowController"];
    if (!self) {
        return nil;
    }

    return self;
}

- (IBAction)donePressed:(id)sender;
{
    [self close];

    [[NSApp delegate] applicationDidFinishLaunching:nil];
}

@end
