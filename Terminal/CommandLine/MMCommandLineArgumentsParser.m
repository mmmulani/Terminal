//
//  MMCommandLineArgumentsParser.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/7/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMCommandLineArgumentsParser.h"
#import "MMParserContext.h"
#import "MMCommandGroup.h"

@implementation MMCommandLineArgumentsParser

+ (NSArray *)commandGroupsFromCommandLine:(NSString *)commandLineText;
{
  return [[MMParserContext new] parseString:commandLineText forTokens:NO];
}

+ (NSArray *)tokensFromCommandLineWithoutEscaping:(NSString *)commandLineText;
{
  return [[MMParserContext new] parseString:commandLineText forTokens:YES];
}

+ (NSArray *)tokenEndingsFromCommandLine:(NSString *)commandLineText;
{
  return [[[MMParserContext alloc] init] parseStringForTokenEndings:commandLineText];
}

@end
