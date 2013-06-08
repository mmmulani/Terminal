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

    if (self.task.shellCommand) {
        [self.outputView.enclosingScrollView removeFromSuperview];
        self.outputView = nil;
        [self updateViewForShellCommand];
    } else {
        if (self.task.displayTextStorage) {
            [self.outputView.layoutManager replaceTextStorage:self.task.displayTextStorage];
        }

        [self.label setStringValue:[NSString stringWithFormat:@"Ran %@", self.task.command]];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(outputFrameChanged:) name:NSViewFrameDidChangeNotification object:self.outputView];
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)outputFrameChanged:(NSNotification *)notification;
{
    // TODO: Add a check to see if we are already scrolled to the bottom, and only scroll down then.
    NSRect clipViewFrame = self.outputView.superview.frame;
    [((NSClipView *)self.outputView.superview) scrollToPoint:NSMakePoint(0, self.outputView.frame.size.height - clipViewFrame.size.height)];
}

- (CGFloat)heightToFitAllOfOutput;
{
    if (self.task.isShellCommand) {
        return 55.0;
    }

    CGFloat textHeight = 0.0f;
    if (self.task.shouldDrawFullTerminalScreen) {
        // We let the default maximum later take over, rather than calculate a max height.
        textHeight = 999.0f;
    } else {
        NSAttributedString *output = [self.outputView.textStorage attributedSubstringFromRange:NSMakeRange(0, self.outputView.textStorage.length)];

        NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:output];
        NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(self.outputView.textContainer.containerSize.width, FLT_MAX)];
        NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
        [layoutManager addTextContainer:textContainer];
        [textStorage addLayoutManager:layoutManager];
        [layoutManager glyphRangeForTextContainer:textContainer];
        textHeight = [layoutManager usedRectForTextContainer:textContainer].size.height + 2.0; // + 2.0 for padding.
    }

    NSScrollView *textScrollView = (NSScrollView *)self.outputView.superview.superview;
    return MIN(self.view.frame.size.height - textScrollView.frame.size.height + textHeight, 424.0f);
}

- (void)updateWithANSIOutput;
{
    NSUInteger cursorPositionByCharacters = self.task.cursorPositionByCharacters;

    [self.outputView setSelectedRange:NSMakeRange(cursorPositionByCharacters, 0)];

    // Sometimes the NSViewFrameDidChangeNotification does not get issued, so we call it here to make sure that it gets sent.
    [self outputFrameChanged:nil];
}

- (IBAction)saveTranscript:(id)sender;
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setAllowedFileTypes:@[@"output"]];
    [savePanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result) {
        if (result != NSFileHandlingPanelOKButton) {
            return;
        }

        [self.task.output writeToURL:savePanel.URL atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }];
}

- (void)updateViewForShellCommand;
{
    // TODO: Handle other types of shell commands.
    if (!self.task.shellCommandAttachment) {
        return;
    }

    NSString *displayText;
    if (self.task.shellCommandSuccessful) {
        displayText = [NSString stringWithFormat:@"Changed directory to %@", self.task.shellCommandAttachment];
        self.label.textColor = [NSColor grayColor];
    } else {
        displayText = [NSString stringWithFormat:@"Unable to change directory to %@", self.task.shellCommandAttachment];
        self.label.textColor = [NSColor redColor];
    }
    self.label.stringValue = displayText;
    self.label.alignment = NSCenterTextAlignment;
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

- (void)handleInput:(NSString *)input;
{
    [self.task handleUserInput:input];
}

@end
