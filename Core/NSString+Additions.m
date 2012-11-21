/*
 *  NSString+Additions.m
 *  MRFS
 *
 *  Created by han9kin on 2011-04-19.
 *
 */

#import "NSString+Additions.h"


@implementation NSString (Additions)


+ (NSString *)stringWithPascalString:(const uint8_t *)aPascalString advanced:(const uint8_t **)aPointer
{
    uint8_t sLength = *aPascalString;

    if (aPointer)
    {
        *aPointer = aPascalString + sLength + 1;
    }

    if (sLength)
    {
        return [[[self alloc] initWithBytes:(aPascalString + 1) length:sLength encoding:NSUTF8StringEncoding] autorelease];
    }
    else
    {
        return @"";
    }
}


+ (NSString *)stringWithPSUTF8String:(const uint8_t *)aPSUTF8String advanced:(const uint8_t **)aPointer
{
    uint16_t sLength = ntohs(*(uint16_t *)aPSUTF8String);

    if (aPointer)
    {
        *aPointer = aPSUTF8String + sLength + 2;
    }

    if (sLength)
    {
        return [[[self alloc] initWithBytes:(aPSUTF8String + 2) length:sLength encoding:NSUTF8StringEncoding] autorelease];
    }
    else
    {
        return @"";
    }
}


+ (NSString *)stringWithTypedString:(const uint8_t *)aTypedString advanced:(const uint8_t **)aPointer
{
    uint8_t   sType = *aTypedString;
    NSString *sString;

    switch (sType)
    {
        case 1: /* kFPShortName */
        case 2: /* kFPLongName */
            sString = [self stringWithPascalString:(aTypedString + 1) advanced:aPointer];
            break;
        case 3: /* kFPUTF8Name */
            sString = [self stringWithPSUTF8String:(aTypedString + 1) advanced:aPointer];
            break;
        default:
            sString = nil;
            break;
    }

    return sString;
}


+ (NSString *)stringWithHintedString:(const uint8_t *)aHintedString advanced:(const uint8_t **)aPointer
{
    uint8_t   sType = *aHintedString;
    NSString *sString;

    switch (sType)
    {
        case 1: /* kFPShortName */
        case 2: /* kFPLongName */
            sString = [self stringWithPascalString:(aHintedString + 1) advanced:aPointer];
            break;
        case 3: /* kFPUTF8Name */
            sString = [self stringWithPSUTF8String:(aHintedString + 5) advanced:aPointer];
            break;
        default:
            sString = nil;
            break;
    }

    return sString;
}


+ (NSString *)stringWithPathnameString:(const uint8_t *)aPathnameString advanced:(const uint8_t **)aPointer
{
    const uint8_t  *sPtr  = aPathnameString;
    uint8_t         sType = *sPtr;
    uint16_t        sLength;

    switch (sType)
    {
        case 1: /* kFPShortName */
        case 2: /* kFPLongName */
            sLength  = *(sPtr + 1);
            sPtr    += 2;
            break;
        case 3: /* kFPUTF8Name */
            sLength  = ntohs(*(uint16_t *)(sPtr + 5));
            sPtr    += 7;
            break;
        default:
            return nil;
            break;
    }

    NSMutableArray *sComps = [NSMutableArray array];
    const uint8_t  *sStop  = sPtr + sLength;

    while (sPtr < sStop)
    {
        if (*sPtr)
        {
            const uint8_t *sComp = sPtr;
            NSString      *sName;

            for (sPtr++; (*sPtr != 0) && (sPtr < sStop); sPtr++)
            {
            }

            sName = [[[self alloc] initWithBytes:sComp length:(sPtr - sComp) encoding:NSUTF8StringEncoding] autorelease];

            if (!sName)
            {
                sName = [[[self alloc] initWithBytes:sComp length:(sPtr - sComp) encoding:NSISOLatin1StringEncoding] autorelease];
                NSLog(@"Pathname may not be UTF8, try decoding ISO8859-1 (%@)", sName);
            }

            NSAssert(sName, @"pathname decoding failed");

            [sComps addObject:sName];
        }
        else
        {
            int sCount = 0;

            for (sPtr++; (*sPtr == 0) && (sPtr < sStop); sPtr++)
            {
                sCount++;
            }

            for (int i = 0; i < sCount; i++)
            {
                [sComps addObject:@".."];
            }
        }
    }

    if (aPointer)
    {
        *aPointer = sStop;
    }

    return [self pathWithComponents:sComps];
}


- (BOOL)demangleFilenamePrefix:(NSString **)aPrefix suffix:(NSString **)aSuffix nodeID:(uint32_t *)aNodeID
{
    NSRange sRange = [self rangeOfString:@"#" options:NSBackwardsSearch];

    if (sRange.location == NSNotFound)
    {
        return NO;
    }

    uint32_t  sNodeID = 0;
    NSInteger sIndex;

    for (sIndex = sRange.location + 1; sIndex < [self length]; sIndex++)
    {
        unichar sChar = [self characterAtIndex:sIndex];

        if ((sNodeID == 0) && (sChar == '0'))
        {
            break;
        }

        if ((sChar >= '0') && (sChar <= '9'))
        {
            sNodeID *= 16;
            sNodeID += sChar - '0';
        }
        else if ((sChar >= 'A') && (sChar <= 'F'))
        {
            sNodeID *= 16;
            sNodeID += 10 + sChar - 'A';
        }
        else
        {
            break;
        }
    }

    if (sNodeID)
    {
        if (sRange.location > 0)
        {
            *aPrefix = [self substringToIndex:sRange.location];
        }
        else
        {
            *aPrefix = @"";
        }

        if (sIndex < [self length])
        {
            *aSuffix = [self substringFromIndex:sIndex];
        }
        else
        {
            *aSuffix = @"";
        }

        *aNodeID = sNodeID;

        return YES;
    }
    else
    {
        return NO;
    }
}


@end
