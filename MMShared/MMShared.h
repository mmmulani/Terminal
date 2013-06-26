//
//  MMShared.h
//  Terminal
//
//  Created by Mehdi Mulani on 2/20/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

FOUNDATION_EXPORT NSString *const ConnectionShellName;
FOUNDATION_EXPORT NSString *const ConnectionTerminalName;

FOUNDATION_EXPORT void MMLog(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);

#define MMSelfKey(key) ((NO && self.key) ? nil : @#key)

#define MMUserDefaultsKey(key) ([[[NSBundle mainBundle] bundleIdentifier] stringByAppendingString:@"."#key])

@interface MMShared : NSObject

@end
