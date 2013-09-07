//
//  MMTabAction.m
//  Terminal
//
//  Created by Mehdi Mulani on 6/4/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMTabAction.h"

@implementation MMTabAction

- (void)do;
{
  NSInteger adjustedPositionX = MIN(self.delegate.cursorPositionX, self.delegate.termWidth);
  NSInteger positionAfterTab = (self.delegate.cursorPositionX + 7) / 8 * 8 + 1;
  if (!([self.delegate isColumnWithinTab:adjustedPositionX inScrollRow:self.delegate.cursorPositionY] ||
        [self.delegate numberOfCharactersInScrollRow:self.delegate.cursorPositionY] >= adjustedPositionX)) {
    NSInteger startOfTab = MAX(adjustedPositionX, [self.delegate numberOfCharactersInScrollRow:self.delegate.cursorPositionY] + 1);
    [self.delegate addTab:NSMakeRange(startOfTab, positionAfterTab - startOfTab) onScrollRow:self.delegate.cursorPositionY];
  }

  [self.delegate setCursorToX:MIN(self.delegate.termWidth, positionAfterTab) Y:self.delegate.cursorPositionY];
}

@end
