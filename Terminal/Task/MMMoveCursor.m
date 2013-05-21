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
    // Comparing it to TERM_WIDTH handles the case where the cursor is pas`t the right margin (which occurs when we right a character at the right margin).
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

    NSInteger newPositionY = MIN(self.delegate.cursorPositionY + lines, self.delegate.termHeight + 1);
    [self.delegate setCursorToX:self.delegate.cursorPositionX Y:newPositionY];

    [self.delegate checkIfExceededLastLineAndObeyScrollMargin:NO];
}

@end

@implementation MMMoveCursorForward

+ (NSArray *)_defaultArguments { return @[@1]; }

- (void)do;
{
    // Unlike the control command to move the cursor backwards, this does not have to deal with wrapping around the margin.
    NSInteger spaces = MAX([[self defaultedArgumentAtIndex:0] integerValue], 1);

    [self.delegate setCursorToX:MIN(self.delegate.termWidth, self.delegate.cursorPositionX + spaces) Y:self.delegate.cursorPositionY];
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

        if (newPositionY == 1 || [self.delegate ansiCharacterAtScrollRow:(newPositionY - 2) column:self.delegate.termWidth] == '\n') {
            spaces = 0;
        } else if (spaces > 0) {
            newPositionY--;
            newPositionX = self.delegate.termWidth + 1;
        }
    }

    [self.delegate setCursorToX:newPositionX Y:newPositionY];
}

@end
