//
//  MMCompletionEngine.h
//  Terminal
//
//  Created by Mehdi Mulani on 5/11/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MMCompletionEngine : NSObject

+ (MMCompletionEngine *)defaultCompletionEngine;

- (NSArray *)completionsForPartial:(NSString *)partial inDirectory:(NSString *)path;

@end
