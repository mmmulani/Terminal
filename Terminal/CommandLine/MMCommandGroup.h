//
//  MMCommandGroup.h
//  Terminal
//
//  Created by Mehdi Mulani on 5/27/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    MMSourceTypeDefault = 0,
    MMSourceTypePipe,
    MMSourceTypeFile,
} MMSourceType;

typedef enum {
    MMCommandOperatorPipe = 0,
    MMCommandOperatorAnd,
    MMCommandOperatorOr,
} MMCommandOperator;

@interface MMCommand : NSObject

@property NSMutableArray *arguments;
@property MMSourceType standardInputSourceType;
@property id standardInput;
@property MMSourceType standardOutputSourceType;
@property id standardOutput;
@property MMSourceType standardErrorSourceType;
@property id standardError;

- (void)insertArgumentAtFront:(NSString *)argument;
- (NSArray *)unescapedArguments;

@end

@interface MMCommandGroup : NSObject

@property NSMutableArray *commands;

+ (MMCommandGroup *)commandGroupWithSingleCommand:(MMCommand *)command;

- (void)insertCommand:(MMCommand *)command withBinaryOperator:(MMCommandOperator)operator;
- (NSArray *)textOnlyForm;

@end
