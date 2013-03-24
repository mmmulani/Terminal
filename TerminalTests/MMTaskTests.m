//
//  MMTaskTests.m
//  Terminal
//
//  Created by Mehdi Mulani on 3/24/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMTaskTests.h"
#import "MMTask.h"

@implementation MMTaskTests

#define CheckInputAgainstExpectedCursorPositionByCharacters(input, cursorPositionByCharacters_) \
do {\
    MMTask *task = [MMTask new]; \
    [task handleCommandOutput:input withVerbosity:NO]; \
    (void) task.currentANSIDisplay; \
    STAssertEquals(task.cursorPositionByCharacters, (NSUInteger)cursorPositionByCharacters_, @"Comparing cursor position by characters."); \
} while (0)

- (void)testCursorPositionByCharacters;
{
    CheckInputAgainstExpectedCursorPositionByCharacters(@"abc", 3);
    CheckInputAgainstExpectedCursorPositionByCharacters(@"a\nb", 3);
    CheckInputAgainstExpectedCursorPositionByCharacters(@"abc\033[1;1H", 0);
    CheckInputAgainstExpectedCursorPositionByCharacters(@"abc\033[1;1Hd", 1);
    CheckInputAgainstExpectedCursorPositionByCharacters(@"abc\033[1;2H", 1);
    NSString *longString = [@"" stringByPaddingToLength:150 withString:@"1234567890" startingAtIndex:0];
    CheckInputAgainstExpectedCursorPositionByCharacters(longString, 150);
    CheckInputAgainstExpectedCursorPositionByCharacters(@"\033[5;1H", 4);
}

@end
