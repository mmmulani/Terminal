//
//  NSString+MMAdditions.h
//  Terminal
//
//  Created by Mehdi Mulani on 6/30/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (MMAdditions)

- (NSString *)repeatedTimes:(NSInteger)times;
- (NSString *)repeatedToLength:(NSInteger)length;

@end
