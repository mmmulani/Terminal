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
    task.displayTextStorage = [NSTextStorage new]; \
    [task handleCommandOutput:input]; \
    (void) task.currentANSIDisplay; \
    STAssertEquals(task.cursorPositionByCharacters, (NSInteger)cursorPositionByCharacters_, @"Comparing cursor position by characters."); \
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

    NSString *longerThanScreenString = [@"" stringByPaddingToLength:(25 * 81) withString:@"1234567890" startingAtIndex:0];
    CheckInputAgainstExpectedCursorPositionByCharacters(longerThanScreenString, 25 * 81);

    NSString *lotsOfNewlines = [@"" stringByPaddingToLength:30 withString:@"\n" startingAtIndex:0];
    CheckInputAgainstExpectedCursorPositionByCharacters(lotsOfNewlines, 30);
}

- (void)testOutputHandling;
{
    MMTask *task = [MMTask new];
    task.displayTextStorage = [NSTextStorage new];
    [task handleCommandOutput:@"\033["];
    [task handleCommandOutput:@"K"];
    [task handleCommandOutput:@"K"];
    STAssertEqualObjects(task.currentANSIDisplay.string, @"K", @"Broken escape sequence should not be handled twice");
}

- (void)testProcessFinished;
{
    MMTask *task = [MMTask new];
    task.displayTextStorage = [NSTextStorage new];
    [task handleCommandOutput:@"test\n"];
    STAssertEqualObjects(task.currentANSIDisplay.string, @"test\n", @"Newline should not be removed before process is finished");
    [task processFinished];
    STAssertEqualObjects(task.currentANSIDisplay.string, @"test", @"Newline should be removed after process is finished");
    [task handleCommandOutput:@"test2\n"];
    STAssertEqualObjects(task.currentANSIDisplay.string, @"test\ntest2", @"Newline should be readded if task has to handle more output");
}

@end
