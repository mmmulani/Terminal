//
//  MMShellCommands.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/30/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMShellCommands.h"
#import "MMCommandGroup.h"

@implementation MMShellCommands

+ (BOOL)isShellCommand:(MMCommand *)command;
{
    return command.arguments.count > 0 && [command.arguments[0] isEqualToString:@"cd"];
}


@end
