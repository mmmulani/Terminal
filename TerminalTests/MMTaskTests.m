//
//  MMTaskTests.m
//  Terminal
//
//  Created by Mehdi Mulani on 3/24/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMTaskTests.h"
#import "MMTask.h"
#import "MMTerminalConnection.h"
#import "MMTerminalWindowController.h"
#import "MMTestHelpers.h"

#import <OCMock/OCMock.h>

@interface MMTask ()

@property NSInteger characterOffsetToScreen;
@property NSMutableArray *characterCountsOnVisibleRows;
@property NSMutableArray *scrollRowHasNewline;
@property NSMutableArray *scrollRowTabRanges;

- (void)changeTerminalWidthTo:(NSInteger)newTerminalWidth;
- (void)changeTerminalHeightTo:(NSInteger)newHeight;

@end

@implementation MMTaskTests

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
    SendInputToTask(task, @"\033[");
    SendInputToTask(task, @"K");
    SendInputToTask(task, @"K");
    STAssertEqualObjects(task.currentANSIDisplay.string, @"K", @"Broken escape sequence should not be handled twice");
}

- (void)testProcessFinished;
{
    MMTask *task = [MMTask new];
    task.displayTextStorage = [NSTextStorage new];
    SendInputToTask(task, @"test\n");
    STAssertEqualObjects(task.currentANSIDisplay.string, @"test\n", @"Newline should not be removed before process is finished");
    [task processFinished:MMProcessStatusExit data:nil];
    STAssertEqualObjects(task.currentANSIDisplay.string, @"test", @"Newline should be removed after process is finished");
    SendInputToTask(task, @"test2\n");
    STAssertEqualObjects(task.currentANSIDisplay.string, @"test\ntest2", @"Newline should be readded if task has to handle more output");
}

- (void)testWidthResizing;
{
    // Test some short lines along with a line that extends across multiple rows.
    MMTask *task = [MMTask new];
    task.displayTextStorage = [NSTextStorage new];
    SendInputToTask(task, @"abcde\nfghij\n123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890");
    STAssertEquals(task.cursorPositionX, (NSInteger)41, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)4, @"");
    STAssertEquals(task.termWidth, (NSInteger)80, @"");

    [task changeTerminalWidthTo:100];
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)0, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)21, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)4, @"");
    STAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@5, @5, @100, @20]), @"");
    STAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @YES, @NO, @NO]), @"");
    STAssertEquals(task.termWidth, (NSInteger)100, @"");

    [task changeTerminalWidthTo:40];
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)0, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)40, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)5, @"");
    STAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@5, @5, @40, @40, @40]), @"");
    STAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @YES, @NO, @NO, @NO]), @"");
    STAssertEquals(task.termWidth, (NSInteger)40, @"");

    [task changeTerminalWidthTo:53];
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)0, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)14, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)5, @"");
    STAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@5, @5, @53, @53, @14]), @"");
    STAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @YES, @NO, @NO, @NO]), @"");
    STAssertEquals(task.termWidth, (NSInteger)53, @"");

    // Test a single newline.
    task = [MMTask new];
    task.displayTextStorage = [NSTextStorage new];
    SendInputToTask(task, @"\n");
    STAssertEquals(task.cursorPositionX, (NSInteger)1, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)2, @"");

    [task changeTerminalWidthTo:100];
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)0, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)1, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)2, @"");
    STAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@0, @0]), @"");
    STAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @NO]), @"");
    STAssertEquals(task.termWidth, (NSInteger)100, @"");

    [task changeTerminalWidthTo:10];
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)0, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)1, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)2, @"");
    STAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@0, @0]), @"");
    STAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @NO]), @"");
    STAssertEquals(task.termWidth, (NSInteger)10, @"");

    // Test a couple newlines.
    task = [MMTask new];
    task.displayTextStorage = [NSTextStorage new];
    SendInputToTask(task, @"\n\n");
    STAssertEquals(task.cursorPositionX, (NSInteger)1, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)3, @"");

    [task changeTerminalWidthTo:100];
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)0, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)1, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)3, @"");
    STAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@0, @0, @0]), @"");
    STAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @YES, @NO]), @"");
    STAssertEquals(task.termWidth, (NSInteger)100, @"");

    // Test enough newlines to go beyond a single screen.
    task = [MMTask new];
    task.displayTextStorage = [NSTextStorage new];
    SendInputToTask(task, [@"" stringByPaddingToLength:25 withString:@"\n" startingAtIndex:0]);
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)2, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)1, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)24, @"");

    [task changeTerminalWidthTo:100];
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)2, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)1, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)24, @"");
    STAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0]), @"");
    STAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @NO]), @"");
    STAssertEquals(task.termWidth, (NSInteger)100, @"");

    // Test a line long enough to fill the screen when resized.
    task = [MMTask new];
    task.displayTextStorage = [NSTextStorage new];
    SendInputToTask(task, [@"\n" stringByAppendingString:[@"" stringByPaddingToLength:500 withString:@"1234567890" startingAtIndex:0]]);
    STAssertEquals(task.cursorPositionX, (NSInteger)21, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)8, @"");

    [task changeTerminalWidthTo:21];
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)1, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)18, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)24, @"");
    STAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @17]), @"");
    STAssertEqualObjects(task.scrollRowHasNewline, (@[@NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO]), @"");
    STAssertEquals(task.termWidth, (NSInteger)21, @"");

    [task changeTerminalWidthTo:80];
    STAssertEquals(task.cursorPositionX, (NSInteger)21, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)8, @"");
    STAssertEquals(task.termWidth, (NSInteger)80, @"");

}

- (void)testHeightResizing;
{
    // Test the bottom being removed.
    MMTask *task = [MMTask new];
    task.displayTextStorage = [NSTextStorage new];
    SendInputToTask(task, @"a\nb\nc");
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)0, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)2, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)3, @"");

    [task changeTerminalHeightTo:20];
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)0, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)2, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)3, @"");
    STAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@1, @1, @1, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0]), @"");
    STAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @YES, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO]), @"");
    STAssertEquals(task.termHeight, (NSInteger)20, @"");

    // Test the top being scrolled away.
    task = [MMTask new];
    task.displayTextStorage = [NSTextStorage new];
    SendInputToTask(task, @"1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12\n13\n14\n15\n16\n17\n18\n19\n20\n21\n22\n23\n24");
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)0, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)3, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)24, @"");

    [task changeTerminalHeightTo:20];
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)8, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)3, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)20, @"");
    STAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@1, @1, @1, @1, @1, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2]), @"");
    STAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @NO]), @"");
    STAssertEquals(task.termHeight, (NSInteger)20, @"");

    // Test both bottom being removed and top scrolling away.
    task = [MMTask new];
    task.displayTextStorage = [NSTextStorage new];
    SendInputToTask(task, @"1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12");
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)0, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)3, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)12, @"");
    STAssertEquals(task.termHeight, (NSInteger)24, @"");

    [task changeTerminalHeightTo:8];
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)8, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)3, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)8, @"");
    STAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@1, @1, @1, @1, @1, @2, @2, @2]), @"");
    STAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @YES, @YES, @YES, @YES, @YES, @YES, @NO]), @"");
    STAssertEquals(task.termHeight, (NSInteger)8, @"");

    // Test the bottom expanding.
    task = [MMTask new];
    task.displayTextStorage = [NSTextStorage new];
    SendInputToTask(task, @"1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12\n13\n14\n15\n16\n17\n18\n19\n20\n21\n22\n23\n24\n25\n26\n27");
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)6, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)3, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)24, @"");

    [task changeTerminalHeightTo:28];
    STAssertEquals(task.characterOffsetToScreen, (NSInteger)0, @"");
    STAssertEquals(task.cursorPositionX, (NSInteger)3, @"");
    STAssertEquals(task.cursorPositionY, (NSInteger)27, @"");
    STAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@1, @1, @1, @1, @1, @1, @1, @1, @1, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2]), @"");
    STAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @NO]), @"");
    STAssertEquals(task.termHeight, (NSInteger)28, @"");

    // Test the top scrolling away too much (possible crash).
    task = [MMTask new];
    task.displayTextStorage = [NSTextStorage new];
    SendInputToTask(task, @"\033[0Ja\nb\nc");
    [task changeTerminalHeightTo:1];
}

- (void)testResizingFromOutput;
{
    MMTask *task = [MMTask new];
    id mockTerminalConnection = [OCMockObject mockForClass:[MMTerminalConnection class]];
    id mockWindowController = [OCMockObject mockForClass:[MMTerminalWindowController class]];
    task.terminalConnection = mockTerminalConnection;
    task.displayTextStorage = [NSTextStorage new];
    SendInputToTask(task, @"a\nb");
    STAssertEquals(task.termWidth, (NSInteger)80, @"");
    STAssertEquals(task.termHeight, (NSInteger)24, @"");

    SendInputToTask(task, @"\033[?3h");
    STAssertEquals(task.termWidth, (NSInteger)80, @"");
    STAssertEquals(task.termHeight, (NSInteger)24, @"");

    [[[mockTerminalConnection expect] andReturn:mockWindowController] terminalWindow];
    [[[mockWindowController expect] andDo:^(NSInvocation *invocation) {
        [task resizeTerminalToColumns:132 rows:24];
    }] resizeWindowForTerminalScreenSizeOfColumns:132 rows:24];

    SendInputToTask(task, @"\033[?40h\033[?3h");
    STAssertEquals(task.termWidth, (NSInteger)132, @"");
    STAssertEquals(task.termHeight, (NSInteger)24, @"");
    STAssertEqualObjects(task.currentANSIDisplay.string, @"", @"");

    [[[mockTerminalConnection expect] andReturn:mockWindowController] terminalWindow];
    [[[mockWindowController expect] andDo:^(NSInvocation *invocation) {
        [task resizeTerminalToColumns:80 rows:24];
    }] resizeWindowForTerminalScreenSizeOfColumns:80 rows:24];

    SendInputToTask(task, @"C\033[?3l");
    STAssertEquals(task.termWidth, (NSInteger)80, @"");
    STAssertEquals(task.termHeight, (NSInteger)24, @"");
    STAssertEqualObjects(task.currentANSIDisplay.string, @"", @"");
}

@end
