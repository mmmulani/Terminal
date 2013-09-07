//
//  MMProcessMonitorMain.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/16/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#include <sys/sysctl.h>
#include <syslog.h>

#import "MMProcessMonitorMain.h"
#import "MMShared.h"

@interface MMProcessMonitorMain ()

@property NSMutableArray *watchedPids;

@end

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

- (id)init;
{
  self = [super init];
  if (!self) {
    return nil;
  }

  self.watchedPids = [NSMutableArray array];
  return self;
}

- (void)watchPid:(NSNumber *)pid;
{
  if ([self.watchedPids indexOfObject:pid] == NSNotFound) {
    [self.watchedPids addObject:pid];
  }
}

- (void)sample;
{
  int miblen = 3;
  size_t len;
	int mib[miblen];
	int res;
  struct kinfo_proc *kinfos;

	mib[0] = CTL_KERN;
	mib[1] = KERN_PROC;
	mib[2] = KERN_PROC_ALL;
	res = sysctl(mib, miblen, NULL, &len, NULL, 0);

  kinfos = malloc(len);

  res = sysctl(mib, miblen, kinfos, &len, NULL, 0);
  syslog(LOG_NOTICE, "sysctl result: %d and len: %ld", res, len / sizeof(struct kinfo_proc));

  for (NSInteger i = 0; i < 3; i++) {
    struct kinfo_proc kinfo = kinfos[i];
    syslog(LOG_NOTICE, "pid: %d parent pid: %d", kinfo.kp_proc.p_pid, kinfo.kp_eproc.e_ppid);
  }
}

- (void)start;
{
  [self sample];
  //    [[NSRunLoop mainRunLoop] run];
}

@end
