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
#import "MMUtilities.h"

#import <OCMock/OCMock.h>

@interface MMCommand (mock)

+ (NSString *)homeDirectoryForUser:(NSString *)user;
+ (NSString *)homeDirectoryForCurrentUser;
+ (NSArray *)filesAndFoldersInDirectory:(NSString *)directory;

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
    NSArray *arguments = [MMCommand unescapeArgument:input]; \
    STAssertEquals(arguments.count, (NSUInteger)1, @"Should only find one argument."); \
    NSString *result = arguments[0];\
    STAssertEqualObjects(result, output, @"Compared parser output to provided output."); \
} while (0)

#define CompareArgumentAgainstExpectedEscaped(argument, expected) \
do {\
    NSArray *arguments = [MMCommand unescapeArgument:[MMCommand escapeArgument:argument]]; \
    STAssertEquals(arguments.count, (NSUInteger)1, @"Should only expand to one argument."); \
    STAssertEqualObjects(arguments[0], argument, @"Unescaping and escaping should be idempotent"); \
    STAssertEqualObjects([MMCommand escapeArgument:argument], expected, @"Compared escaped argument to expected."); \
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
    STAssertEqualObjects([commandMock unescapedArgumentsInDirectory:nil], (@[@"ls", @"/Users/test/Documents"]), @"");
    [commandMock stopMocking];

    command = [MMCommand new];
    command.arguments = [@[@"echo", @"~test", @"~root/lol"] mutableCopy];
    commandMock = [OCMockObject partialMockForObject:command];
    [[[commandMock stub] andReturn:@"/Users/test"] homeDirectoryForUser:@"test"];
    [[[commandMock stub] andReturn:@"/Users/root"] homeDirectoryForUser:@"root"];
    STAssertEqualObjects([commandMock unescapedArgumentsInDirectory:nil], (@[@"echo", @"/Users/test", @"/Users/root/lol"]), @"");
    [commandMock stopMocking];

    // Test various globbing patterns.

    command = [MMCommand new];
    command.arguments = [@[@"echo", @"*"] mutableCopy];
    commandMock = [OCMockObject partialMockForObject:command];
    [[[commandMock stub] andReturn:@[@"a", @"bc"]] filesAndFoldersInDirectory:@"/Users/test/"];
    STAssertEqualObjects([commandMock unescapedArgumentsInDirectory:@"/Users/test"], (@[@"echo", @"a", @"bc"]), @"");
    [commandMock stopMocking];

    command = [MMCommand new];
    command.arguments = [@[@"echo", @"**"] mutableCopy];
    commandMock = [OCMockObject partialMockForObject:command];
    [[[commandMock stub] andReturn:@[@"a", @"bc"]] filesAndFoldersInDirectory:@"/Users/test/"];
    STAssertEqualObjects([commandMock unescapedArgumentsInDirectory:@"/Users/test"], (@[@"echo", @"a", @"bc"]), @"");
    [commandMock stopMocking];

    command = [MMCommand new];
    command.arguments = [@[@"echo", @"?"] mutableCopy];
    commandMock = [OCMockObject partialMockForObject:command];
    [[[commandMock stub] andReturn:@[@"a", @"bc"]] filesAndFoldersInDirectory:@"/Users/test/"];
    STAssertEqualObjects([commandMock unescapedArgumentsInDirectory:@"/Users/test"], (@[@"echo", @"a"]), @"");
    [commandMock stopMocking];

    command = [MMCommand new];
    command.arguments = [@[@"echo", @"??"] mutableCopy];
    commandMock = [OCMockObject partialMockForObject:command];
    [[[commandMock stub] andReturn:@[@"123", @"456", @"789"]] filesAndFoldersInDirectory:@"/Users/test/"];
    STAssertEqualObjects([commandMock unescapedArgumentsInDirectory:@"/Users/test"], (@[@"echo"]), @"");
    [commandMock stopMocking];

    command = [MMCommand new];
    command.arguments = [@[@"echo", @"???"] mutableCopy];
    commandMock = [OCMockObject partialMockForObject:command];
    [[[commandMock stub] andReturn:@[@"123", @"456", @"789"]] filesAndFoldersInDirectory:@"/Users/test/"];
    STAssertEqualObjects([commandMock unescapedArgumentsInDirectory:@"/Users/test"], (@[@"echo", @"123", @"456", @"789"]), @"");
    [commandMock stopMocking];

    command = [MMCommand new];
    command.arguments = [@[@"echo", @"?5?"] mutableCopy];
    commandMock = [OCMockObject partialMockForObject:command];
    [[[commandMock stub] andReturn:@[@"123", @"456", @"789"]] filesAndFoldersInDirectory:@"/Users/test/"];
    STAssertEqualObjects([commandMock unescapedArgumentsInDirectory:@"/Users/test"], (@[@"echo", @"456"]), @"");
    [commandMock stopMocking];

    command = [MMCommand new];
    command.arguments = [@[@"echo", @"4??"] mutableCopy];
    commandMock = [OCMockObject partialMockForObject:command];
    [[[commandMock stub] andReturn:@[@"123", @"456", @"789"]] filesAndFoldersInDirectory:@"/Users/test/"];
    STAssertEqualObjects([commandMock unescapedArgumentsInDirectory:@"/Users/test"], (@[@"echo", @"456"]), @"");
    [commandMock stopMocking];
}

- (void)testEscaping;
{
    CompareArgumentAgainstExpectedEscaped(@"test", @"test");
    CompareArgumentAgainstExpectedEscaped(@"test abc", @"test\\ abc");
    CompareArgumentAgainstExpectedEscaped(@"abc*def", @"abc\\*def");
    CompareArgumentAgainstExpectedEscaped(@"~notpath", @"\\~notpath");
    CompareArgumentAgainstExpectedEscaped(@"what?", @"what\\?");
    CompareArgumentAgainstExpectedEscaped(@"test\"abc", @"test\\\"abc");
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
