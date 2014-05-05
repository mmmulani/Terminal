//
//  MMTextView.h
//  Terminal
//
//  Created by Mehdi Mulani on 2/8/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol MMTextViewDelegate <NSTextViewDelegate>

- (void)handleKeyPress:(NSEvent *)keyEvent;
- (void)handleInput:(NSString *)input;

@end

@interface MMTextView : NSView

@property (assign) id<MMTextViewDelegate> delegate;
@property NSLayoutManager *layoutManager;

- (NSTextStorage *)textStorage;
- (void)setSelectedRange:(NSRange)charRange;

@end
