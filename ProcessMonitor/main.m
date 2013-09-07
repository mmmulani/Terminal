//
//  main.m
//  ProcessMonitor
//
//  Created by Mehdi Mulani on 5/16/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MMProcessMonitorMain.h"

int main(int argc, const char * argv[])
{
  @autoreleasepool {

    [[MMProcessMonitorMain sharedApplication] start];

  }
  return 0;
}

