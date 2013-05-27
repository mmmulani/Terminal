//
//  MMCommandLineArgumentsParser.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/7/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMCommandLineArgumentsParser.h"
#import "MMParserContext.h"
#import "MMCommandGroup.h"

@implementation MMCommandLineArgumentsParser

+ (NSArray *)commandGroupsFromCommandLine:(NSString *)commandLineText;
{
    return [[MMParserContext new] parseString:commandLineText];
}

+ (NSArray *)parseCommandsFromCommandLineWithoutEscaping:(NSString *)commandLineText;
{
    // This method is only used by the completion engine, which doesn't care about the idea of command groups.
    // As such, we flatten command groups into one array.
    NSArray *commandGroups = [[[MMParserContext alloc] init] parseString:commandLineText];
    NSMutableArray *commandStrings = [NSMutableArray array];
    for (MMCommandGroup *commandGroup in commandGroups) {
        for (MMCommand *command in commandGroup.commands) {
            [commandStrings addObject:command.arguments];
        }
    }

    return commandStrings;
}

+ (NSArray *)tokenEndingsFromCommandLine:(NSString *)commandLineText;
{
    return [[[MMParserContext alloc] init] parseStringForTokenEndings:commandLineText];
}

+ (NSString *)unescapeArgument:(NSString *)argument;
{
    NSMutableString *newArgument = [NSMutableString stringWithCapacity:argument.length];
    NSCharacterSet *charSet = [NSCharacterSet characterSetWithCharactersInString:@"\"\\"];
    NSInteger i = 0;
    BOOL insideQuoted = NO;
    while (i < argument.length) {
        NSRange range = [argument rangeOfCharacterFromSet:charSet options:0 range:NSMakeRange(i, argument.length - i)];
        if (range.location == NSNotFound) {
            [newArgument appendString:[argument substringFromIndex:i]];
            i = argument.length;
            break;
        }

        [newArgument appendString:[argument substringWithRange:NSMakeRange(i, range.location - i)]];
        i = range.location;

        if ([argument characterAtIndex:range.location] == '"') {
            insideQuoted = !insideQuoted;
            i++;
        } else {
            if (insideQuoted) {
                i++;
                if (i >= argument.length) {
                    break;
                }

                NSCharacterSet *digitCharacterSet = [NSCharacterSet decimalDigitCharacterSet];
                NSCharacterSet *hexCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"01234567890abcdefABCDEF"];
                NSDictionary *regularEscapes =
                @{
                  @"a": @"\a",
                  @"b": @"\b",
                  @"f": @"\f",
                  @"n": @"\n",
                  @"r": @"\r",
                  @"t": @"\t",
                  @"\\": @"\\",
                  @"'": @"'",
                  @"\"": @"\"",
                  };
                unichar escapedCharacter = [argument characterAtIndex:i];
                if (regularEscapes[[NSString stringWithCharacters:&escapedCharacter length:1]]) {
                    [newArgument appendString:regularEscapes[[NSString stringWithCharacters:&escapedCharacter length:1]]];
                    i++;
                } else if (escapedCharacter == 'u' || escapedCharacter == 'U') {
                    unichar hexValue = 0;
                    NSInteger limit = escapedCharacter == 'u' ? 4 : 8;
                    NSInteger j;
                    for (j = i + 1; j < argument.length && [hexCharacterSet characterIsMember:[argument characterAtIndex:j]] && j < i + 1 + limit; j++) {
                        unichar currentChar = [argument characterAtIndex:j];
                        int currentValue = currentChar >= 'a' ? currentChar - 'W' : currentChar >= 'A' ? currentChar - '7' : currentChar - '0';
                        hexValue = hexValue * 16 + currentValue;
                    }
                    [newArgument appendString:[NSString stringWithCharacters:&hexValue length:1]];
                    i = j;
                } else if ([digitCharacterSet characterIsMember:escapedCharacter]) {
                    unichar octalValue = 0;
                    NSInteger j;
                    for (j = i; j < argument.length && [digitCharacterSet characterIsMember:[argument characterAtIndex:j]] && j < i + 3; j++) {
                        octalValue = octalValue * 8 + ([argument characterAtIndex:j] - '0');
                    }
                    [newArgument appendString:[NSString stringWithCharacters:&octalValue length:1]];
                    i = j;
                } else if (escapedCharacter == 'x') {
                    unichar hexValue = 0;
                    NSInteger j;
                    for (j = i + 1; j < argument.length && [hexCharacterSet characterIsMember:[argument characterAtIndex:j]] && j < i + 1 + 4; j++) {
                        unichar currentChar = [argument characterAtIndex:j];
                        int currentValue = currentChar >= 'a' ? currentChar - 'W' : currentChar >= 'A' ? currentChar - '7' : currentChar - '0';
                        hexValue = hexValue * 16 + currentValue;
                    }
                    [newArgument appendString:[NSString stringWithCharacters:&hexValue length:1]];
                    i = j;
                }
            } else {
                if (i + 1 < argument.length) {
                    [newArgument appendString:[argument substringWithRange:NSMakeRange(i + 1, 1)]];
                }
                i += 2;
            }
        }
    }

    return newArgument;
}

+ (NSString *)escapeArgument:(NSString *)argument;
{
    return [[argument stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"] stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
}

@end
