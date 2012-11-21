/*
 *  AFPSession+Volume.m
 *  MRFS
 *
 *  Created by han9kin on 2011-04-19.
 *
 */

#import "NSMutableData+Additions.h"
#import "NSString+Additions.h"
#import "AFPMessage.h"
#import "AFPSession.h"
#import "AFPConnection.h"
#import "AFPListener.h"
#import "AFPServer.h"
#import "AFPVolume.h"


#ifndef LOG_OFF
#define LOG_PARAMETERS 0
#endif


@implementation AFPSession (Volume)


#pragma mark -


- (BOOL)replyVolumeParametersWithMessage:(AFPMessage *)aMessage volume:(AFPVolume *)aVolume bitmap:(int16_t)aBitmap
{
    static int16_t sAllBits =
        kFPVolAttributeBit |
        kFPVolSignatureBit |
        kFPVolCreateDateBit |
        kFPVolModDateBit |
        kFPVolBackupDateBit |
        kFPVolIDBit |
        kFPVolBytesFreeBit |
        kFPVolBytesTotalBit |
        kFPVolNameBit |
        kFPVolExtBytesFreeBit |
        kFPVolExtBytesTotalBit |
        kFPVolBlockSizeBit;

    if (aBitmap && ((aBitmap & sAllBits) == aBitmap))
    {
        NSMutableData *sReplyBlock     = [NSMutableData data];
        NSMutableData *sVariableBlock  = [NSMutableData data];
        uint16_t       sBaseOffset     = 0;
        uint16_t       sFixedOffset    = 0;
        uint16_t       sVariableOffset = 0;
        int16_t        sVolNameLoc     = -1;
        int16_t        sVolNameOffset  = -1;

        sBaseOffset += [sReplyBlock appendUInt16:aBitmap];

        if (aBitmap & kFPVolAttributeBit)
        {
#if LOG_PARAMETERS
            NSLog(@"  -> Volume:kFPVolAttributeBit = %#hx", [aVolume attribute]);
#endif
            sFixedOffset += [sReplyBlock appendUInt16:[aVolume attribute]];
        }

        if (aBitmap & kFPVolSignatureBit)
        {
#if LOG_PARAMETERS
            NSLog(@"  -> Volume:kFPVolSignatureBit = %hu", 2);
#endif
            sFixedOffset += [sReplyBlock appendUInt16:2]; /* Fixed Directory ID */
        }

        if (aBitmap & kFPVolCreateDateBit)
        {
#if LOG_PARAMETERS
            NSLog(@"  -> Volume:kFPVolCreateDateBit = %d", [aVolume creationDate]);
#endif
            sFixedOffset += [sReplyBlock appendUInt32:[aVolume creationDate]];
        }

        if (aBitmap & kFPVolModDateBit)
        {
#if LOG_PARAMETERS
            NSLog(@"  -> Volume:kFPVolModDateBit = %d", [aVolume modificationDate]);
#endif
            sFixedOffset += [sReplyBlock appendUInt32:[aVolume modificationDate]];
        }

        if (aBitmap & kFPVolBackupDateBit)
        {
#if LOG_PARAMETERS
            NSLog(@"  -> Volume:kFPVolBackupDateBit = %d", [aVolume backupDate]);
#endif
            sFixedOffset += [sReplyBlock appendUInt32:[aVolume backupDate]];
        }

        if (aBitmap & kFPVolIDBit)
        {
#if LOG_PARAMETERS
            NSLog(@"  -> Volume:kFPVolIDBit = %hu", [aVolume volumeID]);
#endif
            sFixedOffset += [sReplyBlock appendUInt16:[aVolume volumeID]];
        }

        if (aBitmap & kFPVolBytesFreeBit)
        {
#if LOG_PARAMETERS
            NSLog(@"  -> Volume:kFPVolBytesFreeBit = %u", [aVolume freeBytes]);
#endif
            sFixedOffset += [sReplyBlock appendUInt32:[aVolume freeBytes]];
        }

        if (aBitmap & kFPVolBytesTotalBit)
        {
#if LOG_PARAMETERS
            NSLog(@"  -> Volume:kFPVolBytesTotalBit = %u", [aVolume totalBytes]);
#endif
            sFixedOffset += [sReplyBlock appendUInt32:[aVolume totalBytes]];
        }

        if (aBitmap & kFPVolNameBit)
        {
#if LOG_PARAMETERS
            NSLog(@"  -> Volume:kFPVolNameBit = %@", [aVolume volumeName]);
#endif
            sVolNameLoc      = sVariableOffset;
            sVolNameOffset   = sFixedOffset;
            sFixedOffset    += [sReplyBlock appendUInt16:0];
            sVariableOffset += [sVariableBlock appendPascalString:[aVolume volumeName] maxLength:0];
        }

        if (aBitmap & kFPVolExtBytesFreeBit)
        {
#if LOG_PARAMETERS
            NSLog(@"  -> Volume:kFPVolExtBytesFreeBit = %llu", [aVolume freeBytesExt]);
#endif
            sFixedOffset += [sReplyBlock appendUInt64:[aVolume freeBytesExt]];
        }

        if (aBitmap & kFPVolExtBytesTotalBit)
        {
#if LOG_PARAMETERS
            NSLog(@"  -> Volume:kFPVolExtBytesTotalBit = %llu", [aVolume totalBytesExt]);
#endif
            sFixedOffset += [sReplyBlock appendUInt64:[aVolume totalBytesExt]];
        }

        if (aBitmap & kFPVolBlockSizeBit)
        {
#if LOG_PARAMETERS
            NSLog(@"  -> Volume:kFPVolBlockSizeBit = %u", [aVolume blockSize]);
#endif
            sFixedOffset += [sReplyBlock appendUInt32:[aVolume blockSize]];
        }

        if (sVolNameLoc >= 0)
        {
            sVolNameLoc = htons(sVolNameLoc + sFixedOffset);
            [sReplyBlock replaceBytesInRange:NSMakeRange(sBaseOffset + sVolNameOffset, 2) withBytes:&sVolNameLoc length:2];
        }

        [sReplyBlock appendData:sVariableBlock];

#if LOG_PARAMETERS
    NSLog(@"  reply block: %@", sReplyBlock);
#endif

        [aMessage setReplyResult:kFPNoErr withBlock:sReplyBlock];

        return YES;
    }
    else
    {
        [aMessage setReplyResult:kFPBitmapErr withBlock:nil];

        return NO;
    }
}


#pragma mark -


- (void)doOpenVol:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    int16_t        sBitmap;
    NSString      *sVolumeName;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sBitmap = ntohs(*(int16_t *)sPayload);
    sPayload += 2;
    sVolumeName = [NSString stringWithPascalString:sPayload advanced:&sPayload];

    AFPVolume *sVolume = [[[mConnection listener] server] volumeForName:sVolumeName];

    if (sVolume)
    {
        if ([self replyVolumeParametersWithMessage:aMessage volume:sVolume bitmap:sBitmap])
        {
            [mVolumesByID setObject:sVolume forKey:[NSNumber numberWithShort:[sVolume volumeID]]];
        }
    }
    else
    {
        [aMessage setReplyResult:kFPObjectNotFound withBlock:nil];
    }

#if LOG_PARAMETERS
    NSLog(@"  Open Volume: %@ current = %@", sVolume, mVolumesByID);
#endif

    [mConnection replyMessage:aMessage];
}


- (void)doCloseVol:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    NSNumber      *sVolumeID;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sVolumeID = [NSNumber numberWithShort:ntohs(*(int16_t *)sPayload)];

    AFPVolume *sVolume = [mVolumesByID objectForKey:sVolumeID];

    if (sVolume)
    {
        [mVolumesByID removeObjectForKey:sVolumeID];

        [aMessage setReplyResult:kFPNoErr withBlock:nil];
    }
    else
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
    }

#if LOG_PARAMETERS
    NSLog(@"  Close Volume: %@ current = %@", sVolume, mVolumesByID);
#endif

    [mConnection replyMessage:aMessage];
}


- (void)doGetVolParms:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    NSNumber      *sVolumeID;
    int16_t        sBitmap;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sVolumeID = [NSNumber numberWithShort:ntohs(*(int16_t *)sPayload)];
    sPayload += 2;
    sBitmap = ntohs(*(int16_t *)sPayload);

    AFPVolume *sVolume = [mVolumesByID objectForKey:sVolumeID];

    if (sVolume)
    {
        [self replyVolumeParametersWithMessage:aMessage volume:sVolume bitmap:sBitmap];
    }
    else
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
    }

    [mConnection replyMessage:aMessage];
}


- (void)doSetVolParms:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    NSNumber      *sVolumeID;
    int16_t        sBitmap;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sVolumeID = [NSNumber numberWithShort:ntohs(*(int16_t *)sPayload)];
    sPayload += 2;
    sBitmap = ntohs(*(int16_t *)sPayload);

    if (sBitmap != kFPVolBackupDateBit)
    {
        [aMessage setReplyResult:kFPBitmapErr withBlock:nil];
    }

    AFPVolume *sVolume = [mVolumesByID objectForKey:sVolumeID];

    if (sVolume)
    {
        if ([sVolume isReadOnly])
        {
            [aMessage setReplyResult:kFPVolLocked withBlock:nil];
        }
        else
        {
            /*
             * no support for backup date, ignore silently
             */
            [aMessage setReplyResult:kFPNoErr withBlock:nil];
        }
    }
    else
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
    }

    [mConnection replyMessage:aMessage];
}


- (void)doFlush:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    NSNumber      *sVolumeID;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sVolumeID = [NSNumber numberWithShort:ntohs(*(int16_t *)sPayload)];

    AFPVolume *sVolume = [mVolumesByID objectForKey:sVolumeID];

    if (sVolume)
    {
        uint32_t sResult = [sVolume flush];

        [aMessage setReplyResult:sResult withBlock:nil];
    }
    else
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
    }

    [mConnection replyMessage:aMessage];
}


#pragma mark -


- (void)doOpenDT:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    NSNumber      *sVolumeID;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sVolumeID = [NSNumber numberWithShort:ntohs(*(int16_t *)sPayload)];

    AFPVolume *sVolume = [mVolumesByID objectForKey:sVolumeID];

    if (sVolume)
    {
        NSMutableData *sReplyBlock = [NSMutableData data];

        [sReplyBlock appendUInt16:[sVolumeID unsignedShortValue]];

        [aMessage setReplyResult:kFPNoErr withBlock:sReplyBlock];
    }
    else
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
    }

    [mConnection replyMessage:aMessage];
}


- (void)doCloseDT:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    NSNumber      *sDesktopID;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sDesktopID = [NSNumber numberWithShort:ntohs(*(int16_t *)sPayload)];

    AFPVolume *sVolume = [mVolumesByID objectForKey:sDesktopID];

    if (sVolume)
    {
        [aMessage setReplyResult:kFPNoErr withBlock:nil];
    }
    else
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
    }

    [mConnection replyMessage:aMessage];
}


@end
