//
//  MMTaskCellViewController.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/19/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMTaskCellViewController.h"
#import "MMAppDelegate.h"

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

    [self.outputView scrollToEndOfDocument:self];
}

- (CGFloat)heightToFitAllOfOutput;
{
    return MIN(self.view.frame.size.height - self.outputView.minSize.height + self.outputView.frame.size.height, 425.0f);
}

- (void)scrollToBottom;
{
    [self.outputView scrollToEndOfDocument:self];
}

- (void)updateWithANSIOutput;
{
    NSMutableAttributedString *displayString = self.task.currentANSIDisplay;
    NSUInteger cursorPositionByCharacters = self.task.cursorPositionByCharacters;

    // If the process has finished, we remove a trailing newline if it exists.
    if (self.task.finishedAt) {
        if (displayString.length && [displayString.mutableString characterAtIndex:(displayString.length - 1)] == '\n') {
            if (cursorPositionByCharacters == displayString.length) {
                cursorPositionByCharacters--;
            }
            [displayString replaceCharactersInRange:NSMakeRange(displayString.length - 1, 1) withString:@""];
        }
    }

    static NSDictionary *attributes = nil;
    if (!attributes) {
        NSFont *font = [NSFont userFixedPitchFontOfSize:[NSFont systemFontSize]];
        attributes =
        @{
          NSFontAttributeName: font,
          };
    }
    [displayString setAttributes:attributes range:NSMakeRange(0, displayString.length)];

    [self.outputView.textStorage setAttributedString:displayString];
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [style setLineBreakMode:NSLineBreakByCharWrapping];
    [self.outputView.textStorage addAttribute:NSParagraphStyleAttributeName value:style range:NSMakeRange(0, [self.outputView.textStorage length])];
    [self.outputView setSelectedRange:NSMakeRange(cursorPositionByCharacters, 0)];
}

- (IBAction)saveTranscript:(id)sender;
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setAllowedFileTypes:@[@"output"]];
    [savePanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result) {
        if (result != NSFileHandlingPanelOKButton) {
            return;
        }

        [self.task.output.string writeToURL:savePanel.URL atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }];
}

# pragma mark - MMTextViewDelegate methods

- (void)handleKeyPress:(NSEvent *)keyEvent;
{
    // Special case the arrow keys.
    if ([keyEvent keyCode] >= 123 && [keyEvent keyCode] <= 126) {
        static MMArrowKey map[] = { MMArrowKeyLeft, MMArrowKeyRight, MMArrowKeyDown, MMArrowKeyUp };
        [self.task handleCursorKeyInput:map[[keyEvent keyCode] - 123]];
    } else {
        [self.task handleUserInput:[keyEvent characters]];
    }
}

@end
