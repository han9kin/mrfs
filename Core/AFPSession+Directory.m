/*
 *  AFPSession+Directory.m
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


#ifndef LOG_OFF
#define LOG_PARAMETERS 1
#endif


@implementation AFPSession (Directory)


- (void)doSetDirParms:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    NSNumber      *sVolumeID;
    int32_t        sDirectoryID;
    int16_t        sBitmap;
    NSString      *sPathname;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sVolumeID = [NSNumber numberWithShort:ntohs(*(int16_t *)sPayload)];
    sPayload += 2;
    sDirectoryID = ntohl(*(int32_t *)sPayload);
    sPayload += 4;
    sBitmap = ntohs(*(int16_t *)sPayload);
    sPayload += 2;
    sPathname = [NSString stringWithPathnameString:sPayload advanced:&sPayload];

    if ((sPayload - [aMessage payload]) & 1)
    {
        sPayload += 1; /* 2-byte align */
    }

    if (!sBitmap)
    {
        [aMessage setReplyResult:kFPBitmapErr withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    AFPVolume *sVolume = [mVolumesByID objectForKey:sVolumeID];

    if ([sVolume isReadOnly])
    {
        [aMessage setReplyResult:kFPVolLocked withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }
    else if (!sVolume)
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

    if ([sPathname length])
    {
        AFPNode *sNode = [sDirectory nodeForRelativePath:sPathname];

        if (sNode)
        {
            if ([sNode isDirectory])
            {
                sDirectory = (AFPDirectory *)sNode;
            }
            else
            {
                [aMessage setReplyResult:kFPObjectTypeErr withBlock:nil];
                [mConnection replyMessage:aMessage];
                return;
            }
        }
        else
        {
            [aMessage setReplyResult:kFPObjectNotFound withBlock:nil];
            [mConnection replyMessage:aMessage];
            return;
        }
    }

    uint32_t sResult = [sDirectory setParameters:sPayload bitmap:sBitmap];

    [aMessage setReplyResult:sResult withBlock:nil];
    [mConnection replyMessage:aMessage];
}


- (void)doEnumerateExt2:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    uint8_t        sCommand = [aMessage afpCommand];
    NSNumber      *sVolumeID;
    int32_t        sDirectoryID;
    int16_t        sFileBitmap;
    int16_t        sDirectoryBitmap;
    int16_t        sReqCount;
    int32_t        sStartIndex;
    int32_t        sMaxReplySize;
    NSString      *sPathname;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sVolumeID = [NSNumber numberWithShort:ntohs(*(int16_t *)sPayload)];
    sPayload += 2;
    sDirectoryID = ntohl(*(int32_t *)sPayload);
    sPayload += 4;
    sFileBitmap = ntohs(*(int16_t *)sPayload);
    sPayload += 2;
    sDirectoryBitmap = ntohs(*(int16_t *)sPayload);
    sPayload += 2;
    sReqCount = ntohs(*(int16_t *)sPayload);
    sPayload += 2;

    if (sCommand == kFPEnumerateExt2)
    {
        sStartIndex = ntohl(*(int32_t *)sPayload);
        sPayload += 4;
        sMaxReplySize = ntohl(*(int32_t *)sPayload);
        sPayload += 4;
    }
    else /* kFPEnumerateExt */
    {
        sStartIndex = ntohs(*(int16_t *)sPayload);
        sPayload += 2;
        sMaxReplySize = ntohs(*(int16_t *)sPayload);
        sPayload += 2;
    }

    sPathname = [NSString stringWithPathnameString:sPayload advanced:&sPayload];

#if LOG_PARAMETERS
    NSLog(@"  request block: %@", [NSData dataWithBytes:[aMessage payload] length:[aMessage payloadLength]]);
    NSLog(@"  VolumeID = %@", sVolumeID);
    NSLog(@"  DirectoryID = %d", sDirectoryID);
    NSLog(@"  FileBitmap = %#hx", sFileBitmap);
    NSLog(@"  DirectoryBitmap = %#hx", sDirectoryBitmap);
    NSLog(@"  ReqCount = %hd", sReqCount);
    NSLog(@"  StartIndex = %d", sStartIndex);
    NSLog(@"  MaxReplySize = %d", sMaxReplySize);
    NSLog(@"  Pathname = %@", sPathname);
#endif


    if (((sFileBitmap & [self allFileBits]) != sFileBitmap) || ((sDirectoryBitmap & [self allDirectoryBits]) != sDirectoryBitmap))
    {
#if LOG_PARAMETERS
        NSLog(@"  Bitmap Error: AvailableFileBits = %#hx, RequestedFileBits = %#hx, AvailableDirBits = %#hx, RequestedDirBits = %#hx", [self allFileBits], sFileBitmap, [self allDirectoryBits], sDirectoryBitmap);
#endif

        [aMessage setReplyResult:kFPBitmapErr withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    if (sStartIndex)
    {
        sStartIndex -= 1;
    }
    else
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
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

    if ([sPathname length])
    {
        AFPNode *sNode = [sDirectory nodeForRelativePath:sPathname];

        if (sNode)
        {
            if ([sNode isDirectory])
            {
                sDirectory = (AFPDirectory *)sNode;
            }
            else
            {
                [aMessage setReplyResult:kFPObjectTypeErr withBlock:nil];
                [mConnection replyMessage:aMessage];
                return;
            }
        }
        else
        {
            [aMessage setReplyResult:kFPDirNotFound withBlock:nil];
            [mConnection replyMessage:aMessage];
            return;
        }
    }

    NSArray *sOffspringNodes;

    if (sStartIndex == 0)
    {
        if ([sDirectory refreshOffspringNodes])
        {
            [sVolume updateModificationDate];
            [mConnection sendAttention:kMsgNotifyVolumeChanged];
        }
    }

    if (sFileBitmap && sDirectoryBitmap)
    {
        sOffspringNodes = [sDirectory offspringNodesWithRange:NSMakeRange(sStartIndex, sReqCount) option:AFPEnumerateAll];
    }
    else if (sFileBitmap)
    {
        sOffspringNodes = [sDirectory offspringNodesWithRange:NSMakeRange(sStartIndex, sReqCount) option:AFPEnumerateFiles];
    }
    else if (sDirectoryBitmap)
    {
        sOffspringNodes = [sDirectory offspringNodesWithRange:NSMakeRange(sStartIndex, sReqCount) option:AFPEnumerateDirectories];
    }
    else
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    if ([sOffspringNodes count])
    {
        NSMutableData *sResultsBlock = [NSMutableData data];
        uint16_t       sCount        = 0;

        for (AFPNode *sNode in sOffspringNodes)
        {
            NSMutableData *sRecordBlock = [NSMutableData data];

            if ([sNode isDirectory])
            {
                [sRecordBlock appendUInt16:0x8000];
                [self fillParameters:sDirectoryBitmap on:sRecordBlock withDirectory:(AFPDirectory *)sNode];
            }
            else
            {
                [sRecordBlock appendUInt16:0x0000];
                [self fillParameters:sFileBitmap on:sRecordBlock withFile:(AFPFile *)sNode];
            }

            if (([sResultsBlock length] + [sRecordBlock length] + 8) > sMaxReplySize)
            {
                break;
            }
            else
            {
                [sResultsBlock appendUInt16:([sRecordBlock length] + 2)];
                [sResultsBlock appendData:sRecordBlock];
            }

            sCount++;
        }

#if LOG_PARAMETERS
        NSLog(@"  results record count: %hu", sCount);
#endif

        if (sCount)
        {
            NSMutableData *sReplyBlock = [NSMutableData data];

            [sReplyBlock appendUInt16:sFileBitmap];
            [sReplyBlock appendUInt16:sDirectoryBitmap];
            [sReplyBlock appendUInt16:sCount];
            [sReplyBlock appendData:sResultsBlock];

#if LOG_PARAMETERS
            NSLog(@"  reply block: %@", sReplyBlock);
#endif

            [aMessage setReplyResult:kFPNoErr withBlock:sReplyBlock];
        }
        else
        {
            [aMessage setReplyResult:kFPParamErr withBlock:nil];
        }
    }
    else
    {
        [aMessage setReplyResult:kFPObjectNotFound withBlock:nil];
    }

    [mConnection replyMessage:aMessage];
}


- (void)doCreateDir:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    NSNumber      *sVolumeID;
    int32_t        sDirectoryID;
    NSString      *sPathname;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sVolumeID = [NSNumber numberWithShort:ntohs(*(int16_t *)sPayload)];
    sPayload += 2;
    sDirectoryID = ntohl(*(int32_t *)sPayload);
    sPayload += 4;
    sPathname = [NSString stringWithPathnameString:sPayload advanced:&sPayload];


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

    if (![sPathname length])
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    AFPNode  *sNode;
    uint32_t  sResult;

    sResult = [sDirectory createDirectory:&sNode withName:sPathname];

    if (sResult == kFPNoErr)
    {
        NSMutableData *sReplyBlock = [NSMutableData data];

        [sReplyBlock appendUInt32:[sNode nodeID]];

        [aMessage setReplyResult:sResult withBlock:sReplyBlock];
    }
    else
    {
        [aMessage setReplyResult:sResult withBlock:nil];
    }

    [mConnection replyMessage:aMessage];
}


@end
