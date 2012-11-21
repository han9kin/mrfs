/*
 *  AFPSession+Fork.m
 *  MRFS
 *
 *  Created by han9kin on 2011-04-20.
 *
 */

#import "NSMutableData+Additions.h"
#import "NSString+Additions.h"
#import "AFPMessage.h"
#import "AFPSession+FileDir.h"
#import "AFPConnection.h"
#import "AFPVolume.h"
#import "AFPDirectory.h"
#import "AFPFile.h"
#import "AFPOpenFork.h"


#ifndef LOG_OFF
#define LOG_PARAMETERS 1
#endif


@implementation AFPSession (Fork)


- (void)doOpenFork:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    uint8_t        sFlag;
    NSNumber      *sVolumeID;
    int32_t        sDirectoryID;
    int16_t        sBitmap;
    int16_t        sAccessMode;
    NSString      *sPathname;

    sPayload += 1; /* CommandCode */
    sFlag     = *sPayload;
    sPayload += 1;
    sVolumeID = [NSNumber numberWithShort:ntohs(*(int16_t *)sPayload)];
    sPayload += 2;
    sDirectoryID = ntohl(*(int32_t *)sPayload);
    sPayload += 4;
    sBitmap = ntohs(*(int16_t *)sPayload);
    sPayload += 2;
    sAccessMode = ntohs(*(int16_t *)sPayload);
    sPayload += 2;
    sPathname = [NSString stringWithPathnameString:sPayload advanced:&sPayload];

#if LOG_PARAMETERS
    NSLog(@"  request block: %@", [NSData dataWithBytes:[aMessage payload] length:[aMessage payloadLength]]);
    NSLog(@"  Flag = %#hhx", sFlag);
    NSLog(@"  VolumeID = %@", sVolumeID);
    NSLog(@"  DirectoryID = %d", sDirectoryID);
    NSLog(@"  Bitmap = %#hx", sBitmap);
    NSLog(@"  AccessMode = %#hx", sAccessMode);
    NSLog(@"  Pathname = %@", sPathname);
#endif


    if ((sBitmap & [self allFileBits]) != sBitmap)
    {
#if LOG_PARAMETERS
        NSLog(@"  Bitmap Error: AvailableFileBits = %#hx, RequestedFileBits = %#hx", [self allFileBits], sBitmap);
#endif

        [aMessage setReplyResult:kFPBitmapErr withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    AFPVolume *sVolume = [mVolumesByID objectForKey:sVolumeID];

    if (!sVolume)
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    AFPDirectory *sDirectory = [sVolume directoryForID:sDirectoryID];

    if (!sDirectory)
    {
        [aMessage setReplyResult:kFPDirNotFound withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    AFPFile *sFile = nil;

    if ([sPathname length])
    {
        sFile = (AFPFile *)[sDirectory nodeForRelativePath:sPathname];

        if ([sFile isDirectory])
        {
            [aMessage setReplyResult:kFPObjectTypeErr withBlock:nil];
            [mConnection replyMessage:aMessage];
            return;
        }
    }

    if (!sFile)
    {
        [aMessage setReplyResult:kFPObjectNotFound withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    if ((sAccessMode & kMRFSFileWrite) && [sVolume isReadOnly])
    {
        [aMessage setReplyResult:kFPVolLocked withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    AFPOpenFork *sFork = [self addForkWithFile:sFile flag:sFlag accessMode:sAccessMode];

    if (!sFork)
    {
        [aMessage setReplyResult:kFPTooManyFilesOpen withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    uint32_t sResult = [sFork openFork];

    if (sResult == kFPNoErr)
    {
        NSMutableData *sReplyBlock = [NSMutableData data];

        [sReplyBlock appendUInt16:sBitmap];
        [sReplyBlock appendUInt16:[sFork forkID]];

        if (sBitmap)
        {
            [self fillParameters:sBitmap on:sReplyBlock withFile:sFile];
        }

        [aMessage setReplyResult:kFPNoErr withBlock:sReplyBlock];
    }
    else
    {
        [self removeFork:sFork];

        [aMessage setReplyResult:sResult withBlock:nil];
    }

    [mConnection replyMessage:aMessage];
}


- (void)doCloseFork:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    int16_t        sForkID;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sForkID = ntohs(*(int16_t *)sPayload);

    AFPOpenFork *sFork = [mForksByID objectForKey:[NSNumber numberWithInt:sForkID]];

    if (sFork)
    {
        uint32_t sResult = [sFork closeFork];

        [self removeFork:sFork];

        [aMessage setReplyResult:sResult withBlock:nil];
    }
    else
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
    }

    [mConnection replyMessage:aMessage];
}


- (void)doGetForkParms:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    int16_t        sForkID;
    int16_t        sBitmap;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sForkID = ntohs(*(int16_t *)sPayload);
    sPayload += 2;
    sBitmap = ntohs(*(int16_t *)sPayload);

    if (!sBitmap || ((sBitmap & [self allFileBits]) != sBitmap))
    {
#if LOG_PARAMETERS
        NSLog(@"  Bitmap Error: AvailableFileBits = %#hx, RequestedFileBits = %#hx", [self allFileBits], sBitmap);
#endif

        [aMessage setReplyResult:kFPBitmapErr withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    AFPOpenFork *sFork = [mForksByID objectForKey:[NSNumber numberWithInt:sForkID]];

    if (!sFork)
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    if ([sFork isResourceFork])
    {
        if (sBitmap & (kFPDataForkLenBit | kFPExtDataForkLenBit))
        {
            [aMessage setReplyResult:kFPParamErr withBlock:nil];
            [mConnection replyMessage:aMessage];
            return;
        }
    }
    else
    {
        if (sBitmap & (kFPRsrcForkLenBit | kFPExtRsrcForkLenBit))
        {
            [aMessage setReplyResult:kFPParamErr withBlock:nil];
            [mConnection replyMessage:aMessage];
            return;
        }
    }

    NSMutableData *sReplyBlock = [NSMutableData data];

    [sReplyBlock appendUInt16:sBitmap];
    [self fillParameters:sBitmap on:sReplyBlock withFile:[sFork file]];

    [aMessage setReplyResult:kFPNoErr withBlock:sReplyBlock];
    [mConnection replyMessage:aMessage];
}


- (void)doSetForkParms:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    int16_t        sForkID;
    int16_t        sBitmap;
    int64_t        sForkLen;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sForkID = ntohs(*(int16_t *)sPayload);
    sPayload += 2;
    sBitmap = ntohs(*(int16_t *)sPayload);
    sPayload += 2;

    AFPOpenFork *sFork = [mForksByID objectForKey:[NSNumber numberWithInt:sForkID]];

    if (!sFork)
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    if (([sFork accessMode] & kMRFSFileWrite) == 0)
    {
        [aMessage setReplyResult:kFPAccessDenied withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    if ([sFork isResourceFork])
    {
        if (sBitmap == kFPExtRsrcForkLenBit)
        {
            sForkLen = NSSwapBigLongLongToHost(*(int64_t *)sPayload);
        }
        else if (sBitmap == kFPRsrcForkLenBit)
        {
            sForkLen = ntohl(*(int32_t *)sPayload);
        }
        else
        {
            [aMessage setReplyResult:kFPBitmapErr withBlock:nil];
            [mConnection replyMessage:aMessage];
            return;
        }
    }
    else
    {
        if (sBitmap == kFPExtDataForkLenBit)
        {
            sForkLen = NSSwapBigLongLongToHost(*(int64_t *)sPayload);
        }
        else if (sBitmap == kFPDataForkLenBit)
        {
            sForkLen = ntohl(*(int32_t *)sPayload);
        }
        else
        {
            [aMessage setReplyResult:kFPBitmapErr withBlock:nil];
            [mConnection replyMessage:aMessage];
            return;
        }
    }

    uint32_t sResult = [sFork truncateAtOffset:sForkLen];

    [aMessage setReplyResult:sResult withBlock:nil];
    [mConnection replyMessage:aMessage];
}


- (void)doReadExt:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    int16_t        sForkID;
    int64_t        sOffset;
    int64_t        sReqCount;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sForkID = ntohs(*(int16_t *)sPayload);
    sPayload += 2;
    sOffset = NSSwapBigLongLongToHost(*(int64_t *)sPayload);
    sPayload += 8;
    sReqCount = NSSwapBigLongLongToHost(*(int64_t *)sPayload);

    AFPOpenFork *sFork = [mForksByID objectForKey:[NSNumber numberWithInt:sForkID]];

    if (!sFork)
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    if (([sFork accessMode] & kMRFSFileRead) == 0)
    {
        [aMessage setReplyResult:kFPAccessDenied withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    if ((sOffset < 0) || (sReqCount < 0))
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    void     *sBuffer = malloc(sReqCount);
    int64_t   sLength;
    uint32_t  sResult;

    sResult = [sFork readFork:sBuffer size:sReqCount offset:sOffset returnedSize:&sLength];

    if ((sResult == kFPNoErr) || (sResult == kFPEOFErr))
    {
        [aMessage setReplyResult:sResult withBlock:[NSData dataWithBytesNoCopy:sBuffer length:sLength freeWhenDone:YES]];
    }
    else
    {
        [aMessage setReplyResult:sResult withBlock:nil];

        free(sBuffer);
    }

    [mConnection replyMessage:aMessage];
}


- (void)doWriteExt:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    uint8_t        sFlag;
    int16_t        sForkID;
    int64_t        sOffset;
    int64_t        sReqCount;

    sPayload += 1; /* CommandCode */
    sFlag = *sPayload;
    sPayload += 1;
    sForkID = ntohs(*(int16_t *)sPayload);
    sPayload += 2;
    sOffset = NSSwapBigLongLongToHost(*(int64_t *)sPayload);
    sPayload += 8;
    sReqCount = NSSwapBigLongLongToHost(*(int64_t *)sPayload);
    sPayload += 8;

    AFPOpenFork *sFork = [mForksByID objectForKey:[NSNumber numberWithInt:sForkID]];

    if (!sFork)
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    if (([sFork accessMode] & kMRFSFileWrite) == 0)
    {
        [aMessage setReplyResult:kFPAccessDenied withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    if (sFlag & 0x80)
    {
        sOffset += [sFork forkLength];
    }

    if ((sOffset < 0) || (sReqCount < 0))
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    int64_t  sSize;
    uint32_t sResult;

    if (sReqCount > 0)
    {
        sResult = [sFork writeFork:sPayload size:sReqCount offset:sOffset writtenSize:&sSize];
    }
    else
    {
        sResult = kFPNoErr;
        sSize   = 0;
    }

    if (sResult == kFPNoErr)
    {
        NSMutableData *sReplyBlock = [NSMutableData data];

        [sReplyBlock appendUInt64:(sOffset + sSize)];

        [aMessage setReplyResult:kFPNoErr withBlock:sReplyBlock];
    }
    else
    {
        [aMessage setReplyResult:sResult withBlock:nil];
    }

    [mConnection replyMessage:aMessage];
}


- (void)doByteRangeLockExt:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    uint8_t        sFlags;
    int16_t        sForkID;
    int64_t        sOffset;
    int64_t        sLength;

    sPayload += 1; /* CommandCode */
    sFlags = *sPayload;
    sPayload += 1;
    sForkID = ntohs(*(int16_t *)sPayload);
    sPayload += 2;
    sOffset = NSSwapBigLongLongToHost(*(int64_t *)sPayload);
    sPayload += 8;
    sLength = NSSwapBigLongLongToHost(*(int64_t *)sPayload);

    AFPOpenFork *sFork = [mForksByID objectForKey:[NSNumber numberWithInt:sForkID]];

    if (!sFork)
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    if (sFlags & 0x80)
    {
        sOffset += [sFork forkLength];
    }

    NSMutableData *sReplyBlock = [NSMutableData data];

    [sReplyBlock appendUInt64:sOffset];

    [aMessage setReplyResult:kFPNoErr withBlock:sReplyBlock];
    [mConnection replyMessage:aMessage];
}


- (void)doFlushFork:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    int16_t        sForkID;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sForkID = ntohs(*(int16_t *)sPayload);

    AFPOpenFork *sFork = [mForksByID objectForKey:[NSNumber numberWithInt:sForkID]];

    if (!sFork)
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    uint32_t sResult = [sFork flushFork];

    [aMessage setReplyResult:sResult withBlock:nil];
    [mConnection replyMessage:aMessage];
}


@end
