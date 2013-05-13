//
//  MMCommandsTextView.h
//  Terminal
//
//  Created by Mehdi Mulani on 5/11/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MMCompletionEngine;

@interface MMCommandsTextView : NSTextView

@property (strong) MMCompletionEngine *completionEngine;

@end
