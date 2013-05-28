//
//  MMCommandLineArgumentsParser.h
//  Terminal
//
//  Created by Mehdi Mulani on 5/7/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MMCommandLineArgumentsParser : NSObject

+ (NSArray *)commandGroupsFromCommandLine:(NSString *)commandLineText;
+ (NSArray *)parseCommandsFromCommandLineWithoutEscaping:(NSString *)commandLineText;
+ (NSArray *)tokenEndingsFromCommandLine:(NSString *)commandLineText;

@end
