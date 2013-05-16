//
//  MMProcessMonitorMain.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/16/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMProcessMonitorMain.h"

@implementation MMProcessMonitorMain

+ (MMProcessMonitorMain *)sharedApplication;
{
    static MMProcessMonitorMain *processMonitorMain = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        processMonitorMain = [[MMProcessMonitorMain alloc] init];
    });

    return processMonitorMain;
}

- (void)start;
{
    [[NSRunLoop mainRunLoop] run];
}

@end
