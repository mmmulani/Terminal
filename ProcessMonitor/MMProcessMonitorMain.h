//
//  MMProcessMonitorMain.h
//  Terminal
//
//  Created by Mehdi Mulani on 5/16/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MMProcessMonitorMain : NSObject

+ (MMProcessMonitorMain *)sharedApplication;

- (void)start;

@end
