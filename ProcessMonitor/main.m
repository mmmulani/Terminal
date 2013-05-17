//
//  main.m
//  ProcessMonitor
//
//  Created by Mehdi Mulani on 5/16/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MMProcessMonitorMain.h"
#include <syslog.h>

int main(int argc, const char * argv[])
{
    syslog(LOG_NOTICE, "Hello world! uid = %d, euid = %d, pid = %d\n", (int) getuid(), (int) geteuid(), (int) getpid());
    
    @autoreleasepool {

        sleep(100);
        [[MMProcessMonitorMain sharedApplication] start];

    }
    return 0;
}

