//
//  MMANSIAction.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/21/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMANSIAction.h"

@implementation MMANSIAction

+ (NSArray *)_defaultArguments;
{
    return @[];
}

+ (NSArray *)defaultArguments;
{
    static NSArray *defaultArguments;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultArguments = [self _defaultArguments];
    });

    return defaultArguments;
}

- (id)init;
{
    self = [super init];
    if (!self) {
        return nil;
    }

    self.data = [NSMutableDictionary dictionary];

    return self;
}

- (id)initWithArguments:(NSArray *)arguments;
{
    self = [self init];
    if (!self) {
        return nil;
    }

    self.arguments = arguments;

    return self;
}

- (id)defaultedArgumentAtIndex:(NSInteger)index;
{
    if (index > self.arguments.count - 1) {
        return self.class.defaultArguments[index];
    }

    return self.arguments[index];
}

- (void)do;
{
    NSAssert(NO, @"Subclass must implement do method");
}

@end
