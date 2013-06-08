//
//  MMTaskTests.m
//  Terminal
//
//  Created by Mehdi Mulani on 3/24/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMTaskTests.h"
#import "MMTask.h"

@interface MMTask ()

@property NSInteger characterOffsetToScreen;
@property NSMutableArray *characterCountsOnVisibleRows;
@property NSMutableArray *scrollRowHasNewline;
@property NSMutableArray *scrollRowTabRanges;

- (void)changeTerminalWidthTo:(NSInteger)newTerminalWidth;

@end

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

- (void)testWidthResizing;
{
    // Test some short lines along with a line that extends across multiple rows.
    MMTask *task = [MMTask new];
    task.displayTextStorage = [NSTextStorage new];
    [task handleCommandOutput:@"abcde\nfghij\n123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890"];
    STAssertEquals(task.cursorPositionX, (NSInteger)41, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)4, @"");

    [task changeTerminalWidthTo:100];
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)0, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)21, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)4, @"");
    STAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@5, @5, @100, @20]), @"");
    STAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @YES, @NO, @NO]), @"");

    [task changeTerminalWidthTo:40];
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)0, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)40, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)5, @"");
    STAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@5, @5, @40, @40, @40]), @"");
    STAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @YES, @NO, @NO, @NO]), @"");

    [task changeTerminalWidthTo:53];
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)0, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)14, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)5, @"");
    STAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@5, @5, @53, @53, @14]), @"");
    STAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @YES, @NO, @NO, @NO]), @"");

    // Test a single newline.
    task = [MMTask new];
    task.displayTextStorage = [NSTextStorage new];
    [task handleCommandOutput:@"\n"];
    STAssertEquals(task.cursorPositionX, (NSInteger)1, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)2, @"");

    [task changeTerminalWidthTo:100];
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)0, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)1, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)2, @"");
    STAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@0, @0]), @"");
    STAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @NO]), @"");

    [task changeTerminalWidthTo:10];
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)0, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)1, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)2, @"");
    STAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@0, @0]), @"");
    STAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @NO]), @"");

    // Test a couple newlines.
    task = [MMTask new];
    task.displayTextStorage = [NSTextStorage new];
    [task handleCommandOutput:@"\n\n"];
    STAssertEquals(task.cursorPositionX, (NSInteger)1, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)3, @"");

    [task changeTerminalWidthTo:100];
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)0, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)1, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)3, @"");
    STAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@0, @0, @0]), @"");
    STAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @YES, @NO]), @"");

    // Test enough newlines to go beyond a single screen.
    task = [MMTask new];
    task.displayTextStorage = [NSTextStorage new];
    [task handleCommandOutput:[@"" stringByPaddingToLength:25 withString:@"\n" startingAtIndex:0]];
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)2, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)1, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)24, @"");

    [task changeTerminalWidthTo:100];
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)2, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)1, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)24, @"");
    STAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0]), @"");
    STAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @NO]), @"");

    // Test a line long enough to fill the screen when resized.
    task = [MMTask new];
    task.displayTextStorage = [NSTextStorage new];
    [task handleCommandOutput:[@"\n" stringByAppendingString:[@"" stringByPaddingToLength:500 withString:@"1234567890" startingAtIndex:0]]];
    STAssertEquals(task.cursorPositionX, (NSInteger)21, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)8, @"");

    [task changeTerminalWidthTo:21];
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)1, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)18, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)24, @"");
    STAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @17]), @"");
    STAssertEqualObjects(task.scrollRowHasNewline, (@[@NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO]), @"");

    [task changeTerminalWidthTo:80];
    STAssertEquals(task.cursorPositionX, (NSInteger)21, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)8, @"");

}

@end
