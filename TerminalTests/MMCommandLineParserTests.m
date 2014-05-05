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
  XCTAssertEqualObjects([result valueForKey:@"textOnlyForm"], a2, @"Compared parser output to provided output."); \
} while (0)

#define CompareInputAgainstEscapedArgument(input, output) \
do {\
  NSArray *arguments = [MMCommand unescapeArgument:input]; \
  XCTAssertEqual(arguments.count, (NSUInteger)1, @"Should only find one argument."); \
  NSString *result = arguments[0];\
  XCTAssertEqualObjects(result, output, @"Compared parser output to provided output."); \
} while (0)

#define CompareArgumentAgainstExpectedEscaped(argument, expected) \
do {\
  NSArray *arguments = [MMCommand unescapeArgument:[MMCommand escapeArgument:argument]]; \
  XCTAssertEqual(arguments.count, (NSUInteger)1, @"Should only expand to one argument."); \
  XCTAssertEqualObjects(arguments[0], argument, @"Unescaping and escaping should be idempotent"); \
  XCTAssertEqualObjects([MMCommand escapeArgument:argument], expected, @"Compared escaped argument to expected."); \
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
  XCTAssertEqualObjects(commands, (@[@"test", @"123", @"echo", @"456"]), @"");

  MMCommand *command = [MMCommand new];
  command.arguments = [@[@"ls", @"~/Documents"] mutableCopy];
  id commandMock = [OCMockObject partialMockForObject:command];
  [[[commandMock stub] andReturn:@"/Users/test"] homeDirectoryForCurrentUser];
  XCTAssertEqualObjects([commandMock unescapedArgumentsInDirectory:nil], (@[@"ls", @"/Users/test/Documents"]), @"");
  [commandMock stopMocking];

  command = [MMCommand new];
  command.arguments = [@[@"echo", @"~test", @"~root/lol"] mutableCopy];
  commandMock = [OCMockObject partialMockForObject:command];
  [[[commandMock stub] andReturn:@"/Users/test"] homeDirectoryForUser:@"test"];
  [[[commandMock stub] andReturn:@"/Users/root"] homeDirectoryForUser:@"root"];
  XCTAssertEqualObjects([commandMock unescapedArgumentsInDirectory:nil], (@[@"echo", @"/Users/test", @"/Users/root/lol"]), @"");
  [commandMock stopMocking];

  // Test various globbing patterns.

  command = [MMCommand new];
  command.arguments = [@[@"echo", @"*"] mutableCopy];
  commandMock = [OCMockObject partialMockForObject:command];
  [[[commandMock stub] andReturn:@[@"a", @"bc"]] filesAndFoldersInDirectory:@"/Users/test/"];
  XCTAssertEqualObjects([commandMock unescapedArgumentsInDirectory:@"/Users/test"], (@[@"echo", @"a", @"bc"]), @"");
  [commandMock stopMocking];

  command = [MMCommand new];
  command.arguments = [@[@"echo", @"**"] mutableCopy];
  commandMock = [OCMockObject partialMockForObject:command];
  [[[commandMock stub] andReturn:@[@"a", @"bc"]] filesAndFoldersInDirectory:@"/Users/test/"];
  XCTAssertEqualObjects([commandMock unescapedArgumentsInDirectory:@"/Users/test"], (@[@"echo", @"a", @"bc"]), @"");
  [commandMock stopMocking];

  command = [MMCommand new];
  command.arguments = [@[@"echo", @"?"] mutableCopy];
  commandMock = [OCMockObject partialMockForObject:command];
  [[[commandMock stub] andReturn:@[@"a", @"bc"]] filesAndFoldersInDirectory:@"/Users/test/"];
  XCTAssertEqualObjects([commandMock unescapedArgumentsInDirectory:@"/Users/test"], (@[@"echo", @"a"]), @"");
  [commandMock stopMocking];

  command = [MMCommand new];
  command.arguments = [@[@"echo", @"??"] mutableCopy];
  commandMock = [OCMockObject partialMockForObject:command];
  [[[commandMock stub] andReturn:@[@"123", @"456", @"789"]] filesAndFoldersInDirectory:@"/Users/test/"];
  XCTAssertEqualObjects([commandMock unescapedArgumentsInDirectory:@"/Users/test"], (@[@"echo"]), @"");
  [commandMock stopMocking];

  command = [MMCommand new];
  command.arguments = [@[@"echo", @"???"] mutableCopy];
  commandMock = [OCMockObject partialMockForObject:command];
  [[[commandMock stub] andReturn:@[@"123", @"456", @"789"]] filesAndFoldersInDirectory:@"/Users/test/"];
  XCTAssertEqualObjects([commandMock unescapedArgumentsInDirectory:@"/Users/test"], (@[@"echo", @"123", @"456", @"789"]), @"");
  [commandMock stopMocking];

  command = [MMCommand new];
  command.arguments = [@[@"echo", @"?5?"] mutableCopy];
  commandMock = [OCMockObject partialMockForObject:command];
  [[[commandMock stub] andReturn:@[@"123", @"456", @"789"]] filesAndFoldersInDirectory:@"/Users/test/"];
  XCTAssertEqualObjects([commandMock unescapedArgumentsInDirectory:@"/Users/test"], (@[@"echo", @"456"]), @"");
  [commandMock stopMocking];

  command = [MMCommand new];
  command.arguments = [@[@"echo", @"4??"] mutableCopy];
  commandMock = [OCMockObject partialMockForObject:command];
  [[[commandMock stub] andReturn:@[@"123", @"456", @"789"]] filesAndFoldersInDirectory:@"/Users/test/"];
  XCTAssertEqualObjects([commandMock unescapedArgumentsInDirectory:@"/Users/test"], (@[@"echo", @"456"]), @"");
  [commandMock stopMocking];

  command = [MMCommand new];
  command.arguments = [@[@"cat", @"*.png"] mutableCopy];
  commandMock = [OCMockObject partialMockForObject:command];
  [[[commandMock stub] andReturn:@[@"abc.png", @"abc.txt", @"abcdpng", @"mmm.png", @"z.png"]] filesAndFoldersInDirectory:@"/Users/test/"];
  XCTAssertEqualObjects([commandMock unescapedArgumentsInDirectory:@"/Users/test"], (@[@"cat", @"abc.png", @"mmm.png", @"z.png"]), @"");
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
  XCTAssertEqualObjects(tokenEndings, (@[@3, @7, @12]), @"");

  NSArray *tokenEndingsWithAccent = [MMCommandLineArgumentsParser tokenEndingsFromCommandLine:@"cd Améli"];
  XCTAssertEqualObjects(tokenEndingsWithAccent, (@[@2, @8]), @"");

  NSArray *tokenEndingsWithRedirection = [MMCommandLineArgumentsParser tokenEndingsFromCommandLine:@"echo test < /dev/null > /dev/test"];
  XCTAssertEqualObjects(tokenEndingsWithRedirection, (@[@4, @9, @21, @33]), @"");
}

- (void)testInputOutputRedirection;
{
  MMCommandGroup *commandGroup = [MMCommandLineArgumentsParser commandGroupsFromCommandLine:@"echo test > /dev/null < /input/file"][0];
  MMCommand *command = commandGroup.commands[0];
  XCTAssertEqual(command.standardInputSourceType, MMSourceTypeFile, @"");
  XCTAssertEqualObjects(command.standardInput, @"/input/file", @"");
  XCTAssertEqual(command.standardOutputSourceType, MMSourceTypeFile, @"");
  XCTAssertEqualObjects(command.standardOutput, @"/dev/null", @"");
  XCTAssertEqualObjects(command.arguments, (@[@"echo", @"test"]), @"");

  MMCommandGroup *unescapedCommandGroup = [MMCommandLineArgumentsParser commandGroupsFromCommandLine:@"echo test > /dev/\"\\u00e9\"test"][0];
  MMCommand *unescapedCommandTest = unescapedCommandGroup.commands[0];
  XCTAssertEqualObjects(unescapedCommandTest.standardOutput, @"/dev/étest", @"Testing whether standard output is unescaped");

  MMCommandGroup *pipedCommandGroup = [MMCommandLineArgumentsParser commandGroupsFromCommandLine:@"echo test | cat -"][0];
  XCTAssertEqual(pipedCommandGroup.commands.count, (NSUInteger)2, @"");
  MMCommand *echoCommand = pipedCommandGroup.commands[0];
  XCTAssertEqualObjects(echoCommand.arguments, (@[@"echo", @"test"]), @"");
  XCTAssertEqual(echoCommand.standardInputSourceType, MMSourceTypeDefault, @"");
  XCTAssertEqual(echoCommand.standardOutputSourceType, MMSourceTypePipe, @"");
  MMCommand *catCommand = pipedCommandGroup.commands[1];
  XCTAssertEqualObjects(catCommand.arguments, (@[@"cat", @"-"]), @"");
  XCTAssertEqual(catCommand.standardInputSourceType, MMSourceTypePipe, @"");
  XCTAssertEqual(echoCommand.standardInputSourceType, MMSourceTypeDefault, @"");
}

@end
