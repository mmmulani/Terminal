//
//  MMCommandLineParserTests.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/7/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMCommandLineParserTests.h"
#import "MMParserContext.h"
#import "MMCommandLineArgumentsParser.h"
#import "MMCommandGroup.h"

#import <OCMock/OCMock.h>

@interface MMCommand (mock)

+ (NSString *)homeDirectoryForUser:(NSString *)user;
+ (NSString *)homeDirectoryForCurrentUser;

@end

@implementation MMCommandLineParserTests

#define CompareInputAgainstExpectedParsedOutput(input, output) \
do {\
    id result = [[[MMParserContext alloc] init] parseString:input forTokens:NO]; \
    id a2 = (output); \
    STAssertEqualObjects([result valueForKey:@"textOnlyForm"], a2, @"Compared parser output to provided output."); \
} while (0)

#define CompareInputAgainstEscapedArgument(input, output) \
do {\
    NSString *result = [MMCommand unescapeArgument:input]; \
    STAssertEqualObjects(result, output, @"Compared parser output to provided output."); \
} while (0)

- (void)testCommandSplitting;
{
    CompareInputAgainstExpectedParsedOutput(@"echo", @[@[@[@"echo"]]]);
    CompareInputAgainstExpectedParsedOutput(@";echo", (@[@[], @[@[@"echo"]]]));
    CompareInputAgainstExpectedParsedOutput(@";echo;", (@[@[], @[@[@"echo"]]]));
    CompareInputAgainstExpectedParsedOutput(@"ec\"ho\"", @[@[@[@"ec\"ho\""]]]);
    CompareInputAgainstExpectedParsedOutput(@"echo 1 2 3; test", (@[@[@[@"echo", @"1", @"2", @"3"]], @[@[@"test"]]]));
    CompareInputAgainstExpectedParsedOutput(@"cp \"test file\" a.out", (@[@[@[@"cp", @"\"test file\"", @"a.out"]]]));
}

- (void)testSemicolonHandling;
{
    CompareInputAgainstExpectedParsedOutput(@"echo 123 ; touch test", (@[@[@[@"echo", @"123"]], @[@[@"touch", @"test"]]]));
    CompareInputAgainstExpectedParsedOutput(@"echo 123; touch test", (@[@[@[@"echo", @"123"]], @[@[@"touch", @"test"]]]));
    CompareInputAgainstExpectedParsedOutput(@"echo 123 ;touch test", (@[@[@[@"echo", @"123"]], @[@[@"touch", @"test"]]]));
    CompareInputAgainstExpectedParsedOutput(@"echo 123;touch test", (@[@[@[@"echo", @"123"]], @[@[@"touch", @"test"]]]));
}

- (void)testArgumentUnescaping;
{
    CompareInputAgainstEscapedArgument(@"echo", @"echo");
    CompareInputAgainstEscapedArgument(@"ec\"ho\"", @"echo");
    CompareInputAgainstEscapedArgument(@"ec\"\\u0068\\u006f\"", @"echo");
    CompareInputAgainstEscapedArgument(@"\"\\uffff\"", @"\uffff");
    CompareInputAgainstEscapedArgument(@"\"\\033\"", @"\033");
    CompareInputAgainstEscapedArgument(@"\"\\xff\"", @"\u00ff");
    CompareInputAgainstEscapedArgument(@"t\"es\"t", @"test");
    CompareInputAgainstEscapedArgument(@"\"multiple words\"", @"multiple words");
}

- (void)testUnescapedArguments;
{
    NSArray *commands = [MMCommandLineArgumentsParser tokensFromCommandLineWithoutEscaping:@"test 123 ; echo 456"];
    STAssertEqualObjects(commands, (@[@"test", @"123", @"echo", @"456"]), @"");

    MMCommand *command = [MMCommand new];
    command.arguments = [@[@"ls", @"~/Documents"] mutableCopy];
    id commandMock = [OCMockObject partialMockForObject:command];
    [[[commandMock stub] andReturn:@"/Users/test"] homeDirectoryForCurrentUser];
    STAssertEqualObjects([commandMock unescapedArguments], (@[@"ls", @"/Users/test/Documents"]), @"");
    [commandMock stopMocking];

    command = [MMCommand new];
    command.arguments = [@[@"echo", @"~test", @"~root/lol"] mutableCopy];
    commandMock = [OCMockObject partialMockForObject:command];
    [[[commandMock stub] andReturn:@"/Users/test"] homeDirectoryForUser:@"test"];
    [[[commandMock stub] andReturn:@"/Users/root"] homeDirectoryForUser:@"root"];
    STAssertEqualObjects([commandMock unescapedArguments], (@[@"echo", @"/Users/test", @"/Users/root/lol"]), @"");
    [commandMock stopMocking];
}

- (void)testTokenEndings;
{
    NSArray *tokenEndings = [MMCommandLineArgumentsParser tokenEndingsFromCommandLine:@"abc def; ghi"];
    STAssertEqualObjects(tokenEndings, (@[@3, @7, @12]), @"");

    NSArray *tokenEndingsWithAccent = [MMCommandLineArgumentsParser tokenEndingsFromCommandLine:@"cd Améli"];
    STAssertEqualObjects(tokenEndingsWithAccent, (@[@2, @8]), @"");

    NSArray *tokenEndingsWithRedirection = [MMCommandLineArgumentsParser tokenEndingsFromCommandLine:@"echo test < /dev/null > /dev/test"];
    STAssertEqualObjects(tokenEndingsWithRedirection, (@[@4, @9, @21, @33]), @"");
}

- (void)testInputOutputRedirection;
{
    MMCommandGroup *commandGroup = [MMCommandLineArgumentsParser commandGroupsFromCommandLine:@"echo test > /dev/null < /input/file"][0];
    MMCommand *command = commandGroup.commands[0];
    STAssertEquals(command.standardInputSourceType, MMSourceTypeFile, @"");
    STAssertEqualObjects(command.standardInput, @"/input/file", @"");
    STAssertEquals(command.standardOutputSourceType, MMSourceTypeFile, @"");
    STAssertEqualObjects(command.standardOutput, @"/dev/null", @"");
    STAssertEqualObjects(command.arguments, (@[@"echo", @"test"]), @"");

    MMCommandGroup *unescapedCommandGroup = [MMCommandLineArgumentsParser commandGroupsFromCommandLine:@"echo test > /dev/\"\\u00e9\"test"][0];
    MMCommand *unescapedCommandTest = unescapedCommandGroup.commands[0];
    STAssertEqualObjects(unescapedCommandTest.standardOutput, @"/dev/étest", @"Testing whether standard output is unescaped");

    MMCommandGroup *pipedCommandGroup = [MMCommandLineArgumentsParser commandGroupsFromCommandLine:@"echo test | cat -"][0];
    STAssertEquals(pipedCommandGroup.commands.count, (NSUInteger)2, @"");
    MMCommand *echoCommand = pipedCommandGroup.commands[0];
    STAssertEqualObjects(echoCommand.arguments, (@[@"echo", @"test"]), @"");
    STAssertEquals(echoCommand.standardInputSourceType, MMSourceTypeDefault, @"");
    STAssertEquals(echoCommand.standardOutputSourceType, MMSourceTypePipe, @"");
    MMCommand *catCommand = pipedCommandGroup.commands[1];
    STAssertEqualObjects(catCommand.arguments, (@[@"cat", @"-"]), @"");
    STAssertEquals(catCommand.standardInputSourceType, MMSourceTypePipe, @"");
    STAssertEquals(echoCommand.standardInputSourceType, MMSourceTypeDefault, @"");
}

@end
