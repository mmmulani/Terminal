//
//  MMLineManipulationActions.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/22/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMLineManipulationActions.h"

@implementation MMInsertBlankLines

+ (NSArray *)_defaultArguments { return @[@1]; }

- (void)do;
{
    if (!self.delegate.isCursorInScrollRegion) {
        return;
    }

    // Three step process:
    // 1. Remove any lines that should be scrolled below the bottom margin.
    // 2. Insert |numberOfLinesToInsert| blank lines starting at the cursor.
    // 3. Move the cursor to the correct spot.
    NSInteger numberOfLinesToInsert = MIN(MAX(1, [[self defaultedArgumentAtIndex:0] integerValue]), self.delegate.scrollMarginBottom - self.delegate.cursorPositionY + 1);

    // Step 1.
    NSInteger numberOfLinesToDelete = MAX(0, MIN([self.delegate numberOfRowsOnScreen], self.delegate.scrollMarginBottom) + numberOfLinesToInsert - self.delegate.scrollMarginBottom);
    for (NSInteger i = 0; i < numberOfLinesToDelete; i++) {
        [self.delegate removeLineAtScrollRow:(self.delegate.scrollMarginBottom - i)];
    }

    // Step 2.
    // We either insert a completely blank line or a line ending with a newline character.
    // We insert a completely blank line if there is content after the lines to be inserted.
    BOOL fillWithNewlines =
        (self.delegate.cursorPositionY + numberOfLinesToInsert < self.delegate.numberOfRowsOnScreen) &&
        ([self.delegate numberOfCharactersInScrollRow:(self.delegate.cursorPositionY + numberOfLinesToInsert)] > 0 ||
         [self.delegate isScrollRowTerminatedInNewline:(self.delegate.cursorPositionY + numberOfLinesToInsert)]);
    for (NSInteger i = 0; i < numberOfLinesToInsert; i++) {
        [self.delegate insertBlankLineAtScrollRow:self.delegate.cursorPositionY withNewline:fillWithNewlines];
    }

    if (self.delegate.numberOfRowsOnScreen == self.delegate.termHeight) {
        [self.delegate setScrollRow:self.delegate.termHeight hasNewline:NO];
    }

    // Step 3.
    [self.delegate setCursorToX:1 Y:self.delegate.cursorPositionY];
}

@end

@implementation MMDeleteLines

+ (NSArray *)_defaultArguments { return @[@1]; }

- (void)do;
{
    // This is called the Delete Line (DL) sequence. It has the escape sequence: ESC[(0-9)*M
    // It is only handled when the cursor is within the scroll region.
    if (!self.delegate.isCursorInScrollRegion) {
        return;
    }
    NSInteger numberOfLinesToDelete = MIN(MAX(1, [[self defaultedArgumentAtIndex:0] integerValue]), self.delegate.scrollMarginBottom - self.delegate.cursorPositionY + 1);

    for (NSInteger i = 0; i < numberOfLinesToDelete; i++) {
        [self.delegate removeLineAtScrollRow:self.delegate.cursorPositionY];
    }

    NSInteger newLineScrollRow = MIN(self.delegate.scrollMarginBottom - numberOfLinesToDelete, self.delegate.numberOfRowsOnScreen) + 1;
    BOOL fillWithNewlines =
        (self.delegate.cursorPositionY + numberOfLinesToDelete <= self.delegate.numberOfRowsOnScreen) &&
         ([self.delegate numberOfCharactersInScrollRow:(self.delegate.cursorPositionY + numberOfLinesToDelete)] > 0 ||
          [self.delegate isScrollRowTerminatedInNewline:(self.delegate.cursorPositionY + numberOfLinesToDelete)]);
    for (NSInteger i = 0; i < numberOfLinesToDelete; i++) {
        [self.delegate insertBlankLineAtScrollRow:newLineScrollRow withNewline:fillWithNewlines];
    }

    if (self.delegate.numberOfRowsOnScreen == self.delegate.termHeight) {
        [self.delegate setScrollRow:self.delegate.termHeight hasNewline:NO];
    }

    [self.delegate setCursorToX:1 Y:self.delegate.cursorPositionY];
}

@end
