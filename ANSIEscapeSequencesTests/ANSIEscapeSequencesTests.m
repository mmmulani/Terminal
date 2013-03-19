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

- (void)checkInput:(NSString *)input againstExpectedOutput:(NSString *)output;
{
    [self checkInput:input againstExpectedOutput:output withExpectedCursor:MMPositionMake(-123, -456)];
}

- (void)checkInput:(NSString *)input againstExpectedOutput:(NSString *)output withExpectedCursor:(MMPosition)cursorPosition;
{
    MMTask *task = [MMTask new];
    [task handleCommandOutput:input withVerbosity:NO];
    STAssertEqualObjects([task.currentANSIDisplay string], output, @"Compared task output to provided output.");

    if (cursorPosition.x != -123 && cursorPosition.y != -456) {
        STAssertEquals(task.cursorPosition.x, cursorPosition.x, @"X coord of cursor position");
        STAssertEquals(task.cursorPosition.y, cursorPosition.y, @"X coord of cursor position");
    }
}

- (void)testNonANSIPrograms;
{
    [self checkInput:@"a" againstExpectedOutput:@"a"];
    [self checkInput:@"a\nb" againstExpectedOutput:@"a\nb"];
    [self checkInput:@"a\nb\n" againstExpectedOutput:@"a\nb\n"];

    // Really long strings shouldn't be separated to multiple lines.
    NSString *longString = [@"" stringByPaddingToLength:100 withString:@"1234567890" startingAtIndex:0];
    [self checkInput:longString againstExpectedOutput:longString];
}

- (void)testClearingScreen;
{
    [self checkInput:@"\033[2J" againstExpectedOutput:@"" withExpectedCursor:MMPositionMake(1,1)];
    [self checkInput:@"_\033[2J" againstExpectedOutput:@" " withExpectedCursor:MMPositionMake(2,1)];
}

- (void)testCursorHorizontalAbsolute;
{
    [self checkInput:@"test\033[GA" againstExpectedOutput:@"Aest"];
    [self checkInput:@"test\033[0GA" againstExpectedOutput:@"Aest"];
    [self checkInput:@"test\033[1GA" againstExpectedOutput:@"Aest"];
    [self checkInput:@"test\033[2GA" againstExpectedOutput:@"tAst"];
    NSString *expectedOutput = [[@"test" stringByPaddingToLength:79 withString:@" " startingAtIndex:0] stringByAppendingString:@"A"];
    [self checkInput:@"test\033[90GA" againstExpectedOutput:expectedOutput];
}

@end
