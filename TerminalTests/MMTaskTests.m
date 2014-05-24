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
#import "NSString+MMAdditions.h"

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
  NSString *longString = [@"1234567890" repeatedTimes:15];
  CheckInputAgainstExpectedCursorPositionByCharacters(longString, 150);
  CheckInputAgainstExpectedCursorPositionByCharacters(@"\033[5;1H", 4);

  NSString *longerThanScreenString = [@"1234567890" repeatedToLength:(25 * 81)];
  CheckInputAgainstExpectedCursorPositionByCharacters(longerThanScreenString, 25 * 81);

  NSString *lotsOfNewlines = [@"\n" repeatedTimes:30];
  CheckInputAgainstExpectedCursorPositionByCharacters(lotsOfNewlines, 30);
}

- (void)testOutputHandling;
{
  MMTask *task = [MMTask new];
  SendInputToTask(task, @"\033[");
  SendInputToTask(task, @"K");
  SendInputToTask(task, @"K");
  XCTAssertEqualObjects(task.currentANSIDisplay.string, @"K", @"Broken escape sequence should not be handled twice");
}

- (void)testProcessFinished;
{
  MMTask *task = [MMTask new];
  SendInputToTask(task, @"test\n");
  XCTAssertEqualObjects(task.currentANSIDisplay.string, @"test\n", @"Newline should not be removed before process is finished");
  [task processFinished:MMProcessStatusExit data:nil];
  XCTAssertEqualObjects(task.currentANSIDisplay.string, @"test", @"Newline should be removed after process is finished");
  SendInputToTask(task, @"test2\n");
  XCTAssertEqualObjects(task.currentANSIDisplay.string, @"test\ntest2", @"Newline should be readded if task has to handle more output");
}

- (void)testWidthResizing;
{
  // Test some short lines along with a line that extends across multiple rows.
  MMTask *task = [MMTask new];
  SendInputToTask(task, @"abcde\nfghij\n123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890");
  XCTAssertEqual(task.cursorPositionX, (NSInteger)41, @"");
  XCTAssertEqual(task.cursorPositionY, (NSInteger)4, @"");
  XCTAssertEqual(task.termWidth, (NSInteger)80, @"");

  [task changeTerminalWidthTo:100];
  XCTAssertEqual(task.characterOffsetToScreen, (NSInteger)0, @"");
  XCTAssertEqual(task.cursorPositionX, (NSInteger)21, @"");
  XCTAssertEqual(task.cursorPositionY, (NSInteger)4, @"");
  XCTAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@5, @5, @100, @20]), @"");
  XCTAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @YES, @NO, @NO]), @"");
  XCTAssertEqual(task.termWidth, (NSInteger)100, @"");

  [task changeTerminalWidthTo:40];
  XCTAssertEqual(task.characterOffsetToScreen, (NSInteger)0, @"");
  XCTAssertEqual(task.cursorPositionX, (NSInteger)40, @"");
  XCTAssertEqual(task.cursorPositionY, (NSInteger)5, @"");
  XCTAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@5, @5, @40, @40, @40]), @"");
  XCTAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @YES, @NO, @NO, @NO]), @"");
  XCTAssertEqual(task.termWidth, (NSInteger)40, @"");

  [task changeTerminalWidthTo:53];
  XCTAssertEqual(task.characterOffsetToScreen, (NSInteger)0, @"");
  XCTAssertEqual(task.cursorPositionX, (NSInteger)14, @"");
  XCTAssertEqual(task.cursorPositionY, (NSInteger)5, @"");
  XCTAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@5, @5, @53, @53, @14]), @"");
  XCTAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @YES, @NO, @NO, @NO]), @"");
  XCTAssertEqual(task.termWidth, (NSInteger)53, @"");

  // Test a single newline.
  task = [MMTask new];
  SendInputToTask(task, @"\n");
  XCTAssertEqual(task.cursorPositionX, (NSInteger)1, @"");
  XCTAssertEqual(task.cursorPositionY, (NSInteger)2, @"");

  [task changeTerminalWidthTo:100];
  XCTAssertEqual(task.characterOffsetToScreen, (NSInteger)0, @"");
  XCTAssertEqual(task.cursorPositionX, (NSInteger)1, @"");
  XCTAssertEqual(task.cursorPositionY, (NSInteger)2, @"");
  XCTAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@0, @0]), @"");
  XCTAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @NO]), @"");
  XCTAssertEqual(task.termWidth, (NSInteger)100, @"");

  [task changeTerminalWidthTo:10];
  XCTAssertEqual(task.characterOffsetToScreen, (NSInteger)0, @"");
  XCTAssertEqual(task.cursorPositionX, (NSInteger)1, @"");
  XCTAssertEqual(task.cursorPositionY, (NSInteger)2, @"");
  XCTAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@0, @0]), @"");
  XCTAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @NO]), @"");
  XCTAssertEqual(task.termWidth, (NSInteger)10, @"");

  // Test a couple newlines.
  task = [MMTask new];
  SendInputToTask(task, @"\n\n");
  XCTAssertEqual(task.cursorPositionX, (NSInteger)1, @"");
  XCTAssertEqual(task.cursorPositionY, (NSInteger)3, @"");

  [task changeTerminalWidthTo:100];
  XCTAssertEqual(task.characterOffsetToScreen, (NSInteger)0, @"");
  XCTAssertEqual(task.cursorPositionX, (NSInteger)1, @"");
  XCTAssertEqual(task.cursorPositionY, (NSInteger)3, @"");
  XCTAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@0, @0, @0]), @"");
  XCTAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @YES, @NO]), @"");
  XCTAssertEqual(task.termWidth, (NSInteger)100, @"");

  // Test enough newlines to go beyond a single screen.
  task = [MMTask new];
  SendInputToTask(task, [@"\n" repeatedTimes:25]);
  XCTAssertEqual(task.characterOffsetToScreen, (NSInteger)2, @"");
  XCTAssertEqual(task.cursorPositionX, (NSInteger)1, @"");
  XCTAssertEqual(task.cursorPositionY, (NSInteger)24, @"");

  [task changeTerminalWidthTo:100];
  XCTAssertEqual(task.characterOffsetToScreen, (NSInteger)2, @"");
  XCTAssertEqual(task.cursorPositionX, (NSInteger)1, @"");
  XCTAssertEqual(task.cursorPositionY, (NSInteger)24, @"");
  XCTAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0]), @"");
  XCTAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @NO]), @"");
  XCTAssertEqual(task.termWidth, (NSInteger)100, @"");

  // Test a line long enough to fill the screen when resized.
  task = [MMTask new];
  SendInputToTask(task, [@"\n" stringByAppendingString:[@"1234567890" repeatedToLength:500]]);
  XCTAssertEqual(task.cursorPositionX, (NSInteger)21, @"");
  XCTAssertEqual(task.cursorPositionY, (NSInteger)8, @"");

  [task changeTerminalWidthTo:21];
  XCTAssertEqual(task.characterOffsetToScreen, (NSInteger)1, @"");
  XCTAssertEqual(task.cursorPositionX, (NSInteger)18, @"");
  XCTAssertEqual(task.cursorPositionY, (NSInteger)24, @"");
  XCTAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @21, @17]), @"");
  XCTAssertEqualObjects(task.scrollRowHasNewline, (@[@NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO, @NO]), @"");
  XCTAssertEqual(task.termWidth, (NSInteger)21, @"");

  [task changeTerminalWidthTo:80];
  XCTAssertEqual(task.cursorPositionX, (NSInteger)21, @"");
  XCTAssertEqual(task.cursorPositionY, (NSInteger)8, @"");
  XCTAssertEqual(task.termWidth, (NSInteger)80, @"");

}

- (void)testHeightResizing;
{
  // Test the bottom being removed.
  MMTask *task = [MMTask new];
  SendInputToTask(task, @"a\nb\nc");
  XCTAssertEqual(task.characterOffsetToScreen, (NSInteger)0, @"");
  XCTAssertEqual(task.cursorPositionX, (NSInteger)2, @"");
  XCTAssertEqual(task.cursorPositionY, (NSInteger)3, @"");
  XCTAssertEqual(task.scrollMarginTop, (NSInteger)1, @"");
  XCTAssertEqual(task.scrollMarginBottom, (NSInteger)24, @"");

  [task changeTerminalHeightTo:20];
  XCTAssertEqual(task.characterOffsetToScreen, (NSInteger)0, @"");
  XCTAssertEqual(task.cursorPositionX, (NSInteger)2, @"");
  XCTAssertEqual(task.cursorPositionY, (NSInteger)3, @"");
  XCTAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@1, @1, @1]));
  XCTAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @YES, @NO]));
  XCTAssertEqual(task.termHeight, (NSInteger)20, @"");
  XCTAssertEqual(task.scrollMarginTop, (NSInteger)1, @"");
  XCTAssertEqual(task.scrollMarginBottom, (NSInteger)20, @"");

  SendInputToTask(task, @"\033[2;10r");
  XCTAssertEqual(task.scrollMarginTop, (NSInteger)2, @"");
  XCTAssertEqual(task.scrollMarginBottom, (NSInteger)10, @"");

  [task changeTerminalHeightTo:21];
  XCTAssertEqual(task.scrollMarginTop, (NSInteger)1, @"");
  XCTAssertEqual(task.scrollMarginBottom, (NSInteger)21, @"");

  // Test the top being scrolled away.
  task = [MMTask new];
  SendInputToTask(task, @"1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12\n13\n14\n15\n16\n17\n18\n19\n20\n21\n22\n23\n24");
  XCTAssertEqual(task.characterOffsetToScreen, (NSInteger)0, @"");
  XCTAssertEqual(task.cursorPositionX, (NSInteger)3, @"");
  XCTAssertEqual(task.cursorPositionY, (NSInteger)24, @"");

  [task changeTerminalHeightTo:20];
  XCTAssertEqual(task.characterOffsetToScreen, (NSInteger)8, @"");
  XCTAssertEqual(task.cursorPositionX, (NSInteger)3, @"");
  XCTAssertEqual(task.cursorPositionY, (NSInteger)20, @"");
  XCTAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@1, @1, @1, @1, @1, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2]), @"");
  XCTAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @NO]), @"");
  XCTAssertEqual(task.termHeight, (NSInteger)20, @"");

  // Test both bottom being removed and top scrolling away.
  task = [MMTask new];
  SendInputToTask(task, @"1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12");
  XCTAssertEqual(task.characterOffsetToScreen, (NSInteger)0, @"");
  XCTAssertEqual(task.cursorPositionX, (NSInteger)3, @"");
  XCTAssertEqual(task.cursorPositionY, (NSInteger)12, @"");
  XCTAssertEqual(task.termHeight, (NSInteger)24, @"");

  [task changeTerminalHeightTo:8];
  XCTAssertEqual(task.characterOffsetToScreen, (NSInteger)8, @"");
  XCTAssertEqual(task.cursorPositionX, (NSInteger)3, @"");
  XCTAssertEqual(task.cursorPositionY, (NSInteger)8, @"");
  XCTAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@1, @1, @1, @1, @1, @2, @2, @2]), @"");
  XCTAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @YES, @YES, @YES, @YES, @YES, @YES, @NO]), @"");
  XCTAssertEqual(task.termHeight, (NSInteger)8, @"");

  // Test the bottom expanding.
  task = [MMTask new];
  SendInputToTask(task, @"1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12\n13\n14\n15\n16\n17\n18\n19\n20\n21\n22\n23\n24\n25\n26\n27");
  XCTAssertEqual(task.characterOffsetToScreen, (NSInteger)6, @"");
  XCTAssertEqual(task.cursorPositionX, (NSInteger)3, @"");
  XCTAssertEqual(task.cursorPositionY, (NSInteger)24, @"");

  [task changeTerminalHeightTo:28];
  XCTAssertEqual(task.characterOffsetToScreen, (NSInteger)0, @"");
  XCTAssertEqual(task.cursorPositionX, (NSInteger)3, @"");
  XCTAssertEqual(task.cursorPositionY, (NSInteger)27, @"");
  XCTAssertEqualObjects(task.characterCountsOnVisibleRows, (@[@1, @1, @1, @1, @1, @1, @1, @1, @1, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2, @2]), @"");
  XCTAssertEqualObjects(task.scrollRowHasNewline, (@[@YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @YES, @NO]), @"");
  XCTAssertEqual(task.termHeight, (NSInteger)28, @"");

  // Test the top scrolling away too much (possible crash).
  task = [MMTask new];
  SendInputToTask(task, @"\033[0Ja\nb\nc");
  [task changeTerminalHeightTo:1];
}

- (void)testResizingFromOutput;
{
  MMTask *task = [MMTask new];
  id mockTerminalConnection = [OCMockObject mockForClass:[MMTerminalConnection class]];
  id mockWindowController = [OCMockObject mockForClass:[MMTerminalWindowController class]];
  task.terminalConnection = mockTerminalConnection;
  SendInputToTask(task, @"a\nb");
  XCTAssertEqual(task.termWidth, (NSInteger)80, @"");
  XCTAssertEqual(task.termHeight, (NSInteger)24, @"");

  SendInputToTask(task, @"\033[?3h");
  XCTAssertEqual(task.termWidth, (NSInteger)80, @"");
  XCTAssertEqual(task.termHeight, (NSInteger)24, @"");

  [[[mockTerminalConnection expect] andReturn:mockWindowController] terminalWindow];
  [[[mockWindowController expect] andDo:^(NSInvocation *invocation) {
    [task resizeTerminalToColumns:132 rows:24];
  }] resizeWindowForTerminalScreenSizeOfColumns:132 rows:24];

  SendInputToTask(task, @"\033[?40h\033[?3h");
  XCTAssertEqual(task.termWidth, (NSInteger)132, @"");
  XCTAssertEqual(task.termHeight, (NSInteger)24, @"");
  XCTAssertEqualObjects(task.currentANSIDisplay.string, @"", @"");

  [[[mockTerminalConnection expect] andReturn:mockWindowController] terminalWindow];
  [[[mockWindowController expect] andDo:^(NSInvocation *invocation) {
    [task resizeTerminalToColumns:80 rows:24];
  }] resizeWindowForTerminalScreenSizeOfColumns:80 rows:24];

  SendInputToTask(task, @"C\033[?3l");
  XCTAssertEqual(task.termWidth, (NSInteger)80, @"");
  XCTAssertEqual(task.termHeight, (NSInteger)24, @"");
  XCTAssertEqualObjects(task.currentANSIDisplay.string, @"", @"");
}

- (void)testRowCounting
{
  MMTask *task = [MMTask new];
  XCTAssertEqual(task.totalRowsInOutput, 1);
  SendInputToTask(task, @"a\nb\nc");
  XCTAssertEqual(task.totalRowsInOutput, 3);
  SendInputToTask(task, @" ");
  XCTAssertEqual(task.totalRowsInOutput, 3);
  SendInputToTask(task, @"\n");
  XCTAssertEqual(task.totalRowsInOutput, 4);
  SendInputToTask(task, @"\b");
  XCTAssertEqual(task.totalRowsInOutput, 4);

  task = [MMTask new];
  SendInputToTask(task, [@"\n" repeatedTimes:25]);
  XCTAssertEqual(task.totalRowsInOutput, 26);

  task = [MMTask new];
  SendInputToTask(task, @"\033[5;1H");
  XCTAssertEqual(task.totalRowsInOutput, 5);
  SendInputToTask(task, @"\033[24;1H");
  XCTAssertEqual(task.totalRowsInOutput, 24);

  task = [MMTask new];
  SendInputToTask(task, [@"A" repeatedTimes:81]);
  XCTAssertEqual(task.totalRowsInOutput, 2);
}

@end
