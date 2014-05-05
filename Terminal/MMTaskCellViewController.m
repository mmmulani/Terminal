//
//  MMTaskCellViewController.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/19/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMTaskCellViewController.h"
#import "MMTerminalWindowController.h"

@interface MMTaskCellViewController ()

@end

@implementation MMTaskCellViewController

- (id)init;
{
  self = [self initWithNibName:@"MMTaskCellView" bundle:[NSBundle mainBundle]];
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

    [self.view addSubview:self.imageView];
    [self.view addSubview:self.spinningIndicator];

    if (self.task.shellCommand) {
        [self.outputView.enclosingScrollView removeFromSuperview];
        self.outputView = nil;
        [self updateViewForShellCommand];
        
        BOOL isCd = [[[self.task.commandGroups[0] commands][0] arguments][0] isEqualToString:@"cd"];
        if (!isCd) {
            [self.view addSubview:self.catImageView];
        }
    } else {
      [self.label setStringValue:[NSString stringWithFormat:@"Running %@", self.task.command]];
    }
  }

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(labelFrameChanged:) name:NSViewFrameDidChangeNotification object:self.label];
}

- (void)dealloc;
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context;
{
  if ([keyPath isEqualToString:@"firstResponder"]) {
    if ([self.windowController.window.firstResponder isEqual:self.outputView]) {
      [self.spinningIndicator stopAnimation:nil];
      [self.spinningIndicator setHidden:YES];
    } else {
      [self.spinningIndicator startAnimation:nil];
      [self.spinningIndicator setHidden:NO];
    }
  }
}

- (void)labelFrameChanged:(NSNotification *)notification;
{
  [self.imageView setFrameOrigin:NSMakePoint(self.label.frame.origin.x + self.label.intrinsicContentSize.width + 10, self.label.frame.origin.y)];
  [self.spinningIndicator setFrameOrigin:self.imageView.frame.origin];
}

- (void)scrollOutputToBottom
{
  // TODO: Add a check to see if we are already scrolled to the bottom, and only scroll down then.
  // XXX: This is a hack to scroll the text by farther than it should go, to give the appearance of a full terminal screen.
  // In the future, we should move it to the scroll view, so that the scroll bar still works.
  CGFloat extraScroll = 0;
  if (self.task.shouldDrawFullTerminalScreen && self.outputView.superview.frame.size.height < self.outputView.frame.size.height) {
    NSInteger numberOfRowsWithText;
    for (numberOfRowsWithText = 1; numberOfRowsWithText <= self.task.numberOfRowsOnScreen; numberOfRowsWithText++) {
      if ([self.task numberOfCharactersInScrollRow:numberOfRowsWithText] == 0 && ![self.task isScrollRowTerminatedInNewline:numberOfRowsWithText]) {
        numberOfRowsWithText--;
        break;
      }
    }
    numberOfRowsWithText = MIN(self.task.numberOfRowsOnScreen, numberOfRowsWithText);
    extraScroll = (self.task.termHeight - numberOfRowsWithText) * 15;
  }

  NSRect clipViewFrame = self.outputView.superview.frame;
  CGFloat scrollY = self.outputView.frame.size.height - clipViewFrame.size.height + extraScroll;
  if (ABS(self.outputView.enclosingScrollView.contentView.bounds.origin.y - scrollY) > 1) {
    [((NSClipView *)self.outputView.superview) scrollToPoint:NSMakePoint(0, scrollY)];
  }
}

- (CGFloat)heightToFitAllOfOutput;
{
    if (self.task.isShellCommand) {
        if (self.catImageView.image) {
            return self.catImageView.image.size.height + 80.0;
        }
        
        return 55.0;
    }

    CGFloat textHeight = 0.0f;
    if (self.task.shouldDrawFullTerminalScreen) {
        // We let the default maximum later take over, rather than calculate a max height.
        textHeight = 9999.0f;
    } else {
        NSAttributedString *output = [self.outputView.textStorage attributedSubstringFromRange:NSMakeRange(0, self.outputView.textStorage.length)];

        NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:output];
        NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(self.view.frame.size.width - 40, FLT_MAX)];
        NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
        [layoutManager addTextContainer:textContainer];
        [textStorage addLayoutManager:layoutManager];
        [layoutManager glyphRangeForTextContainer:textContainer];
        textHeight = [layoutManager usedRectForTextContainer:textContainer].size.height + 2.0; // + 2.0 for padding.
    }

    // When drawing the whole screen, we use 64 points for the chrome and 15 points for each line of text.
    CGFloat heightForWholeScreen = 64.0 + 15.0 * self.task.termHeight;

    CGFloat height = MIN(64 + textHeight, heightForWholeScreen);
    return height;
}

- (void)updateWithANSIOutput;
{
  NSUInteger cursorPositionByCharacters = self.task.cursorPositionByCharacters;

  [self.outputView setSelectedRange:NSMakeRange(cursorPositionByCharacters, 0)];

  if (self.task.isFinished) {
    NSImage *imageToDisplay;
    NSString *toolTip;
    if (self.task.finishStatus == MMProcessStatusExit) {
      if (self.task.finishCode == 0) {
        imageToDisplay = [[NSBundle mainBundle] imageForResource:@"glyphiconsOK.png"];
      } else {
        imageToDisplay = [[NSBundle mainBundle] imageForResource:@"glyphiconsWarning.png"];
        toolTip = [NSString stringWithFormat:@"Exited with code %ld", self.task.finishCode];
      }
    } else if (self.task.finishStatus == MMProcessStatusSignal) {
      imageToDisplay = [[NSBundle mainBundle] imageForResource:@"glyphiconsX.png"];
      toolTip = [NSString stringWithFormat:@"Stopped by signal %ld", self.task.finishCode];
    }
    self.imageView.image = imageToDisplay;
    self.imageView.toolTip = toolTip;
  }
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
  BOOL isCd = [[[self.task.commandGroups[0] commands][0] arguments][0] isEqualToString:@"cd"];
  if (isCd) {
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
  } else {
    self.label.stringValue = [NSString stringWithFormat:@"Ran cat_ %@", self.task.shellCommandAttachment[@"image"]];

    // Image cat.
    NSString *imageString = self.task.shellCommandAttachment[@"content"];
    NSMutableData *imageData = [NSMutableData dataWithCapacity:(imageString.length / 2)];
    for (NSInteger i = 0; i < imageString.length; i += 2) {
      unichar first = [imageString characterAtIndex:i];
      unichar second = [imageString characterAtIndex:(i + 1)];
      NSInteger value = first >= 'a' ? first - 'a' + 10 : first - '0';
      NSInteger secondValue = second >= 'a' ? second - 'a' + 10 : second - '0';

      NSInteger totalValue = (value * 16) + secondValue;
      [imageData appendBytes:&totalValue length:1];
    }
    self.catImageView.image = [[NSImage alloc] initWithData:imageData];
    [self.catImageView setFrame:NSMakeRect(20, -(self.catImageView.image.size.height) + 10, self.catImageView.image.size.width, self.catImageView.image.size.height)];
  }
}

- (void)resizeTerminalToColumns:(NSInteger)columns rows:(NSInteger)rows;
{
  [self.task resizeTerminalToColumns:columns rows:rows];
}

# pragma mark - MMTextViewDelegate methods

- (void)handleKeyPress:(NSEvent *)keyEvent;
{
  // Special case the arrow keys.
  if ([keyEvent keyCode] >= 123 && [keyEvent keyCode] <= 126) {
    static MMArrowKey map[] = { MMArrowKeyLeft, MMArrowKeyRight, MMArrowKeyDown, MMArrowKeyUp };
    [self.task handleCursorKeyInput:map[[keyEvent keyCode] - 123]];
  } else if ([[keyEvent charactersIgnoringModifiers].uppercaseString isEqualToString:@"Z"] &&
             ([keyEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask & ~NSShiftKeyMask) == NSControlKeyMask) { // CTRL + Z
    [self taskMovedToBackground:self.task];
  } else {
    [self.task handleUserInput:[keyEvent characters]];
  }
}

- (void)handleInput:(NSString *)input;
{
  [self.task handleUserInput:input];
}

# pragma mark - MMTaskDelegate

- (void)taskStarted:(MMTask *)task;
{
  [self.windowController taskStarted:self];

  [self.spinningIndicator startAnimation:nil];
  [self.windowController.window addObserver:self forKeyPath:@"firstResponder" options:NSKeyValueObservingOptionInitial context:NULL];
}

- (void)taskFinished:(MMTask *)task;
{
  if (self.task.isShellCommand) {
    [self updateViewForShellCommand];
  } else {
    [self.label setStringValue:[NSString stringWithFormat:@"Ran %@", self.task.command]];
    [self labelFrameChanged:nil];

    [self updateWithANSIOutput];
  }

  [[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:self.outputView];

  [self.windowController taskFinished:self];

  [self.windowController noteHeightChangeForTask:self];

  [self.windowController.window removeObserver:self forKeyPath:@"firstResponder"];
  [self.spinningIndicator removeFromSuperview];
}

- (void)taskMovedToBackground:(MMTask *)task;
{
  self.backgrounded = YES;
  [self.windowController taskRunsInBackground:self];
}

- (void)taskReceivedOutput:(MMTask *)task;
{
  [self updateWithANSIOutput];

  [self.windowController noteHeightChangeForTask:self];
  [self scrollOutputToBottom];
}

@end
