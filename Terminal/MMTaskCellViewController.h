//
//  MMTaskCellViewController.h
//  Terminal
//
//  Created by Mehdi Mulani on 2/19/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MMTask.h"
#import "MMTextView.h"

@interface MMTaskCellViewController : NSViewController <MMTextViewDelegate>

@property (strong) IBOutlet NSTextField *label;
@property (strong) IBOutlet MMTextView *outputView;

@property (strong) MMTask *task;

- (id)initWithTask:(MMTask *)task;
- (void)scrollToBottom;
- (CGFloat)heightToFitAllOfOutput;
- (void)updateWithANSIOutput;
- (IBAction)saveTranscript:(id)sender;

- (void)handleKeyPress:(NSEvent *)keyEvent;

@end
