//
//  MMParserContext.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/7/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMParserContext.h"
#import "MMCommandGroup.h"

@implementation MMParserContext

NSMutableDictionary *_parsers = nil;
NSMutableArray *_storedObjects = nil;
NSMutableDictionary *_tokenEnds = nil;
NSInteger _currentPosition = 0;

+ (void)initialize;
{
    _parsers = [NSMutableDictionary dictionary];
    _storedObjects = [NSMutableArray array];
    _tokenEnds = [NSMutableDictionary dictionary];
}

+ (MMParserContext *)parserForContext:(MMParserCtx *)context;
{
    return [_parsers objectForKey:[NSValue valueWithPointer:context]];
}

+ (void)storeObject:(id)object;
{
    [_storedObjects addObject:object];
}

+ (NSInteger)currentPosition;
{
    return _currentPosition;
}

+ (void)incrementCurrentPosition:(NSInteger)amount;
{
    _currentPosition += amount;
}

+ (void)setEnd:(NSInteger)end forToken:(NSString *)token;
{
    _tokenEnds[[NSValue valueWithPointer:(__bridge const void *)token]] = [NSNumber numberWithInteger:end];
}

- (id)init;
{
    self = [super init];
    if (!self) {
        return nil;
    }

    self.scanner = (MMParserCtx *)malloc(sizeof(MMParserCtx));
    [_parsers setObject:self forKey:[NSValue valueWithPointer:self.scanner]];
    [self initScanner];

    return self;
}

- (void)dealloc;
{
    [_parsers removeObjectForKey:[NSValue valueWithPointer:self.scanner]];
    [self deallocScanner];
    free(self.scanner);
    self.scanner = nil;
}

- (void)initScanner;
{
    _currentPosition = 0;
    yylex_init(&(self.scanner->scanner));
	yyset_extra(self.scanner,self.scanner->scanner);
	self.scanner->error_text = nil;
	self.scanner->error_line = -1;
}

- (void)deallocScanner;
{
    yylex_destroy(self.scanner->scanner);
}

- (int)inputToBuffer:(char *)buffer maxBytesToRead:(size_t)maxBytesToRead;
{
    if (self.stream.streamStatus == NSStreamStatusAtEnd ||
        self.stream.streamStatus == NSStreamStatusClosed ||
        self.stream.streamStatus == NSStreamStatusError ||
        self.stream.streamStatus == NSStreamStatusNotOpen) {
        return 0;
    }

    NSInteger bytesRead = [self.stream read:(uint8_t *)buffer maxLength:maxBytesToRead];
    if (bytesRead < 0) {
        return 0;
    }

    return (int)bytesRead;
}

- (id)parseString:(NSString *)commandLineInput;
{
    id result;
    NSData *data = [commandLineInput dataUsingEncoding:NSUTF8StringEncoding];
    self.stream = [NSInputStream inputStreamWithData:data];
    [self.stream open];
    self.scanner->result = nil;
    if (yyparse(self.scanner)) {
        // TODO: Error handling.
        return nil;
    }
    result = self.scanner->result;
    _storedObjects = [NSMutableArray array];
    _tokenEnds = [NSMutableDictionary dictionary];
    self.scanner->result = nil;
    [self.stream close];
    self.stream = nil;

    return result;
}

- (id)parseStringForTokenEndings:(NSString *)commandLineInput;
{
    NSMutableArray *result;
    NSData *data = [commandLineInput dataUsingEncoding:NSUTF8StringEncoding];
    self.stream = [NSInputStream inputStreamWithData:data];
    [self.stream open];
    self.scanner->result = nil;
    if (yyparse(self.scanner)) {
        // TODO: Error handling.
        return nil;
    }
    NSMutableArray *tokenEndings = [NSMutableArray array];
    result = self.scanner->result;
    for (NSInteger i = 0; i < result.count; i++) {
        MMCommandGroup *commandGroup = result[i];
        for (NSInteger j = 0; j < commandGroup.commands.count; j++) {
            NSMutableArray *commandEndings = [NSMutableArray array];
            for (NSInteger k = 0; k < [[commandGroup.commands[j] arguments] count]; k++) {
                NSString *token = [commandGroup.commands[j] arguments][k];
                [commandEndings addObject:_tokenEnds[[NSValue valueWithPointer:(__bridge const void *)token]]];
            }

            [tokenEndings addObject:commandEndings];
        }
    }
    _storedObjects = [NSMutableArray array];
    _tokenEnds = [NSMutableDictionary dictionary];
    self.scanner->result = nil;
    [self.stream close];
    self.stream = nil;

    return tokenEndings;
}

@end
