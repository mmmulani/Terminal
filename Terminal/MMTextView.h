//
//  MMTextView.h
//  Terminal
//
//  Created by Mehdi Mulani on 2/8/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MMTask;

@protocol MMTextViewDelegate <NSTextViewDelegate>

- (void)handleKeyPress:(NSEvent *)keyEvent;
- (void)handleInput:(NSString *)input;

@end

@interface MMTextView : NSView <NSTextStorageDelegate>

+ (CGFloat)widthForColumnsOfText:(NSUInteger)columns;
+ (NSUInteger)columnsForWidthOfText:(CGFloat)width;

@property (assign) id<MMTextViewDelegate> delegate;
@property NSLayoutManager *layoutManager;
@property NSTextStorage *textStorage;
@property (weak) MMTask *task;

- (void)setSelectedRange:(NSRange)charRange;
- (CGFloat)desiredScrollHeight;

@end
