//
//  ANSIEscapeSequencesTests.m
//  ANSIEscapeSequencesTests
//
//  Created by Mehdi Mulani on 3/10/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "ANSIEscapeSequencesTests.h"
#import "MMTask.h"

@implementation ANSIEscapeSequencesTests

- (void)setUp;
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown;
{
    // Tear-down code here.
    
    [super tearDown];
}

#define CheckInputAgainstExpectedOutput(input, output) \
do {\
    MMTask *task = [MMTask new]; \
    [task handleCommandOutput:input withVerbosity:NO]; \
    STAssertEqualObjects([task.currentANSIDisplay string], output, @"Compared task output to provided output."); \
} while (0)

#define CheckInputAgainstExpectedOutputWithExpectedCursor(input, output, cursorPosition_) \
do {\
    MMTask *task = [MMTask new]; \
    [task handleCommandOutput:input withVerbosity:NO]; \
    STAssertEqualObjects([task.currentANSIDisplay string], output, @"Compared task output to provided output."); \
    STAssertEquals(task.cursorPosition.x, cursorPosition_.x, @"X coord of cursor position"); \
    STAssertEquals(task.cursorPosition.y, cursorPosition_.y, @"Y coord of cursor position"); \
} while (0)

- (void)testNonANSIPrograms;
{
    CheckInputAgainstExpectedOutput(@"a", @"a");
    CheckInputAgainstExpectedOutput(@"a\nb", @"a\nb");
    CheckInputAgainstExpectedOutput(@"a\nb\n", @"a\nb\n");

    // Really long strings shouldn't be separated to multiple lines.
    NSString *longString = [@"" stringByPaddingToLength:100 withString:@"1234567890" startingAtIndex:0];
    CheckInputAgainstExpectedOutput(longString, longString);
}

- (void)testClearingScreen;
{
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\033[2J", @"", MMPositionMake(1,1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"_\033[2J", @"", MMPositionMake(2,1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"_\033[2Ja", @" a", MMPositionMake(3,1));
    CheckInputAgainstExpectedOutput(@"__\033[2Ja", @"  a");
    CheckInputAgainstExpectedOutput(@"12\n34\n\033[2J", @"");

    // This is mainly a test against crashes.
    NSString *lotsOfNewLines = [@"" stringByPaddingToLength:80 withString:@"\n" startingAtIndex:0];
    CheckInputAgainstExpectedOutput([lotsOfNewLines stringByAppendingString:@"\033[2J"], [@"" stringByPaddingToLength:(80 - 23) withString:@"\n" startingAtIndex:0]);

    CheckInputAgainstExpectedOutput(@"\033[24;1H\n\n\n\033[2Ja", [[@"" stringByPaddingToLength:26 withString:@"\n" startingAtIndex:0] stringByAppendingString:@"a"]);
}

- (void)testCursorHorizontalAbsolute;
{
    CheckInputAgainstExpectedOutput(@"test\033[GA", @"Aest");
    CheckInputAgainstExpectedOutput(@"test\033[0GA", @"Aest");
    CheckInputAgainstExpectedOutput(@"test\033[1GA", @"Aest");
    CheckInputAgainstExpectedOutput(@"test\033[2GA", @"tAst");
    CheckInputAgainstExpectedOutput(@"\033[80Gt", @"                                                                               t");
    CheckInputAgainstExpectedOutput(@"\033[80Gta", @"                                                                               ta");
    NSString *expectedOutput = [[@"test" stringByPaddingToLength:79 withString:@" " startingAtIndex:0] stringByAppendingString:@"A"];
    CheckInputAgainstExpectedOutput(@"test\033[90GA", expectedOutput);
}

- (void)testCursorVerticalAbsolute;
{
    CheckInputAgainstExpectedOutput(@"\na\033[db", @" b\na");
    CheckInputAgainstExpectedOutput(@"\na\033[0db", @" b\na");
    CheckInputAgainstExpectedOutput(@"\na\033[1db", @" b\na");
    CheckInputAgainstExpectedOutput(@"a\033[2db", @"a\n b");
    CheckInputAgainstExpectedOutput(@"\033[100da", [[@"" stringByPaddingToLength:23 withString:@"\n" startingAtIndex:0] stringByAppendingFormat:@"a"]);
}

- (void)testNewlineHandling;
{
    CheckInputAgainstExpectedOutput(@"test\n", @"test\n");
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"test\n\n", @"test\n\n", MMPositionMake(1, 3));
    CheckInputAgainstExpectedOutput(@"test\033[1C\n", @"test\n");
    CheckInputAgainstExpectedOutput(@"\033[2J\033[1;1HTest\033[2;1HAbc", @"Test\nAbc");

    CheckInputAgainstExpectedOutput(@"\033[1;80H\n", @"\n");

    // Test that the terminal can a nearly full screen. By that we mean 23 full lines and a non-empty 24th line.
    // This tests how the terminal handles wrapping around at the end of a line.
    NSString *spaceFillingLine = [@"" stringByPaddingToLength:80 withString:@"1234567890" startingAtIndex:0];
    NSString *nearlyFullScreen = [[@"" stringByPaddingToLength:(80 * 23) withString:spaceFillingLine startingAtIndex:0] stringByAppendingString:@"1"];
    CheckInputAgainstExpectedOutput(nearlyFullScreen, nearlyFullScreen);
    NSString *nearlyFullScreenWithNewlines = [[@"" stringByPaddingToLength:(81 * 23) withString:[spaceFillingLine stringByAppendingString:@"\n"] startingAtIndex:0] stringByAppendingString:@"1"];
    CheckInputAgainstExpectedOutput(nearlyFullScreenWithNewlines, nearlyFullScreenWithNewlines);
    NSString *overflowedScreen = [[@"" stringByPaddingToLength:(80 * 26) withString:spaceFillingLine startingAtIndex:0] stringByAppendingString:@"1"];
    CheckInputAgainstExpectedOutput(overflowedScreen, overflowedScreen);

    // Writing characters past the terminal limit should overwrite the newline present on that line.
    CheckInputAgainstExpectedOutput(@"\033[1;1H\n\033[1;79Habcde", @"                                                                              abcde");
}

- (void)testCursorBackward;
{
    CheckInputAgainstExpectedOutput(@"abcd\033[De", @"abce");
    CheckInputAgainstExpectedOutput(@"abcd\033[0De", @"abce");
    CheckInputAgainstExpectedOutput(@"abcd\033[1De", @"abce");
    CheckInputAgainstExpectedOutput(@"abcd\033[2De", @"abed");

    CheckInputAgainstExpectedOutput(@"\033[1;80Ha\033[1Db", @"                                                                               b");
    CheckInputAgainstExpectedOutput(@"\033[1;80Ha\n\033[1Db", @"                                                                               a\nb");
}

- (void)testCursorForward;
{
    CheckInputAgainstExpectedOutput(@"a\033[0Cb", @"a b");
    CheckInputAgainstExpectedOutput(@"a\033[1Cb", @"a b");
    CheckInputAgainstExpectedOutput(@"a\033[2Cb", @"a  b");

    // Test wrap-around.
    CheckInputAgainstExpectedOutput(@"a\033[1000Cb", @"a                                                                              b");
    CheckInputAgainstExpectedOutput(@"a\033[1000Cbc", @"a                                                                              bc");

    CheckInputAgainstExpectedOutput(@"\033[1;80Habcd\033[1;80H\033[2Cef", @"                                                                               efcd");
}

- (void)testCursorUp;
{
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\033[1A", @"", MMPositionMake(1, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"a\n\033[1Ab", @"b\n", MMPositionMake(2, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"a\n\033[Ab", @"b\n", MMPositionMake(2, 1))    ;
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"a\n\033[0Ab", @"b\n", MMPositionMake(2, 1));
    CheckInputAgainstExpectedOutput(@"\033[3;80Ha\033[1Ab", @"\n                                                                               b\n                                                                               a");
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\n\n\n\n\033[100A", @"\n\n\n\n", MMPositionMake(1, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\nabc\033[1A", @"\nabc", MMPositionMake(4, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\nabc\033[1Ad", @"   d\nabc", MMPositionMake(5, 1));

    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\033[10B\033[10A", @"", MMPositionMake(1, 1));
}

- (void)testCursorPosition;
{
    // TODO: Also test ending the escape sequence with a f.

    // Bounds tests.
    CheckInputAgainstExpectedOutput(@"\033[0;0Ha", @"a");
    CheckInputAgainstExpectedOutput(@"b\033[Ha", @"a");
    CheckInputAgainstExpectedOutput(@"a\033[2Hb", @"a\nb");
    CheckInputAgainstExpectedOutput(@"\033[1;800Ha", @"                                                                               a");
    CheckInputAgainstExpectedOutput(@"\033[2;800Ha", @"\n                                                                               a");
    CheckInputAgainstExpectedOutput(@"\033[1;79Ha", @"                                                                              a");
    CheckInputAgainstExpectedOutput(@"\033[23;1Ha", [[@"" stringByPaddingToLength:22 withString:@"\n" startingAtIndex:0] stringByAppendingString:@"a"]);
    CheckInputAgainstExpectedOutput(@"\033[24;1Ha", [[@"" stringByPaddingToLength:23 withString:@"\n" startingAtIndex:0] stringByAppendingString:@"a"]);
    // Both of these are expected failures:
    CheckInputAgainstExpectedOutput(@"\033[24;80Ha", [[@"" stringByPaddingToLength:23 withString:@"\n" startingAtIndex:0] stringByAppendingString:@"                                                                               a"]);
    CheckInputAgainstExpectedOutput(@"\033[100;100Ha", [[@"" stringByPaddingToLength:23 withString:@"\n" startingAtIndex:0] stringByAppendingString:@"                                                                               a"]);

    CheckInputAgainstExpectedOutput(@"\033[2;1Ha", @"\na");
    CheckInputAgainstExpectedOutput(@"\033[2;2Ha", @"\n a");

    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\033[1;80Ha\n", @"                                                                               a\n", MMPositionMake(1, 2));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\033[2;1H\n", @"\n\n", MMPositionMake(1, 3));
}

- (void)testDeleteCharacter;
{
    // When we are pushed past the right margin, deleting one character should still remove a character from that line.
    CheckInputAgainstExpectedOutput(@"abc\033[1P", @"abc");
    CheckInputAgainstExpectedOutput(@"abc\033[1D\033[P", @"ab");
    CheckInputAgainstExpectedOutput(@"abc\033[1D\033[0P", @"ab");
    CheckInputAgainstExpectedOutput(@"abc\033[1D\033[1P", @"ab");
    CheckInputAgainstExpectedOutput(@"abc\033[1D\033[2P", @"ab");
    CheckInputAgainstExpectedOutput(@"\033[1;80Ha\033[1P", @"                                                                               ");
    CheckInputAgainstExpectedOutput(@"abc\033[1;1H\033[3P", @"");
    CheckInputAgainstExpectedOutput(@"abcd\033[1;1H\033[3P", @"d");
    // This escape sequence is handled differently by xterm, iTerm 2 and Terminal.app.
    CheckInputAgainstExpectedOutput(@"\033[1;80Ha\033[1Pb", @"                                                                                b");
    CheckInputAgainstExpectedOutput(@"12345678901234567890123456789012345678901234567890123456789012345678901234567890\033[1;1H\033[1P", @"2345678901234567890123456789012345678901234567890123456789012345678901234567890");
    CheckInputAgainstExpectedOutput(@"12345678901234567890123456789012345678901234567890123456789012345678901234567890123\033[1;1H\033[1P", @"2345678901234567890123456789012345678901234567890123456789012345678901234567890\n123");
}

- (void)testInsertLine;
{
    CheckInputAgainstExpectedOutput(@"a\nb\nc\nd\ne\033[1;1H\033[L", @"\na\nb\nc\nd\ne");
    CheckInputAgainstExpectedOutput(@"a\nb\nc\nd\ne\033[1;1H\033[0L", @"\na\nb\nc\nd\ne");
    CheckInputAgainstExpectedOutput(@"a\nb\nc\nd\ne\033[1;1H\033[1L", @"\na\nb\nc\nd\ne");
    CheckInputAgainstExpectedOutput(@"a\nb\nc\nd\ne\033[1;1H\033[3L", @"\n\n\na\nb\nc\nd\ne");

    // This tests whether the cursor is reset to the left margin after an insert line. (Section 4.11 of the vt220 manual states this behaviour.)
    // Screen, iTerm 2 and Terminal.app do not implement this behaviour while xterm does.
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"abc\ndef\033[1;2H\033[1Lg", @"g\nabc\ndef", MMPositionMake(2, 1));

    CheckInputAgainstExpectedOutput(@"\033[24;1H12345678901234567890123456789012345678901234567890123456789012345678901234567890\033[10;1H\033[100L", @"\n\n\n\n\n\n\n\n\n\n");
    CheckInputAgainstExpectedOutput(@"\033[24;1Habc\033[23;1H\033[1Ld", [[@"" stringByPaddingToLength:22 withString:@"\n" startingAtIndex:0] stringByAppendingString:@"d\n"]);
    CheckInputAgainstExpectedOutput(@"\033[24;1Ha\033[1Lb", [[@"" stringByPaddingToLength:23 withString:@"\n" startingAtIndex:0] stringByAppendingString:@"b"]);
}

- (void)testDeleteLine;
{
    CheckInputAgainstExpectedOutput(@"\033[10M", @"");
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"abc\033[M", @"", MMPositionMake(1, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"abc\033[0M", @"", MMPositionMake(1, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"abc\033[1M", @"", MMPositionMake(1, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"abc\033[2M", @"", MMPositionMake(1, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"abc\ndef\033[1;1H\033[1M", @"def", MMPositionMake(1, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\033[24;1Habc\033[1M", [@"" stringByPaddingToLength:23 withString:@"\n" startingAtIndex:0], MMPositionMake(1, 24));
}

- (void)testBeep;
{
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\a", @"", MMPositionMake(1, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"1\a", @"1", MMPositionMake(2, 1));
    CheckInputAgainstExpectedOutput(@"\a\a\a\a\a\a\a\a\a", @"");
}

- (void)testScrolling;
{
    CheckInputAgainstExpectedOutput(@"\033[0;1ra\nb\nc\nd\ne\nf\n", @"a\nb\nc\nd\ne\nf\n");
    CheckInputAgainstExpectedOutput(@"\033[1;1ra\nb\nc\nd\ne\nf\n", @"a\nb\nc\nd\ne\nf\n");
    CheckInputAgainstExpectedOutput(@"\033[1;100ra\nb\nc\nd\ne\nf\n", @"a\nb\nc\nd\ne\nf\n");

    CheckInputAgainstExpectedOutput(@"\033[2;3ra\nb\nc\nd\ne\nf\n", @"a\nf\n");
    CheckInputAgainstExpectedOutput(@"\033[2;5ra\nb\nc\nd\ne\nf\n", @"a\nd\ne\nf\n");
}

@end
