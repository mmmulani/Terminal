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
