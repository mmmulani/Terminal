//
//  MMTextView.h
//  Terminal
//
//  Created by Mehdi Mulani on 2/8/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol MMTextViewDelegate <NSTextViewDelegate>
@optional

- (void)handleKeyPress:(NSEvent *)keyEvent;

@end

@interface MMTextView : NSTextView

@property (assign) id<MMTextViewDelegate> delegate;

@end
