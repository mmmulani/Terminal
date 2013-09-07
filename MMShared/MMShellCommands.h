//
//  MMShellCommands.h
//  Terminal
//
//  Created by Mehdi Mulani on 5/30/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
  MMShellCommandCd = 0,
} MMShellCommand;

@class MMCommand;

@interface MMShellCommands : NSObject

+ (BOOL)isShellCommand:(MMCommand *)command;

@end
