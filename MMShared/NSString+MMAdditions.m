//
//  NSString+MMAdditions.m
//  Terminal
//
//  Created by Mehdi Mulani on 6/30/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "NSString+MMAdditions.h"

@implementation NSString (MMAdditions)

- (NSString *)repeatedTimes:(NSInteger)times;
{
  return [@"" stringByPaddingToLength:(self.length * times) withString:self startingAtIndex:0];
}

- (NSString *)repeatedToLength:(NSInteger)length;
{
  return [@"" stringByPaddingToLength:length withString:self startingAtIndex:0];
}

@end
