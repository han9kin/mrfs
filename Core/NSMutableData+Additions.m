/*
 *  NSMutableData+Additions.m
 *  MRFS
 *
 *  Created by han9kin on 2011-04-18.
 *
 */

#import "NSMutableData+Additions.h"


static uint32_t gTextEncodingHint = 0;


@implementation NSMutableData (Additions)


+ (void)load
{
    if (!gTextEncodingHint)
    {
        gTextEncodingHint = CreateTextEncoding(kTextEncodingUnicodeV3_2, kUnicodeNoSubset, kUnicodeUTF8Format);
    }
}


- (NSUInteger)appendUInt8:(uint8_t)aValue
{
    [self appendBytes:&aValue length:sizeof(aValue)];
    return 1;
}


- (NSUInteger)appendUInt16:(uint16_t)aValue
{
    aValue = htons(aValue);
    [self appendBytes:&aValue length:sizeof(aValue)];
    return 2;
}


- (NSUInteger)appendUInt32:(uint32_t)aValue
{
    aValue = htonl(aValue);
    [self appendBytes:&aValue length:sizeof(aValue)];
    return 4;
}


- (NSUInteger)appendUInt64:(uint64_t)aValue
{
    aValue = NSSwapHostLongLongToBig(aValue);
    [self appendBytes:&aValue length:sizeof(aValue)];
    return 8;
}


- (NSUInteger)appendPascalString:(NSString *)aString maxLength:(NSUInteger)aMaxLength
{
    if ([aString length])
    {
        const char *sString = [aString fileSystemRepresentation];
        size_t      sLength = strlen(sString);

        if (aMaxLength)
        {
            if (aMaxLength > 0xff)
            {
                aMaxLength = 0xff;
            }
        }
        else
        {
            aMaxLength = 0xff;
        }

        if (sLength <= aMaxLength)
        {
            uint8_t sSize = sLength;

            [self appendBytes:&sSize length:sizeof(sSize)];
            [self appendBytes:sString length:sLength];

            return sLength + 1;
        }
        else
        {
            uint8_t sSize = aMaxLength;

            [self appendBytes:&sSize length:sizeof(sSize)];
            [self appendBytes:sString length:aMaxLength];

            return aMaxLength + 1;
        }
    }
    else
    {
        uint8_t sSize = 0;

        [self appendBytes:&sSize length:sizeof(sSize)];

        return 1;
    }
}


- (NSUInteger)appendPSUTF8String:(NSString *)aString maxLength:(NSUInteger)aMaxLength
{
    if ([aString length])
    {
        const char *sString = [aString fileSystemRepresentation];
        size_t      sLength = strlen(sString);

        if (aMaxLength)
        {
            if (aMaxLength > 0xffff)
            {
                aMaxLength = 0xffff;
            }
        }
        else
        {
            aMaxLength = 0xffff;
        }

        if (sLength <= aMaxLength)
        {
            uint16_t sSize = sLength;

            sSize = htons(sSize);

            [self appendBytes:&sSize length:sizeof(sSize)];
            [self appendBytes:sString length:sLength];

            return sLength + 2;
        }
        else
        {
            uint16_t sSize = aMaxLength;

            sSize = htons(sSize);

            [self appendBytes:&sSize length:sizeof(sSize)];
            [self appendBytes:sString length:aMaxLength];

            return aMaxLength + 2;
        }
    }
    else
    {
        uint16_t sSize = 0;

        [self appendBytes:&sSize length:sizeof(sSize)];

        return 2;
    }
}


- (NSUInteger)appendHintedString:(NSString *)aString
{
    NSUInteger sWritten = 0;

    sWritten += [self appendUInt32:gTextEncodingHint];
    sWritten += [self appendPSUTF8String:aString maxLength:0];

    return sWritten;
}


@end
