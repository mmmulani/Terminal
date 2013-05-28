//
//  MMErasingActions.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/22/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMErasingActions.h"

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
        [self.delegate replaceCharactersAtScrollRow:self.delegate.cursorPositionY scrollColumn:rangeToRemove.location withString:[@"" stringByPaddingToLength:rangeToRemove.length withString:@" " startingAtIndex:0]];
    } else {
        [self.delegate removeCharactersInScrollRow:self.delegate.cursorPositionY range:rangeToRemove shiftCharactersAfter:NO];
    }
}

@end

@implementation MMClearScreen

+ (NSArray *)_defaultArguments { return @[@0]; }

- (void)do;
{
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
        [self.delegate removeCharactersInScrollRow:self.delegate.cursorPositionY range:NSMakeRange(1, MIN(self.delegate.cursorPositionX, [self.delegate numberOfCharactersInScrollRow:self.delegate.cursorPositionY])) shiftCharactersAfter:NO];
        if (self.delegate.cursorPositionX == self.delegate.termWidth) {
            [self.delegate setScrollRow:self.delegate.cursorPositionY hasNewline:fillWithNewlines];
        }
    } else if ([[self defaultedArgumentAtIndex:0] integerValue] == 2) {
        // Erase entire screen.
        for (NSInteger i = 1; i <= self.delegate.termHeight; i++) {
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