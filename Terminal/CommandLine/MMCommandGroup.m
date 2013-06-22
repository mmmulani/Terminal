//
//  MMCommandGroup.m
//  Terminal
//
//  Created by Mehdi Mulani on 5/27/13.
//  Copyright (c) 2013 Mehdi Mulani. All rights reserved.
//

#import "MMCommandGroup.h"
#import "MMCommandLineArgumentsParser.h"
#import "MMShared.h"
#import "MMUtilities.h"

@implementation MMCommand

+ (NSArray *)unescapeArgument:(NSString *)argument;
{
    return [self unescapeArgument:argument inDirectory:nil];
}

+ (NSArray *)unescapeArgument:(NSString *)argument inDirectory:(NSString *)directory;
{
    NSMutableString *newArgument = [NSMutableString stringWithCapacity:argument.length];
    NSCharacterSet *charSet = [NSCharacterSet characterSetWithCharactersInString:@"\"\\"];
    NSInteger i = 0;
    // |starGlobLocations| and |questionGlobLocations| are indices into |newArgument| where *s and ?s can be found.
    // The locations are adjusted for escaped characters being simplified but not for tilde expansion.
    NSMutableArray *starGlobLocations = [NSMutableArray array];
    NSMutableArray *questionGlobLocations = [NSMutableArray array];
    BOOL insideQuoted = NO;
    while (i < argument.length) {
        NSRange searchRange = NSMakeRange(i, argument.length - i);
        NSRange range = [argument rangeOfCharacterFromSet:charSet options:0 range:searchRange];
        NSRange questionRange = [argument rangeOfString:@"?" options:0 range:searchRange];
        NSRange starRange = [argument rangeOfString:@"*" options:0 range:searchRange];

        while (!insideQuoted && questionRange.location < range.location) {
            [questionGlobLocations addObject:@(newArgument.length + questionRange.location - i)];
            questionRange = [argument rangeOfString:@"?" options:0 range:NSMakeRange(questionRange.location + 1, argument.length - questionRange.location - 1)];
        }
        while (!insideQuoted && starRange.location < range.location) {
            [starGlobLocations addObject:@(newArgument.length + starRange.location - i)];
            starRange = [argument rangeOfString:@"*" options:0 range:NSMakeRange(starRange.location + 1, argument.length - starRange.location - 1)];
        }

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

    // Apply tilde expansion.
    NSInteger tildeExpandingAmount = 0;
    if (argument.length > 0 && [argument characterAtIndex:0] == '~') {
        NSRange slashRange = [newArgument rangeOfString:@"/"];
        NSString *user = @"";
        if (slashRange.location != NSNotFound) {
            user = [newArgument substringWithRange:NSMakeRange(1, slashRange.location - 1)];
        } else {
            user = [newArgument substringFromIndex:1];
        }

        NSString *homeDirectory = user.length == 0 ? [self homeDirectoryForCurrentUser] : [self homeDirectoryForUser:user];
        if (homeDirectory) {
            [newArgument replaceCharactersInRange:NSMakeRange(0, 1 + user.length) withString:homeDirectory];
        }

        tildeExpandingAmount = homeDirectory.length - (1 + user.length);
    }

    // Apply globbing patterns. (Only ? and * so far.)
    // We accomplish this by converting the argument to a regex, and matching it against the appropriate files.
    if (starGlobLocations.count + questionGlobLocations.count > 0) {
        // TODO: Support globbing patterns into multiple directories. (e.g. "a*/b*")
        // TODO: Support globbing hidden files. (e.g. ".*")

        // First, we have to find out which directory to search for matches in.
        NSString *directoryForGlobbing = [directory characterAtIndex:(directory.length - 1)] == '/' ? directory : [directory stringByAppendingString:@"/"];
        NSInteger directoryOffset = 0;
        NSRange directoryRange = [newArgument rangeOfString:@"/" options:NSBackwardsSearch range:NSMakeRange(0, newArgument.length - 1)];
        if (directoryRange.location != NSNotFound) {
            directoryForGlobbing = [newArgument substringToIndex:(directoryRange.location + 1)];
            directoryOffset = directoryForGlobbing.length;
            newArgument = [[newArgument substringFromIndex:directoryOffset] mutableCopy];
        }

        // Construct the regular expression pattern.
        NSMutableString *regexPattern = [NSMutableString stringWithString:@"^"];
        NSInteger i = 0;
        NSInteger j = 0;
        NSInteger previousIndex = -1;
        while (i < starGlobLocations.count || j < questionGlobLocations.count) {
            BOOL starGlob = NO;
            if (j >= questionGlobLocations.count ||
                (i < starGlobLocations.count && [starGlobLocations[i] integerValue] < [questionGlobLocations[j] integerValue])) {
                starGlob = YES;
            }

            NSInteger currentIndex = starGlob ? [starGlobLocations[i] integerValue] : [questionGlobLocations[j] integerValue];
            [regexPattern appendString:[NSRegularExpression escapedPatternForString:[newArgument substringWithRange:NSMakeRange(previousIndex + 1, currentIndex - (previousIndex + 1))]]];
            previousIndex = currentIndex;

            if (starGlob) {
                [regexPattern appendString:@"(.*)"];
                i++;
            } else {
                [regexPattern appendString:@"(.)"];
                j++;
            }
        }

        // Add the part of the argument following the last pattern.
        [regexPattern appendString:[NSRegularExpression escapedPatternForString:[newArgument substringWithRange:NSMakeRange(previousIndex + 1, newArgument.length - (previousIndex + 1))]]];

        // Allow a trailing slash, to account for directories where we add a slash.
        [regexPattern appendString:@"\\/?$"];

        NSRegularExpression *regularExpression = [NSRegularExpression regularExpressionWithPattern:regexPattern options:NSRegularExpressionAnchorsMatchLines error:NULL];
        NSArray *files = [self filesAndFoldersInDirectory:directoryForGlobbing];
        NSMutableArray *matches = [NSMutableArray array];
        for (NSString *file in files) {
            if ([regularExpression numberOfMatchesInString:file options:NSMatchingAnchored range:NSMakeRange(0, file.length)]) {
                NSString *expandedResult;
                if (directoryRange.location != NSNotFound) {
                    expandedResult = [directoryForGlobbing stringByAppendingString:file];
                } else {
                    expandedResult = file;
                }
                [matches addObject:expandedResult];
            }
        }

        return matches;
    }

    return @[newArgument];
}

+ (NSArray *)filesAndFoldersInDirectory:(NSString *)directory;
{
    return [MMUtilities filesAndFoldersInDirectory:directory includeHiddenFiles:NO];
}

+ (NSString *)homeDirectoryForUser:(NSString *)user;
{
    // We write this as a method so that it can be mocked for tests.
    return NSHomeDirectoryForUser(user);
}

+ (NSString *)homeDirectoryForCurrentUser;
{
    // We write this as a method so that it can be mocked for tests.
    return NSHomeDirectory();
}

+ (NSString *)escapeArgument:(NSString *)argument;
{
    NSString *charactersToEscape = @"\\ ~*?\"";
    NSMutableString *mutableArgument = [argument mutableCopy];
    for (NSInteger i = 0; i < charactersToEscape.length; i++) {
        unichar currentChar = [charactersToEscape characterAtIndex:i];
        NSString *search = [NSString stringWithCharacters:&currentChar length:1];
        NSString *replace = [@"\\" stringByAppendingString:search];
        [mutableArgument replaceOccurrencesOfString:search withString:replace options:0 range:NSMakeRange(0, mutableArgument.length)];
    }
    return mutableArgument;
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

- (NSArray *)unescapedArgumentsInDirectory:(NSString *)currentDirectory;
{
    NSMutableArray *unescapedArguments = [NSMutableArray arrayWithCapacity:self.arguments.count];
    for (NSString *argument in self.arguments) {
        [unescapedArguments addObjectsFromArray:[MMCommand unescapeArgument:argument inDirectory:currentDirectory]];
    }

    return unescapedArguments;
}

# pragma mark - Methods called from yacc

- (void)insertArgumentAtFront:(NSString *)argument;
{
    [self.arguments insertObject:argument atIndex:0];
}

- (void)treatFirstArgumentAsStandardOutput;
{
    // We could be calling this method as a result of parsing the command line input for a completion, in which case there might not be an argument after.
    if (self.arguments.count == 0) {
        return;
    }

    self.standardOutput = [MMCommand unescapeArgument:self.arguments[0]][0];
    [self.arguments removeObjectAtIndex:0];
    self.standardOutputSourceType = MMSourceTypeFile;
}

- (void)treatFirstArgumentAsStandardInput;
{
    // We could be calling this method as a result of parsing the command line input for a completion, in which case there might not be an argument after.
    if (self.arguments.count == 0) {
        return;
    }

    self.standardInput = [MMCommand unescapeArgument:self.arguments[0]][0];
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
    // As this is called by the parser, it might be parsing a command for completion.
    // Thus it is possible that no command has been specified yet.
    if (self.commands.count == 0) {
        return;
    }

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

    self.commands = [decoder decodeObjectForKey:MMSelfKey(commands)];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder;
{
    [coder encodeObject:self.commands forKey:MMSelfKey(commands)];
}

@end
