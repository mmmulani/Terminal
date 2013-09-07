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

@interface MMCommand : NSObject <NSCoding>

@property NSMutableArray *arguments;
@property MMSourceType standardInputSourceType;
@property id standardInput;
@property MMSourceType standardOutputSourceType;
@property id standardOutput;
@property MMSourceType standardErrorSourceType;
@property id standardError;

+ (NSString *)escapeArgument:(NSString *)argument;
+ (NSArray *)unescapeArgument:(NSString *)argument;
+ (NSArray *)unescapeArgument:(NSString *)argument inDirectory:(NSString *)directory;

- (NSArray *)unescapedArgumentsInDirectory:(NSString *)currentDirectory;

// These methods should only be called from the yacc-generated parser.
- (void)insertArgumentAtFront:(NSString *)argument;
- (void)treatFirstArgumentAsStandardOutput;
- (void)treatFirstArgumentAsStandardInput;

@end

@interface MMCommandGroup : NSObject <NSCoding>

@property NSMutableArray *commands;

+ (MMCommandGroup *)commandGroupWithSingleCommand:(MMCommand *)command;

- (NSArray *)textOnlyForm;

- (void)insertCommand:(MMCommand *)command withBinaryOperator:(MMCommandOperator)operator;

@end
