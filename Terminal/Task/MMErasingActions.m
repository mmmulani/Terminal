//
//  MMErasingActions.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/22/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMErasingActions.h"
#import "NSString+MMAdditions.h"

@implementation MMClearUntilEndOfLine

+ (NSArray *)_defaultArguments { return @[@0]; }

- (void)do;
{
    NSRange rangeToRemove;
    BOOL fillWithSpaces = NO;
    NSInteger numberOfCharactersLeftInLine;
    switch ([[self defaultedArgumentAtIndex:0] integerValue]) {
        case 0:
            numberOfCharactersLeftInLine = MAX(0, [self.delegate numberOfCharactersInScrollRow:self.delegate.cursorPositionY] - self.delegate.cursorPositionX + 1);
            rangeToRemove = NSMakeRange(self.delegate.cursorPositionX, numberOfCharactersLeftInLine);
            break;
        case 1:
            fillWithSpaces = [self.delegate numberOfCharactersInScrollRow:self.delegate.cursorPositionY] > self.delegate.cursorPositionX;
            rangeToRemove = NSMakeRange(1, MIN(self.delegate.cursorPositionX, [self.delegate numberOfCharactersInScrollRow:self.delegate.cursorPositionY]));
            break;
        case 2:
            rangeToRemove = NSMakeRange(1, [self.delegate numberOfCharactersInScrollRow:self.delegate.cursorPositionY]);
            break;
    }
    if (fillWithSpaces) {
        [self.delegate replaceCharactersAtScrollRow:self.delegate.cursorPositionY scrollColumn:rangeToRemove.location withString:[@" " repeatedTimes:rangeToRemove.length]];
    } else {
        [self.delegate removeCharactersInScrollRow:self.delegate.cursorPositionY range:rangeToRemove shiftCharactersAfter:NO];
    }
}

@end

@implementation MMClearScreen

+ (NSArray *)_defaultArguments { return @[@0]; }

- (void)do;
{
    [self.delegate setHasUsedWholeScreen:YES];
    if ([[self defaultedArgumentAtIndex:0] integerValue] == 0) {
        // Erase at and below cursor.
        for (NSInteger i = self.delegate.cursorPositionY + 1; i <= self.delegate.numberOfRowsOnScreen; ) {
            [self.delegate removeLineAtScrollRow:(self.delegate.cursorPositionY + 1)];
        }
        [self.delegate setScrollRow:self.delegate.cursorPositionY hasNewline:NO];
        NSInteger numberOfCharactersToRemove = MAX(0, [self.delegate numberOfCharactersInScrollRow:self.delegate.cursorPositionY] - self.delegate.cursorPositionX + 1);
        [self.delegate removeCharactersInScrollRow:self.delegate.cursorPositionY range:NSMakeRange(self.delegate.cursorPositionX, numberOfCharactersToRemove) shiftCharactersAfter:NO];
    } else if ([[self defaultedArgumentAtIndex:0] integerValue] == 1) {
        // Erase at and above cursor.
        BOOL fillWithNewlines =
            [self.delegate numberOfCharactersInScrollRow:self.delegate.cursorPositionY] > self.delegate.cursorPositionY ||
            [self.delegate isScrollRowTerminatedInNewline:self.delegate.cursorPositionY] ||
            (self.delegate.cursorPositionY < self.delegate.termHeight && ([self.delegate numberOfCharactersInScrollRow:(self.delegate.cursorPositionY + 1)] > 0 || [self.delegate isScrollRowTerminatedInNewline:(self.delegate.cursorPositionY + 1)]));
        for (NSInteger i = 1; i < self.delegate.cursorPositionY; i++) {
            [self.delegate removeCharactersInScrollRow:i range:NSMakeRange(1, [self.delegate numberOfCharactersInScrollRow:i]) shiftCharactersAfter:NO];
            [self.delegate setScrollRow:i hasNewline:fillWithNewlines];
        }

        // At this point, we have to determine if we are filling the line with spaces up to the cursor or just removing the line entirely.
        if (self.delegate.cursorPositionX == self.delegate.termWidth || self.delegate.cursorPositionX >= [self.delegate numberOfCharactersInScrollRow:self.delegate.cursorPositionY]) {
            [self.delegate removeCharactersInScrollRow:self.delegate.cursorPositionY range:NSMakeRange(1, MIN(self.delegate.cursorPositionX, [self.delegate numberOfCharactersInScrollRow:self.delegate.cursorPositionY])) shiftCharactersAfter:NO];
            [self.delegate setScrollRow:self.delegate.cursorPositionY hasNewline:fillWithNewlines];
        } else {
            [self.delegate replaceCharactersAtScrollRow:self.delegate.cursorPositionY scrollColumn:1 withString:[@" " repeatedTimes:MIN(self.delegate.cursorPositionX, [self.delegate numberOfCharactersInScrollRow:self.delegate.cursorPositionY])]];
        }
    } else if ([[self defaultedArgumentAtIndex:0] integerValue] == 2) {
        // Erase entire screen.
        for (NSInteger i = 1; i <= MIN(self.delegate.termHeight, self.delegate.numberOfRowsOnScreen); i++) {
            [self.delegate removeCharactersInScrollRow:i range:NSMakeRange(1, [self.delegate numberOfCharactersInScrollRow:i]) shiftCharactersAfter:NO];
            [self.delegate setScrollRow:i hasNewline:NO];
        }
    }
}

@end

@implementation MMDeleteCharacters

+ (NSArray *)_defaultArguments { return @[@1]; }

- (void)do;
{
    // This implements the VT220 feature "Delete Character (DCH)".
    NSInteger numberOfCharactersToDelete = MIN(MAX(1, [[self defaultedArgumentAtIndex:0] integerValue]), self.delegate.termWidth);
    NSInteger adjustedPositionX = MIN(self.delegate.cursorPositionX, self.delegate.termWidth);

    [self.delegate removeCharactersInScrollRow:self.delegate.cursorPositionY range:NSMakeRange(adjustedPositionX, numberOfCharactersToDelete) shiftCharactersAfter:YES];

    if (self.delegate.cursorPositionY < self.delegate.termHeight &&
        [self.delegate numberOfCharactersInScrollRow:(self.delegate.cursorPositionY + 1)] > 0) {
        [self.delegate setScrollRow:self.delegate.cursorPositionY hasNewline:YES];
    }
}

@end

@implementation MMEraseCharacters

+ (NSArray *)_defaultArguments { return @[@1]; }

- (void)do;
{
    // This implements the VT550 feature "Erase Character" (ECH).
    // It differs from the Delete Character escape sequence in that this sequence replaces the erased characters with spaces.
    NSInteger adjustedPositionX = MIN(self.delegate.cursorPositionX, self.delegate.termWidth);
    NSInteger spacesToInsert = MIN(MAX(1, [[self defaultedArgumentAtIndex:0] integerValue]), self.delegate.termWidth - adjustedPositionX + 1);
    NSInteger charactersToDelete = MIN(spacesToInsert, [self.delegate numberOfCharactersInScrollRow:self.delegate.cursorPositionY] - adjustedPositionX + 1);
    [self.delegate removeCharactersInScrollRow:self.delegate.cursorPositionY range:NSMakeRange(self.delegate.cursorPositionX, charactersToDelete) shiftCharactersAfter:YES];
    [self.delegate insertCharactersAtScrollRow:self.delegate.cursorPositionY scrollColumn:self.delegate.cursorPositionX text:[@" " repeatedTimes:spacesToInsert]];
}

@end