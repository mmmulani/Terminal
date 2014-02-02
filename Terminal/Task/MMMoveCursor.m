//
//  MMMoveCursor.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/21/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMMoveCursor.h"

@implementation MMMoveCursorUp

+ (NSArray *)_defaultArguments { return @[@1]; }

- (void)do;
{
  NSInteger lines = MAX([[self defaultedArgumentAtIndex:0] integerValue], 1);
  // Comparing it to the terminal width handles the case where the cursor is past the right margin (which occurs when we right a character at the right margin).
  NSInteger newPositionX = MIN(self.delegate.cursorPositionX, self.delegate.termWidth);
  if (lines >= self.delegate.cursorPositionY) {
    newPositionX = 1;
  }
  NSInteger newPositionY = MAX(1, self.delegate.cursorPositionY - lines);

  [self.delegate setCursorToX:newPositionX Y:newPositionY];
}

@end

@implementation MMMoveCursorDown

+ (NSArray *)_defaultArguments { return @[@1]; }

- (void)do;
{
  NSInteger lines = MAX([[self defaultedArgumentAtIndex:0] integerValue], 1);

  NSInteger newPositionX = MIN(self.delegate.cursorPositionX, self.delegate.termWidth);
  NSInteger newPositionY = MIN(self.delegate.cursorPositionY + lines, self.delegate.termHeight);
  [self.delegate setCursorToX:newPositionX Y:newPositionY];

  [self.delegate createBlankLinesUpToCursor];
}

@end

@implementation MMMoveCursorForward

+ (NSArray *)_defaultArguments { return @[@1]; }

- (void)do;
{
  // Unlike the control command to move the cursor backwards, this does not have to deal with wrapping around the margin.
  NSInteger spaces = MAX([[self defaultedArgumentAtIndex:0] integerValue], 1);

  [self.delegate setCursorToX:MIN(self.delegate.termWidth, self.delegate.cursorPositionX + spaces) Y:self.delegate.cursorPositionY];

  [self.delegate createBlankLinesUpToCursor];
}

@end

@implementation MMMoveCursorBackward

+ (NSArray *)_defaultArguments { return @[@1]; }

- (void)do;
{
  NSInteger spaces = MAX([[self defaultedArgumentAtIndex:0] integerValue], 1);

  NSInteger newPositionX = self.delegate.cursorPositionX;
  NSInteger newPositionY = self.delegate.cursorPositionY;
  while (spaces > 0) {
    NSInteger distanceToMove = MIN(spaces, newPositionX - 1);

    newPositionX -= distanceToMove;
    spaces -= distanceToMove;

    if (newPositionY == 1 || [self.delegate isScrollRowTerminatedInNewline:(newPositionY - 1)]) {
      spaces = 0;
    } else if (spaces > 0) {
      newPositionY--;
      newPositionX = self.delegate.termWidth + 1;
    }
  }

  [self.delegate setCursorToX:newPositionX Y:newPositionY];
  [self.delegate createBlankLinesUpToCursor];
}

@end

@implementation MMBackspace

- (void)do;
{
  NSInteger adjustedPositionX = MIN(self.delegate.termWidth, self.delegate.cursorPositionX);

  if (self.delegate.cursorPositionY == 1 || adjustedPositionX > 1 || [self.delegate isScrollRowTerminatedInNewline:(self.delegate.cursorPositionY - 1)]) {
    [self.delegate setCursorToX:MAX(1, adjustedPositionX - 1) Y:self.delegate.cursorPositionY];
  } else {
    [self.delegate setCursorToX:self.delegate.termWidth Y:(self.delegate.cursorPositionY - 1)];
  }
}

@end

@implementation MMMoveCursorPosition

+ (NSArray *)_defaultArguments { return @[@1, @1]; }

- (void)do;
{
  NSInteger maxDistanceY = [self.delegate isDECPrivateModeSet:MMDECModeOrigin] ? self.delegate.scrollMarginBottom - self.delegate.scrollMarginTop + 1 : self.delegate.termHeight;
  NSInteger maxDistanceX = self.delegate.termWidth;

  // Sanitize the input.
  NSInteger x = MIN(MAX([[self defaultedArgumentAtIndex:1] integerValue], 1), maxDistanceX);
  NSInteger y = MIN(MAX([[self defaultedArgumentAtIndex:0] integerValue], 1), maxDistanceY);

  // If we are origin mode, we have to convert the inputs to an actual position.
  if ([self.delegate isDECPrivateModeSet:MMDECModeOrigin]) {
    y = self.delegate.scrollMarginTop + y - 1;
  }

  if (y <= self.delegate.cursorPositionY) {
    [self.delegate setCursorToX:x Y:y];
  } else {
    // We are guaranteed that y >= 2.
    // Add new lines as needed.
    NSInteger linesToAdd = self.delegate.termHeight - self.delegate.numberOfRowsOnScreen;
    for (NSInteger i = 0; i < linesToAdd; i++) {
      [self.delegate insertBlankLineAtScrollRow:(self.delegate.numberOfRowsOnScreen + 1) withNewline:NO];
    }

    // Add newline characters when necessary starting from the final row and moving up.
    for (NSUInteger row = y; row > 1; row--) {
      if ([self.delegate numberOfCharactersInScrollRow:row] > 0) {
        continue;
      }

      [self.delegate setScrollRow:(row - 1) hasNewline:YES];
    }

    [self.delegate setCursorToX:x Y:y];
  }
}

@end

@implementation MMMoveHorizontalAbsolute

+ (NSArray *)_defaultArguments { return @[@1]; }

- (void)do;
{
  MMANSIAction *action = [[MMMoveCursorPosition alloc] initWithArguments:[@[@(self.delegate.cursorPositionY)] arrayByAddingObjectsFromArray:self.arguments]];
  action.delegate = self.delegate;
  [action do];
}

@end

@implementation MMMoveVerticalAbsolute

+ (NSArray *)_defaultArguments { return @[@1]; }

- (void)do;
{
  MMANSIAction *action = [[MMMoveCursorPosition alloc] initWithArguments:@[[self defaultedArgumentAtIndex:0], @(self.delegate.cursorPositionX)]];
  action.delegate = self.delegate;
  [action do];
}

@end

@implementation MMCarriageReturn

-(void)do;
{
  if (self.delegate.cursorPositionX > 1) {
    MMANSIAction *action = [[MMMoveCursorBackward alloc] initWithArguments:@[@(self.delegate.cursorPositionX - 1)]];
    action.delegate = self.delegate;
    [action do];
  }
}

@end
