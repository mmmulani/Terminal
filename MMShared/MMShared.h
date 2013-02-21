//
//  MMShared.h
//  Terminal
//
//  Created by Mehdi Mulani on 2/20/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

FOUNDATION_EXPORT NSString *const ConnectionShellName;
FOUNDATION_EXPORT NSString *const ConnectionTerminalName;

@interface MMShared : NSObject

+ (void)logMessage:(NSString *)format, ...;

@end
