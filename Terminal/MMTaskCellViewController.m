//
//  MMTaskCellViewController.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/19/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMTaskCellViewController.h"

@interface MMTaskCellViewController ()

@end

@implementation MMTaskCellViewController

- (id)init;
{
    self = [self initWithNibName:@"MMTaskCellView" bundle:[NSBundle mainBundle]];
    return self;
}

- (id)initWithTask:(MMTask *)task;
{
    self = [self init];
    if (!self) {
        return nil;
    }

    self.task = task;

    return self;
}

- (void)loadView;
{
    [super loadView];

    [self.label setStringValue:[NSString stringWithFormat:@"Ran %@", self.task.command]];

    [self.outputView.layoutManager replaceTextStorage:self.task.output];
    [self.outputView scrollToEndOfDocument:self];
}

- (void)scrollToBottom;
{
    [self.outputView scrollToEndOfDocument:self];
}

@end
