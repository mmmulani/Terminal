//
//  MMTaskInfo.h
//  Terminal
//
//  Created by Mehdi on 2013-06-15.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MMTerminalProxy.h"

@interface MMTaskInfo : NSObject <NSCoding>

@property (nonatomic, strong) NSString *command;
@property NSArray *commandGroups;
@property (getter=isShellCommand) BOOL shellCommand;
@property MMTaskIdentifier identifier;

@end
