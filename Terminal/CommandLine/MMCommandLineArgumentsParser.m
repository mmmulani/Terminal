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
    return [[MMParserContext new] parseString:commandLineText];
}

+ (NSArray *)parseCommandsFromCommandLineWithoutEscaping:(NSString *)commandLineText;
{
    // This method is only used by the completion engine, which doesn't care about the idea of command groups.
    // As such, we flatten command groups into one array.
    NSArray *commandGroups = [[[MMParserContext alloc] init] parseString:commandLineText];
    NSMutableArray *commandStrings = [NSMutableArray array];
    for (MMCommandGroup *commandGroup in commandGroups) {
        for (MMCommand *command in commandGroup.commands) {
            [commandStrings addObject:command.arguments];
        }
    }

    return commandStrings;
}

+ (NSArray *)tokenEndingsFromCommandLine:(NSString *)commandLineText;
{
    return [[[MMParserContext alloc] init] parseStringForTokenEndings:commandLineText];
}

@end
