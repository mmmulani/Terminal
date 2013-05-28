//
//  MMCommandGroup.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/27/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMCommandGroup.h"
#import "MMCommandLineArgumentsParser.h"

@implementation MMCommand

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

- (id)init;
{
    self = [super init];
    if (!self) {
        return nil;
    }

    self.arguments = [NSMutableArray array];

    return self;
}

- (void)insertArgumentAtFront:(NSString *)argument;
{
    [self.arguments insertObject:argument atIndex:0];
}

- (NSArray *)unescapedArguments;
{
    NSMutableArray *unescapedArguments = [NSMutableArray arrayWithCapacity:self.arguments.count];
    for (NSString *argument in self.arguments) {
        [unescapedArguments addObject:[MMCommand unescapeArgument:argument]];
    }

    return unescapedArguments;
}

- (void)treatFirstArgumentAsStandardOutput;
{
    NSAssert(self.arguments.count > 0, @"Standard output must be specified already");
    self.standardOutput = self.arguments[0];
    [self.arguments removeObjectAtIndex:0];
    self.standardOutputSourceType = MMSourceTypeFile;
}

- (void)treatFirstArgumentAsStandardInput;
{
    NSAssert(self.arguments.count > 0, @"Standard input must be specified already");
    self.standardInput = self.arguments[0];
    [self.arguments removeObjectAtIndex:0];
    self.standardInputSourceType = MMSourceTypeFile;
}

# pragma mark - NSCoding and NSPortCoder

- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder;
{
    if ([encoder isByref]) {
        return [super replacementObjectForPortCoder:encoder];
    } else {
        return self;
    }
}

- (id)initWithCoder:(NSCoder *)decoder;
{
    self = [super init];
    if (!self) {
        return nil;
    }

    self.arguments = [decoder decodeObjectForKey:@"arguments"];
    self.standardError = [decoder decodeObjectForKey:@"standardError"];
    self.standardErrorSourceType = [decoder decodeIntegerForKey:@"standardErrorSourceType"];
    self.standardInput = [decoder decodeObjectForKey:@"standardInput"];
    self.standardInputSourceType = [decoder decodeIntegerForKey:@"standardInputSourceType"];
    self.standardOutput = [decoder decodeObjectForKey:@"standardOutput"];
    self.standardOutputSourceType = [decoder decodeIntegerForKey:@"standardOutputSourceType"];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder;
{
    [coder encodeObject:self.arguments forKey:@"arguments"];
    [coder encodeObject:self.standardError forKey:@"standardError"];
    [coder encodeInteger:self.standardErrorSourceType forKey:@"standardErrorSourceType"];
    [coder encodeObject:self.standardInput forKey:@"standardInput"];
    [coder encodeInteger:self.standardInputSourceType forKey:@"standardInputSourceType"];
    [coder encodeObject:self.standardOutput forKey:@"standardOutput"];
    [coder encodeInteger:self.standardOutputSourceType forKey:@"standardOutputSourceType"];
}

@end

@implementation MMCommandGroup

+ (MMCommandGroup *)commandGroupWithSingleCommand:(MMCommand *)command;
{
    MMCommandGroup *group = [MMCommandGroup new];
    [group.commands addObject:command];
    return group;
}

- (id)init;
{
    self = [super init];
    if (!self) {
        return nil;
    }

    self.commands = [NSMutableArray array];

    return self;
}

- (void)insertCommand:(MMCommand *)command withBinaryOperator:(MMCommandOperator)operator;
{
    NSAssert(self.commands.count > 0, @"Must already have a command to use operator with");
    [self.commands insertObject:command atIndex:0];
    MMCommand *secondCommand = self.commands[1];

    if (operator == MMCommandOperatorPipe) {
        command.standardOutputSourceType = MMSourceTypePipe;
        command.standardErrorSourceType = MMSourceTypePipe;
        secondCommand.standardInputSourceType = MMSourceTypePipe;
    }
}

- (NSArray *)textOnlyForm;
{
    return [self.commands valueForKey:@"arguments"];
}

@end
