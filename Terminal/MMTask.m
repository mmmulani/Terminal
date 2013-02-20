//
//  MMTask.m
//  Terminal
//
//  Created by Mehdi Mulani on 2/19/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMTask.h"

@implementation MMTask

- (id)init;
{
    self = [super init];
    if (!self) {
        return nil;
    }

    self.output = [[NSTextStorage alloc] init];

    return self;
}

@end
