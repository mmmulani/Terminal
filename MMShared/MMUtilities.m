//
//  MMUtilities.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/31/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMUtilities.h"

@implementation MMUtilities

+ (void)postData:(NSData *)data toURL:(NSURL *)url description:(NSString *)description;
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"content-type"];
    [request setValue:description forHTTPHeaderField:@"MMFilename"];
    [request setHTTPBody:data];

    NSURLResponse *response;
    NSError *error;
    NSData *returnData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (error) {
        NSLog(@"Error in sending request: %@", error);
    }
}

@end
