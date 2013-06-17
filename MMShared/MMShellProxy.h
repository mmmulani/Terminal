//
//  MMShellProxy.h
//  Terminal
//
//  Created by Mehdi on 2013-06-15.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MMTaskInfo;

@protocol MMShellProxy <NSObject>

- (void)setPathVariable:(NSString *)pathVariable;
- (void)executeTask:(MMTaskInfo *)taskInfo;
- (void)endShell;

@end
