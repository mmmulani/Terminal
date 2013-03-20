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
    STAssertEquals(task.cursorPosition.y, cursorPosition_.y, @"X coord of cursor position"); \
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
    CheckInputAgainstExpectedOutputWithExpectedCursor(@"_\033[2J", @" ", MMPositionMake(2,1));
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
}

@end
