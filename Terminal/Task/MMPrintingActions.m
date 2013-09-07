//
//  MMPrintingActions.m
//  Terminal
//
//  Created by Mehdi Mulani on 6/30/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMPrintingActions.h"

#import "NSString+MMAdditions.h"

@implementation MMInsertCharacters

+ (NSArray *)_defaultArguments { return @[@1]; }

- (void)do;
{
  // This is the Insert Character (ICH) escape sequence and it is invoked by "\033[<number>@".
  // It inserts spaces at the cursor, shifting the text at the cursor to the right. Any text that would be shifted beyond the right margin should be truncated.
  // Though xterm and Terminal.app handle the shifting and truncating differently, the VT520 manual specifically states this behaviour.

  if (!self.delegate.isCursorInScrollRegion) {
    return;
  }

  NSInteger spacesToInsert = MIN(self.delegate.termWidth - MIN(self.delegate.termWidth, self.delegate.cursorPositionX) + 1, MAX(1, [[self defaultedArgumentAtIndex:0] integerValue]));
  NSInteger charactersToRemove = MAX(0, [self.delegate numberOfCharactersInScrollRow:self.delegate.cursorPositionY] + spacesToInsert - self.delegate.termWidth);

  [self.delegate removeCharactersInScrollRow:self.delegate.cursorPositionY range:NSMakeRange(self.delegate.cursorPositionX, charactersToRemove) shiftCharactersAfter:YES];
  [self.delegate insertCharactersAtScrollRow:self.delegate.cursorPositionY scrollColumn:self.delegate.cursorPositionX text:[@" " repeatedTimes:spacesToInsert]];
}

@end

@implementation MMANSIPrint

- (void)do;
{
  NSAssert(self.arguments.count == 1, @"Must be provided a string to print");

  NSString *string = self.arguments[0];
  [self.delegate fillCurrentScreenWithSpacesUpToCursor];

  string = [self.delegate convertStringForCurrentKeyboard:string];

  // If we are not in autowrap mode, we only print the characters that will fit on the current line.
  // Furthermore, as per the vt100 wrapping glitch (at http://invisible-island.net/xterm/xterm.faq.html#vt100_wrapping), we only print the "head" of the content to be outputted.
  if (![self.delegate isDECPrivateModeSet:MMDECModeAutoWrap] && string.length > (self.delegate.termWidth - self.delegate.cursorPositionX + 1)) {
    [self.delegate setCursorToX:MIN(self.delegate.termWidth, self.delegate.cursorPositionX) Y:self.delegate.cursorPositionY];
    NSString *charactersToInsertFromHead = [string substringWithRange:NSMakeRange(0, self.delegate.termWidth - self.delegate.cursorPositionX + 1)];
    string = charactersToInsertFromHead;
  }

  NSInteger i = 0;
  while (i < string.length) {
    if (self.delegate.cursorPositionX == self.delegate.termWidth + 1) {
      // If there is a newline present at the end of this line, we clear it as the text will now flow to the next line.
      [self.delegate setScrollRow:self.delegate.cursorPositionY hasNewline:NO];
      [self.delegate setCursorToX:1 Y:(self.delegate.cursorPositionY + 1)];
      [self.delegate checkIfExceededLastLineAndObeyScrollMargin:YES];
    }

    NSInteger lengthToPrintOnLine = MIN(string.length - i, self.delegate.termWidth - self.delegate.cursorPositionX + 1);

    NSInteger numberOfCharactersToDelete = MIN(lengthToPrintOnLine, [self.delegate numberOfCharactersInScrollRow:self.delegate.cursorPositionY] - self.delegate.cursorPositionX + 1);
    [self.delegate removeCharactersInScrollRow:self.delegate.cursorPositionY range:NSMakeRange(self.delegate.cursorPositionX, numberOfCharactersToDelete) shiftCharactersAfter:YES];

    [self.delegate insertCharactersAtScrollRow:self.delegate.cursorPositionY scrollColumn:self.delegate.cursorPositionX text:[string substringWithRange:NSMakeRange(i, lengthToPrintOnLine)]];

    [self.delegate setCursorToX:(self.delegate.cursorPositionX + lengthToPrintOnLine) Y:self.delegate.cursorPositionY];

    i += lengthToPrintOnLine;
  }
}

@end
