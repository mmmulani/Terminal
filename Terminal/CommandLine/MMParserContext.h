//
//  MMParserContext.h
//  Terminal
//
//  Created by Mehdi Mulani on 5/7/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct {
    void *scanner;
    __unsafe_unretained id result;
    const char *error_text;
    int error_line;
} MMParserCtx;

extern int yydebug;
int yyparse(MMParserCtx *context);
int yylex_init(void **scanner);
void yyset_extra(MMParserCtx *context, void *scanner);
int yylex_destroy(void *scanner);


@interface MMParserContext : NSObject

@property MMParserCtx *scanner;
@property NSInputStream *stream;

+ (MMParserContext *)parserForContext:(MMParserCtx *)context;

+ (void)storeObject:(id)object;

+ (NSInteger)currentPosition;
+ (void)incrementCurrentPosition:(NSInteger)amount;
+ (void)setEnd:(NSInteger)end forToken:(NSString *)token;

- (int)inputToBuffer:(char *)buffer maxBytesToRead:(size_t)maxBytesToRead;

- (id)parseString:(NSString *)commandLineInput;
- (id)parseStringForTokenEndings:(NSString *)commandLineInput;

@end
