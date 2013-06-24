//
//  ANSIEscapeSequencesTests.m
//  ANSIEscapeSequencesTests
//
//  Created by Mehdi Mulani on 3/10/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "ANSIEscapeSequencesTests.h"
#import "MMTask.h"
#import "MMTestHelpers.h"

@interface ANSIEscapeSequencesTests ()

@property NSArray *twentyFourNumberedLines;

@end

@implementation ANSIEscapeSequencesTests

- (void)setUp;
{
    [super setUp];

    NSMutableArray *numberedLines = [NSMutableArray array];
    for (NSInteger i = 1; i <= 24; i++) {
        [numberedLines addObject:[[NSString stringWithFormat:@"%ld", i] stringByPaddingToLength:80 withString:@"-" startingAtIndex:0]];
    }
    self.twentyFourNumberedLines = numberedLines;
}

- (void)tearDown;
{
    // Tear-down code here.
    
    [super tearDown];
}

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
    CheckInputAgainstExpectedOutput(@"1\n2\n345\033[3;2H\033[J", @"1\n2\n3");

    CheckInputAgainstExpectedOutput(@"1\n2\n345\033[3;2H\033[0J", @"1\n2\n3");
    CheckInputAgainstExpectedOutput(@"1\n2\n3\n4\n5\n\033[2;1H\033[0J", @"1\n");
    CheckInputAgainstExpectedOutput(@"\033[0J\n\n", @"\n\n");

    CheckInputAgainstExpectedOutput(@"1\n2\033[1J_", @"\n _");
    CheckInputAgainstExpectedOutput(@"1\n2\033[2;1H\033[1J", @"");
    CheckInputAgainstExpectedOutput(@"1\n2\n3\033[2;1H\033[1J", @"\n\n3");
    CheckInputAgainstExpectedOutput([[@"" stringByPaddingToLength:82 withString:@" " startingAtIndex:0] stringByAppendingString:@"\033[1;80H\033[1J"], @"\n  ");
    CheckInputAgainstExpectedOutput(@"abc\033[1;2H\033[1J", @"  c");

    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\033[2J", @"", MMPositionMake(1,1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"_\033[2J", @"", MMPositionMake(2,1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"_\033[2Ja", @" a", MMPositionMake(3,1));
    CheckInputAgainstExpectedOutput(@"__\033[2Ja", @"  a");
    CheckInputAgainstExpectedOutput(@"12\n34\n\033[2J", @"");

    // The rest of these tests are against crashes.
    NSString *lotsOfNewLines = [@"" stringByPaddingToLength:80 withString:@"\n" startingAtIndex:0];
    CheckInputAgainstExpectedOutput([lotsOfNewLines stringByAppendingString:@"\033[2J"], [@"" stringByPaddingToLength:(80 - 23) withString:@"\n" startingAtIndex:0]);

    CheckInputAgainstExpectedOutput(@"\033[0J\033[2J", @"");
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

    CheckInputAgainstExpectedOutput(@"abc\ndef\033[2G_", @"abc\nd_f");
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

    // Test that the terminal can handle nearly full screen. By that we mean 23 full lines and a non-empty 24th line.
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

    CheckInputAgainstExpectedOutput([[@"" stringByPaddingToLength:160 withString:@" " startingAtIndex:0] stringByAppendingString:@"\r\r\nA"], [[@"" stringByPaddingToLength:160 withString:@" " startingAtIndex:0] stringByAppendingString:@"\nA"]);

    // Test that a raw newline does not change the cursor position.
    CheckRawInputAgainstExpectedOutput(@"A\nB", @"A\n B");
    CheckRawInputAgainstExpectedOutput(@"A\n\nB", @"A\n\n B");
    CheckRawInputAgainstExpectedOutput(@"A\n\r\nB", @"A\n\nB");
}

- (void)testVerticalTabulationAndFormFeed;
{
    CheckInputAgainstExpectedOutput(@"A\013B", @"A\n B");
    CheckInputAgainstExpectedOutput(@"A\014B", @"A\n B");
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

- (void)testCursorDown;
{
    CheckInputAgainstExpectedOutput(@"A\033[BB", @"A\n B");
    CheckInputAgainstExpectedOutput(@"A\033[0BB", @"A\n B");
    CheckInputAgainstExpectedOutput(@"A\033[1BB", @"A\n B");
    CheckInputAgainstExpectedOutput(@"A\033[3BB", @"A\n\n\n B");

    NSString *twentyThreeNewlines = [@"" stringByPaddingToLength:23 withString:@"\n" startingAtIndex:0];
    CheckInputAgainstExpectedOutput(@"A\033[100BB", ([NSString stringWithFormat:@"A%@ B", twentyThreeNewlines]));
    NSString *seventyNineSpaces = [@"" stringByPaddingToLength:79 withString:@" " startingAtIndex:0];
    CheckInputAgainstExpectedOutput(@"\033[24;80HA\033[1BB", ([NSString stringWithFormat:@"%@%@B", twentyThreeNewlines, seventyNineSpaces]));
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

- (void)testClearingUntilEndOfLine;
{
    // Test handling the default case.
    CheckInputAgainstExpectedOutput(@"abc\033[1;2H\033[K", @"a");

    CheckInputAgainstExpectedOutput(@"abc\033[1;1H\033[0K", @"");
    CheckInputAgainstExpectedOutput(@"abc\033[1;2H\033[0K", @"a");
    CheckInputAgainstExpectedOutput(@"abc\033[1;3H\033[0K", @"ab");
    CheckInputAgainstExpectedOutput(@"abc\033[1;4H\033[0K", @"abc");
    CheckInputAgainstExpectedOutput(@"abc\033[1;20H\033[0K", @"abc");

    CheckInputAgainstExpectedOutput(@"a\033[1;1H\033[1K", @"");
    CheckInputAgainstExpectedOutput(@"\033[1K", @"");
    CheckInputAgainstExpectedOutput(@"abc\033[1;2H\033[1K", @"  c");

    CheckInputAgainstExpectedOutput(@"abc\033[1;2H\033[2K", @"");
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

    CheckInputAgainstExpectedOutput(@"\033[24;1H12345678901234567890123456789012345678901234567890123456789012345678901234567890\033[10;1H\033[100L", @"\n\n\n\n\n\n\n\n\n");
    CheckInputAgainstExpectedOutput(@"\033[24;1Habc\033[23;1H\033[1Ld", [[[@"" stringByPaddingToLength:22 withString:@"\n" startingAtIndex:0] stringByAppendingString:@"d"] stringByAppendingString:@"\n"]);
    CheckInputAgainstExpectedOutput(@"\033[24;1Ha\033[1Lb", [[@"" stringByPaddingToLength:23 withString:@"\n" startingAtIndex:0] stringByAppendingString:@"b"]);

    // Make sure that nothing happens when we are not in the scroll region.
    CheckInputAgainstExpectedOutput(@"a\nb\nc\033[2;3r\033[1;1H\033[1L", @"a\nb\nc");

    // Make sure that the bottom line doesn't inherit a newline character when it is pushed down by the insert line command.
    CheckInputAgainstExpectedOutput(@"\033[23;1HA\n\033[1;1H\033[L", [[@"" stringByPaddingToLength:23 withString:@"\n" startingAtIndex:0] stringByAppendingString:@"A"]);

    // Test inserting lots of lines.
    CheckInputAgainstExpectedOutput(@"1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12\n13\n14\n15\n16\n17\n18\n19\n20\n21\n22\n23\n24\033[2;1H\033[22M\033[22L", @"1\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n24");
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

    CheckInputAgainstExpectedOutput(@"a\nb\nc\nd\ne\nf\033[1;3r\033[4;1H\033[1M", @"a\nb\nc\nd\ne\nf");
    CheckInputAgainstExpectedOutput(@"a\nb\nc\nd\ne\nf\033[1;3r\033[1;1H\033[1M", @"b\nc\n\nd\ne\nf");
    CheckInputAgainstExpectedOutput(@"a\nb\nc\nd\ne\nf\033[1;3r\033[1;1H\033[2M", @"c\n\n\nd\ne\nf");
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

    CheckInputAgainstExpectedOutput(@"\033[2;5r\033[6;1H\n", @"\n\n\n\n\n\n");

    CheckInputAgainstExpectedOutput(@"123\n456\033[3;10r789", @"789\n456");
}

- (void)testPossibleCrashers;
{
    CheckThatInputDoesNotCauseACrash(@"\033[M\033[24;1Ha");

    MMTask *task = [MMTask new];
    [task handleCommandOutput:@"\033[0J\n\n\n"];
    STAssertEquals(task.cursorPositionByCharacters, (NSInteger)3, @"Should not crash in looking at the cursor position for a row which does not exist");

    CheckInputAgainstExpectedOutput(([NSString stringWithFormat:@"\033[%@HA", [@"" stringByPaddingToLength:875 withString:@"1;" startingAtIndex:0]]), @"A");

    CheckInputAgainstExpectedOutput(@"\033[0J\033D\033[0J", @"");
    CheckInputAgainstExpectedOutput([@"\033[0J" stringByPaddingToLength:300 withString:@"A" startingAtIndex:0], [@"" stringByPaddingToLength:296 withString:@"A" startingAtIndex:0]);
}

- (void)testReverseIndex;
{
    NSString *riTest = [[self.twentyFourNumberedLines componentsJoinedByString:@""] stringByAppendingString:@"\033[1;5H\033M"];
    NSString *riTestOutput = [@"\n" stringByAppendingString:[[self.twentyFourNumberedLines subarrayWithRange:NSMakeRange(0, 23)]componentsJoinedByString:@""]];
    CheckInputAgainstExpectedOutputWithExpectedCursor(riTest, riTestOutput, MMPositionMake(5, 1));

    NSString *scrollRiTest = [[self.twentyFourNumberedLines componentsJoinedByString:@""] stringByAppendingString:@"\033[5;10r\033[5;1H\033M"];
    NSString *scrollRiOutput = [NSString stringWithFormat:@"%@%@%@%@",
                                [[self.twentyFourNumberedLines subarrayWithRange:NSMakeRange(0, 4)] componentsJoinedByString:@""],
                                @"\n",
                                [[self.twentyFourNumberedLines subarrayWithRange:NSMakeRange(4, 5)] componentsJoinedByString:@""],
                                [[self.twentyFourNumberedLines subarrayWithRange:NSMakeRange(10, 14)] componentsJoinedByString:@""]];
    CheckInputAgainstExpectedOutputWithExpectedCursor(scrollRiTest, scrollRiOutput, MMPositionMake(1, 5));

    // Test that the last newline is removed from the last line.
    CheckInputAgainstExpectedOutput([[@"1" stringByPaddingToLength:24 withString:@"\n" startingAtIndex:0] stringByAppendingString:@"!\033[1;1H\033M"], [@"\n1" stringByPaddingToLength:24 withString:@"\n" startingAtIndex:0]);

    CheckInputAgainstExpectedOutput(@"A\033MB\033MC", @"  C\n B\nA");
    CheckInputAgainstExpectedOutput(@"\033[3;10rA\033MB", @"AB");
    CheckInputAgainstExpectedOutput(@"\033[3;10rA\033MB\033MC", @"ABC");
}

- (void)testIndex;
{
    CheckInputAgainstExpectedOutput([[self.twentyFourNumberedLines componentsJoinedByString:@""] stringByAppendingString:@"\033D!"], [[self.twentyFourNumberedLines componentsJoinedByString:@""] stringByAppendingString:@"!"]);
    CheckInputAgainstExpectedOutput([[self.twentyFourNumberedLines componentsJoinedByString:@""] stringByAppendingString:@"\033[24;5H\033D!"], [[self.twentyFourNumberedLines componentsJoinedByString:@""] stringByAppendingString:@"    !"]);
    // Make sure that newline is added if necessary.
    CheckInputAgainstExpectedOutput([[@"" stringByPaddingToLength:23 withString:@"\n" startingAtIndex:0] stringByAppendingString:@"\033[24;5H\033D!"], [[@"" stringByPaddingToLength:24 withString:@"\n" startingAtIndex:0] stringByAppendingString:@"    !"]);
}

- (void)testNextLine;
{
    CheckInputAgainstExpectedOutput(@"\033E!", @"\n!");
    CheckInputAgainstExpectedOutput([[@"" stringByPaddingToLength:79 withString:@" " startingAtIndex:0] stringByAppendingString:@"\033E_"], [[@"" stringByPaddingToLength:79 withString:@" " startingAtIndex:0] stringByAppendingString:@"\n_"]);
    CheckInputAgainstExpectedOutput([[@"" stringByPaddingToLength:80 withString:@" " startingAtIndex:0] stringByAppendingString:@"\033E_"], [[@"" stringByPaddingToLength:80 withString:@" " startingAtIndex:0] stringByAppendingString:@"_"]);
    CheckInputAgainstExpectedOutput([[self.twentyFourNumberedLines componentsJoinedByString:@""] stringByAppendingString:@"\033E!"], [[self.twentyFourNumberedLines componentsJoinedByString:@""] stringByAppendingString:@"!"]);
    CheckInputAgainstExpectedOutput([[@"" stringByPaddingToLength:23 withString:@"\n" startingAtIndex:0] stringByAppendingString:@"\033[1;10r\033[24;1H1\033E2"], [[@"" stringByPaddingToLength:23 withString:@"\n" startingAtIndex:0] stringByAppendingString:@"2"]);
}

- (void)testScreenAlignmentTest;
{
    CheckInputAgainstExpectedOutput(@"\033#8\033[2Ja", @"a");
    NSMutableArray *lines = [NSMutableArray array];
    for (NSInteger i = 0; i < 24; i++) {
        [lines addObject:[@"" stringByPaddingToLength:80 withString:@"E" startingAtIndex:0]];
    }
    CheckInputAgainstExpectedOutput(@"\033#8", [lines componentsJoinedByString:@"\n"]);
}

- (void)testAutowrapMode;
{
    // Test that autowrap is on by default.
    NSString *longString = [@"" stringByPaddingToLength:250 withString:@"123" startingAtIndex:0];
    CheckInputAgainstExpectedOutput(longString, longString);

    // The behaviour autowrap and rather surprising compared to the expected behaviour.
    // With autowrap disabled:
    // - when a large block of text is to be printed, it will only print up to the end of the line, and it will only print enough characters to fill the screen. That is, the tail end may not be printed.
    // - when a block of text is about to be printed, if it is past the right margin, it will be moved to within the screen and then the print operation will commence.
    NSString *longerThanLineString = [@"" stringByPaddingToLength:85 withString:@"1234567890" startingAtIndex:0];
    NSString *expectedOutput = [longerThanLineString substringToIndex:80];
    CheckInputAgainstExpectedOutput([@"\033[?7l" stringByAppendingString:longerThanLineString], expectedOutput);

    CheckInputAgainstExpectedOutput(@"\033[?7l\033[1;80HA\033[mB", [[@"" stringByPaddingToLength:79 withString:@" " startingAtIndex:0] stringByAppendingString:@"B"]);

    CheckInputAgainstExpectedOutput(@"12345678901234567890123456789012345678901234567890123456789012345678901234567890\n"
                                    "12345678901234567890123456789012345678901234567890123456789012345678901234567890\033[?7l\033[1;80HAB",
                                    @"1234567890123456789012345678901234567890123456789012345678901234567890123456789A\n"
                                    "12345678901234567890123456789012345678901234567890123456789012345678901234567890");

    // This tests against a crash.
    CheckInputAgainstExpectedOutput(@"\033[?7l12345678901234567890123456789012345678901234567890123456789012345678901234567890\033[1;1HA", @"A2345678901234567890123456789012345678901234567890123456789012345678901234567890");
}

- (void)testOriginMode;
{
    // Test that origin mode is off by default.
    CheckInputAgainstExpectedOutput(@"\033[5;6r\033[1;1HA", @"A");
    CheckInputAgainstExpectedOutput(@"\033[?6h\033[?6l\033[5;6r\033[1;1HA", @"A");

    // Test double enabling and then removing once still turns it off.
    CheckInputAgainstExpectedOutput(@"\033[?6h\033[?6h\033[?6l\033[5;6r\033[1;1HA", @"A");

    CheckInputAgainstExpectedOutput(@"\033[?6h\033[5;6r\033[0;1HA", @"\n\n\n\nA");
    CheckInputAgainstExpectedOutput(@"\033[?6h\033[5;6r\033[1;1HA", @"\n\n\n\nA");
    CheckInputAgainstExpectedOutput(@"\033[?6h\033[5;6r\033[2;1HA", @"\n\n\n\n\nA");
    CheckInputAgainstExpectedOutput(@"\033[?6h\033[5;6r\033[100;1HA", @"\n\n\n\n\nA");
    CheckInputAgainstExpectedOutput(@"\033[?6h\033[5;7r\033[100;1HA", @"\n\n\n\n\n\nA");
}

- (void)testBackspace;
{
    CheckInputAgainstExpectedOutput(@"1\b", @"1");
    CheckInputAgainstExpectedOutput(@"1\b2", @"2");
    CheckInputAgainstExpectedOutput(@"1\b\b2", @"2");
    CheckInputAgainstExpectedOutput(@"1 \b2", @"12");
    CheckInputAgainstExpectedOutput(@"\033[1;80H1\b2", [[@"" stringByPaddingToLength:78 withString:@" " startingAtIndex:0] stringByAppendingString:@"21"]);

    CheckInputAgainstExpectedOutput(@"\033[1;80H12\b\b\b3", [[@"" stringByPaddingToLength:78 withString:@" " startingAtIndex:0] stringByAppendingString:@"312"]);
    CheckInputAgainstExpectedOutput(@"\033[1;80H12\b\b3", [[@"" stringByPaddingToLength:79 withString:@" " startingAtIndex:0] stringByAppendingString:@"32"]);
    CheckInputAgainstExpectedOutput(@"\033[1;80H12\b3", [[@"" stringByPaddingToLength:79 withString:@" " startingAtIndex:0] stringByAppendingString:@"13"]);

    CheckInputAgainstExpectedOutput(@"\033[1;80H1\n\b2", [[@"" stringByPaddingToLength:79 withString:@" " startingAtIndex:0] stringByAppendingString:@"1\n2"]);
    CheckInputAgainstExpectedOutput(@"\033[1;80H1\n\b\b2", [[@"" stringByPaddingToLength:79 withString:@" " startingAtIndex:0] stringByAppendingString:@"1\n2"]);
    CheckInputAgainstExpectedOutputWithExpectedCursor([[@"" stringByPaddingToLength:80 withString:@" " startingAtIndex:0] stringByAppendingString:@"a\bb"], [[@"" stringByPaddingToLength:80 withString:@" " startingAtIndex:0] stringByAppendingString:@"b"], MMPositionMake(2, 2));
}

- (void)testTabs;
{
    // Test default tab positions.
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\t", @"\t", MMPositionMake(9, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\t\t", @"\t\t", MMPositionMake(17, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\t\t\t", @"\t\t\t", MMPositionMake(25, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\t\t\t\t", @"\t\t\t\t", MMPositionMake(33, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\t\t\t\t\t", @"\t\t\t\t\t", MMPositionMake(41, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\t\t\t\t\t\t", @"\t\t\t\t\t\t", MMPositionMake(49, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\t\t\t\t\t\t\t", @"\t\t\t\t\t\t\t", MMPositionMake(57, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\t\t\t\t\t\t\t\t", @"\t\t\t\t\t\t\t\t", MMPositionMake(65, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\t\t\t\t\t\t\t\t\t", @"\t\t\t\t\t\t\t\t\t", MMPositionMake(73, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\t\t\t\t\t\t\t\t\t\t", @"\t\t\t\t\t\t\t\t\t\t", MMPositionMake(80, 1));

    // Test handling tabs at the end of the line.
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\t\t\t\t\t\t\t\t\t\t\t", @"\t\t\t\t\t\t\t\t\t\t", MMPositionMake(80, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\t\t\t\t\t\t\t\t\t\t\t\t", @"\t\t\t\t\t\t\t\t\t\t", MMPositionMake(80, 1));
    CheckInputAgainstExpectedOutput(@"\t\t\t\t\t\t\t\t\t\ta", @"\t\t\t\t\t\t\t\t\t       a");

    // Test deleting tabs.
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\t\033[g\tb", @"\t\tb", MMPositionMake(18, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\t\033[g\033[1;1H\tb", @"\t       b", MMPositionMake(18, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"a\t\033[g\033[1;1H\tb", @"a\t        b", MMPositionMake(18, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"a\t\033[g\033[1;1H\t", @"a\t", MMPositionMake(17, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\033[1;9H\033[g\033[1;1H\ta", @"\ta", MMPositionMake(18, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\033[1;9H\033[g\033[1;17H\033[g\033[1;1H\ta", @"\ta", MMPositionMake(26, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\t\033[g\t\033[g\033[1;1H\ta", @"\t\t        a", MMPositionMake(26, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\t\033[g\t\033[g\033[1;1H\t\ta", @"\t\t        \ta", MMPositionMake(34, 1));

    // Test expansion of the tab character into spaces.
    CheckInputAgainstExpectedOutput(@"\ta", @"\ta");
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"\033[1;2H\ta", @" \ta", MMPositionMake(10, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"abcdefg\ti", @"abcdefg\ti", MMPositionMake(10, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"a\033[1;3H\ti", @"a \ti", MMPositionMake(10, 1));
    CheckInputAgainstExpectedOutput(@"\t\033[1;2Ha", @" a      ");
    CheckInputAgainstExpectedOutput(@"\t\033[1;3Ha", @"  a     ");
    CheckInputAgainstExpectedOutput(@"ab\t\033[1;3Hc", @"abc     ");
    CheckInputAgainstExpectedOutput(@"\033[1;9H\033[g\t\033[1;2Ha", @" a      \t");
    CheckInputAgainstExpectedOutput(@"\t\t\033[1;1H123456789", @"123456789       ");
    CheckInputAgainstExpectedOutput(@"\t\t\033[1;1H1234567890", @"1234567890      ");

    // Test tab characters overwriting other characters.
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"abcdefgh\033[1;1H\ti", @"abcdefghi", MMPositionMake(10, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"abcdefg\033[1;1H\ti", @"abcdefg i", MMPositionMake(10, 1));
    CheckInputAgainstExpectedOutput(@"a\033[1;1H\ti", @"a       i");
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"a\ti", @"a\ti", MMPositionMake(10, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"a\033[1;2H\ti", @"a\ti", MMPositionMake(10, 1));
    CheckInputAgainstExpectedOutput(@"\t\033[1;2H\ta", @"\ta");

    // Test relative cursor movements.

    // Test that the character offset changes by the number of printable characters.
    MMTask *task = [MMTask new];
    [task handleCommandOutput:[@"\t" stringByAppendingString:[@"" stringByPaddingToLength:30 withString:@"\n" startingAtIndex:0]]];
    STAssertEquals(task.cursorPositionByCharacters, (NSInteger)31, @"Cursor should be offset by number of printable characters.");
}

- (void)testFullReset;
{
    CheckInputAgainstExpectedOutput(@"\033c", @"");
    CheckInputAgainstExpectedOutput(@"\033ca", @"a");
    CheckInputAgainstExpectedOutput(@"\nA\033cB", @"B");
}

- (void)testCursorControlInsideEscapeSequence;
{
    CheckInputAgainstExpectedOutput(@"A\033[\b1CB", @"AB");
    CheckInputAgainstExpectedOutput(@"A\033[\b2CB", @"A B");
    CheckInputAgainstExpectedOutput(@" A\033[\b\b1CB", @" B");
    CheckInputAgainstExpectedOutput(@" A\033[\b\b2CB", @" AB");
    CheckInputAgainstExpectedOutput(@" A\033[\b2\bCB", @" AB");
    CheckInputAgainstExpectedOutput(@" A\033[\b2C\bB", @" AB");

    CheckInputAgainstExpectedOutput(@"ABC\033[\r1CD", @"ADC");
    CheckInputAgainstExpectedOutput(@"ABC\033[\b\r1CD", @"ADC");

    CheckInputAgainstExpectedOutput(@"AB\033[1\nCD", @"AB\n D");
    CheckInputAgainstExpectedOutput(@"AB\033[1\n\nCD", @"AB\n\n D");

    CheckInputAgainstExpectedOutputWithExpectedCursor(@"AB\033[1\tCD", @"AB\t D", MMPositionMake(11, 1));
}

- (void)testCharacterSets;
{
    // Test that the Shift Out and Shift In control characters do not get printed.
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"a\016b", @"ab", MMPositionMake(3, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"a\016\016b", @"ab", MMPositionMake(3, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"a\017b", @"ab", MMPositionMake(3, 1));
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"a\017b\017", @"ab", MMPositionMake(3, 1));
}

@end
