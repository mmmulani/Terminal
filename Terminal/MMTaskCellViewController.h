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

@interface MMTaskCellViewController : NSViewController <MMTextViewDelegate, MMTaskDelegate>

@property (strong) IBOutlet NSTextField *label;
@property (strong) IBOutlet MMTextView *outputView;
@property (strong) IBOutlet NSImageView *imageView;

@property (strong) MMTask *task;

- (id)initWithTask:(MMTask *)task;
- (CGFloat)heightToFitAllOfOutput;
- (void)updateWithANSIOutput;
- (IBAction)saveTranscript:(id)sender;
- (void)updateViewForShellCommand;
- (void)resizeTerminalToColumns:(NSInteger)columns rows:(NSInteger)rows;

@end
