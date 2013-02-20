//
//  MMTask.h
//  Terminal
//
//  Created by Mehdi Mulani on 2/19/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MMTask : NSObject

@property (strong) NSTextStorage *output;
@property pid_t processId;
@property (strong) NSDate *startedAt;
@property (strong) NSDate *finishedAt;
@property (strong) NSString *command;

@end
