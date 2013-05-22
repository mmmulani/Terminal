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
        [self.delegate removeCharactersInScrollRow:self.delegate.cursorPositionY range:rangeToRemove];
    }
}

@end
