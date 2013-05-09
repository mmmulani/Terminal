//
//  MMCommandLineArgumentsParser.h
//  Terminal
//
//  Created by Mehdi Mulani on 5/7/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MMCommandLineArgumentsParser : NSObject

+ (NSArray *)parseCommandsFromCommandLine:(NSString *)commandLineText;
+ (NSString *)escapeArgument:(NSString *)argument;

@end
