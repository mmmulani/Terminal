//
//  MMTaskCellViewController.h
//  Terminal
//
//  Created by Mehdi Mulani on 2/19/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MMTask.h"

@interface MMTaskCellViewController : NSViewController

@property (strong) IBOutlet NSTextField *label;
@property (strong) IBOutlet NSTextView *output;

@property (strong) MMTask *task;

- (id)initWithTask:(MMTask *)task;

@end
