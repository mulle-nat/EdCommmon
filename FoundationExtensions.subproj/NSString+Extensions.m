//---------------------------------------------------------------------------------------
//  NSString+printf.m created by erik on Sat 27-Sep-1997
//  @(#)$Id: NSString+Extensions.m,v 1.3 2000-10-23 23:22:40 erik Exp $
//
//  Copyright (c) 1997-2000 by Erik Doernenburg. All rights reserved.
//
//  Permission to use, copy, modify and distribute this software and its documentation
//  is hereby granted, provided that both the copyright notice and this permission
//  notice appear in all copies of the software, derivative works or modified versions,
//  and any portions thereof, and that both notices appear in supporting documentation,
//  and that credit is given to Erik Doernenburg in all documents and publicity
//  pertaining to direct or indirect use of this code or its derivatives.
//
//  THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
//  SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
//  "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
//  DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
//  OR OF ANY DERIVATIVE WORK.
//---------------------------------------------------------------------------------------

#import <Foundation/Foundation.h>
#import "NSString+Extensions.h"

#ifndef WIN32
#import <unistd.h>
#else
#define random() rand()
#endif


//---------------------------------------------------------------------------------------
    @implementation NSString(EDExtensions)
//---------------------------------------------------------------------------------------

static NSFileHandle *stdoutFileHandle = nil;
static NSLock *printfLock = nil;
static NSCharacterSet *iwsSet = nil;


//---------------------------------------------------------------------------------------
//	CONVENIENCE CONSTRUCTORS
//---------------------------------------------------------------------------------------

+ (NSString *)stringWithData:(NSData *)data encoding:(NSStringEncoding)encoding
{
    return [[[NSString alloc] initWithData:data encoding:encoding] autorelease];
}


//---------------------------------------------------------------------------------------
//	VARIOUS EXTENSIONS
//---------------------------------------------------------------------------------------

- (NSString *)stringByRemovingSurroundingWhitespace
{
    NSRange				  start, end, result;

    if(iwsSet == nil)
        iwsSet = [[[NSCharacterSet whitespaceCharacterSet] invertedSet] retain];

    start = [self rangeOfCharacterFromSet:iwsSet];
    if(start.length == 0)
        return @""; // string is empty or consists of whitespace only

    end = [self rangeOfCharacterFromSet:iwsSet options:NSBackwardsSearch];
    if((start.location == 0) && (end.location == [self length] - 1))
        return self;

    result = NSMakeRange(start.location, end.location + end.length - start.location);

    return [self substringWithRange:result];	
}


- (BOOL)isWhitespace
{
    if(iwsSet == nil)
        iwsSet = [[[NSCharacterSet whitespaceCharacterSet] invertedSet] retain];

    return ([self rangeOfCharacterFromSet:iwsSet].length == 0);

}


- (BOOL)hasPrefixCaseInsensitive:(NSString *)string
{
    return (([string length] <= [self length]) && ([self compare:string options:(NSCaseInsensitiveSearch|NSAnchoredSearch) range:NSMakeRange(0, [string length])] == NSOrderedSame));
}


- (BOOL)boolValue
{
    if([self intValue] > 0)
        return YES;
    return [self caseInsensitiveCompare:@"yes"] == NSOrderedSame;
}


- (unsigned int)intValueForHex
{
    unsigned int	value;

    if([[NSScanner scannerWithString:self] scanHexInt:&value] == NO)
        return 0;
    return value;
}


- (BOOL)isEmpty
{
  return [self isEqualToString:@""];
}


//---------------------------------------------------------------------------------------
//	CRYPTING
//---------------------------------------------------------------------------------------

- (NSString *)encryptedString
{
    char 	salt[3];

    salt[0] = 'A' + random() % 26;
    salt[1] = 'A' + random() % 26;
    salt[2] = '\0';

    return [self encryptedStringWithSalt:salt];
}


- (NSString *)encryptedStringWithSalt:(const char *)salt
{
    static NSLock	*encryptLock = nil;
    NSMutableData 	*sdata;
    char 			*encryptedCString;
    NSString 		*encryptedString;
    char 			terminator = '\0';

    NSParameterAssert((salt != NULL) && (strlen(salt) == 2));

    if(encryptLock == nil)
        encryptLock = [[NSLock alloc] init]; // intentional leak

    sdata = [[self dataUsingEncoding:NSNonLossyASCIIStringEncoding] mutableCopy];
    [sdata appendBytes:&terminator length:1];

    [encryptLock lock];
    encryptedCString = crypt((const char *)[sdata bytes], (const char *)salt);
    encryptedString = [[[NSString allocWithZone:[self zone]] initWithCString:encryptedCString] autorelease];
    [encryptLock unlock];

    [sdata release];
    
    return encryptedString;
}


- (BOOL)isValidEncryptionOfString:(NSString *)aString
{
  char salt[3];

  [self getCString:salt maxLength:2];
  salt[2] = '\0';
  return [self isEqualToString:[aString encryptedStringWithSalt:salt]];
}


//---------------------------------------------------------------------------------------
//	SHARING STRING INSTANCES (USE WITH CAUTION!)
//---------------------------------------------------------------------------------------

- (NSString *)sharedInstance
{
    static NSMutableSet *stringPool;
    NSString *sharedInstance;

    if(stringPool == nil)
        stringPool = [[NSMutableSet alloc] init];

    if((sharedInstance = [stringPool member:self]) != nil)
        return sharedInstance;
    [stringPool addObject:self];
    return self;
}


//---------------------------------------------------------------------------------------
//	PRINTING
//---------------------------------------------------------------------------------------

+ (void)printf:(NSString *)format, ...
{
    va_list   	args;
    NSString	*buffer;

    va_start(args, format);
    buffer = [[NSString alloc] initWithFormat:format arguments:args];
    [buffer printf];
    [buffer release];
    va_end(args);
}


+ (void)fprintf:(NSFileHandle *)fileHandle:(NSString *)format, ...
{
    va_list   	args;
    NSString	*buffer;

    va_start(args, format);
    buffer = [[NSString alloc] initWithFormat:format arguments:args];
    [buffer fprintf:fileHandle];
    [buffer release];
    va_end(args);
}


- (void)printf
{
    if(printfLock == nil)
        printfLock = [[NSLock alloc] init];

    [printfLock lock];
    if(stdoutFileHandle == nil)
        stdoutFileHandle = [[NSFileHandle fileHandleWithStandardOutput] retain];
    [stdoutFileHandle writeData:[self dataUsingEncoding:[NSString defaultCStringEncoding]]];
    [printfLock unlock];
}


- (void)fprintf:(NSFileHandle *)fileHandle
{
    if(printfLock == nil)
        printfLock = [[NSLock alloc] init];

    [printfLock lock];
    [fileHandle writeData:[self dataUsingEncoding:[NSString defaultCStringEncoding]]];
    [printfLock unlock];
}


//---------------------------------------------------------------------------------------
    @end
//---------------------------------------------------------------------------------------
