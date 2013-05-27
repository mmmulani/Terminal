//
//  MMCommandGroup.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/27/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMCommandGroup.h"
#import "MMCommandLineArgumentsParser.h"

@implementation MMCommand

- (id)init;
{
    self = [super init];
    if (!self) {
        return nil;
    }

    self.arguments = [NSMutableArray array];

    return self;
}

- (void)insertArgumentAtFront:(NSString *)argument;
{
    [self.arguments insertObject:argument atIndex:0];
}

- (NSArray *)unescapedArguments;
{
    NSMutableArray *unescapedArguments = [NSMutableArray arrayWithCapacity:self.arguments.count];
    for (NSString *argument in self.arguments) {
        [unescapedArguments addObject:[MMCommandLineArgumentsParser unescapeArgument:argument]];
    }

    return unescapedArguments;
}

@end

@implementation MMCommandGroup

+ (MMCommandGroup *)commandGroupWithSingleCommand:(MMCommand *)command;
{
    MMCommandGroup *group = [MMCommandGroup new];
    [group.commands addObject:command];
    return group;
}

- (id)init;
{
    self = [super init];
    if (!self) {
        return nil;
    }

    self.commands = [NSMutableArray array];

    return self;
}

- (void)insertCommand:(MMCommand *)command withBinaryOperator:(MMCommandOperator)operator;
{
    NSAssert(self.commands.count > 0, @"Must already have a command to use operator with");
    [self.commands insertObject:command atIndex:0];
    MMCommand *secondCommand = self.commands[1];

    if (operator == MMCommandOperatorPipe) {
        command.standardOutputSourceType = MMSourceTypePipe;
        command.standardErrorSourceType = MMSourceTypePipe;
        secondCommand.standardInputSourceType = MMSourceTypePipe;
    }
}

- (NSArray *)textOnlyForm;
{
    return [self.commands valueForKey:@"arguments"];
}

@end
