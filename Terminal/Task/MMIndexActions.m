//
//  MMIndexActions.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/22/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMIndexActions.h"

@implementation MMIndex

- (void)do;
{
  // This corresponds to ESC D and is called IND.
  // This escape sequence moves the cursor down by one line and if it passes the bottom, scrolls down.
  NSInteger newXPosition = self.delegate.cursorPositionX == self.delegate.termWidth + 1 ? 1 : self.delegate.cursorPositionX;
  [self.delegate setCursorToX:newXPosition Y:(self.delegate.cursorPositionY + 1)];
  [self.delegate checkIfExceededLastLineAndObeyScrollMargin:YES];
  [self.delegate createBlankLinesUpToCursor];
}

@end

@implementation MMReverseIndex

- (void)do;
{
  // This corresponds to ESC M and is called RI.
  // This escape sequence moves the cursor up by one line and if it passes the top margin, scrolls up.
  // When we scroll up, we remove a newline from the last line if it exists.
  if (self.delegate.cursorPositionY == self.delegate.scrollMarginTop) {
    if ([self.delegate numberOfRowsOnScreen] >= self.delegate.scrollMarginBottom) {
      [self.delegate setScrollRow:(self.delegate.termHeight - 1) hasNewline:NO];
      [self.delegate removeLineAtScrollRow:self.delegate.scrollMarginBottom];
    }
    [self.delegate insertBlankLineAtScrollRow:self.delegate.scrollMarginTop withNewline:YES];
  } else {
    [self.delegate setCursorToX:self.delegate.cursorPositionX Y:MAX(1, self.delegate.cursorPositionY - 1)];
  }
}

@end

@implementation MMNextLine

- (void)do;
{
  // This corresponds to ESC E and is called NEL.
  // This moves the cursor down by one line and to the front of the line.
  // If it passes the bottom margin, it scrolls down.
  // However, if it passes the bottom of the screen but the bottom of the screen is not the scroll margin, it does not scroll down.
  if (self.delegate.cursorPositionY == self.delegate.scrollMarginBottom) {
    [self.delegate setCursorToX:1 Y:(self.delegate.cursorPositionY + 1)];
    [self.delegate checkIfExceededLastLineAndObeyScrollMargin:YES];
  } else {
    [self.delegate setCursorToX:1 Y:MIN(self.delegate.termHeight, self.delegate.cursorPositionY + 1)];
  }
}

@end