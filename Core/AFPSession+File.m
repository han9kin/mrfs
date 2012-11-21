/*
 *  AFPSession+File.m
 *  MRFS
 *
 *  Created by han9kin on 2011-04-20.
 *
 */

#import "NSMutableData+Additions.h"
#import "NSString+Additions.h"
#import "AFPMessage.h"
#import "AFPSession.h"
#import "AFPConnection.h"
#import "AFPVolume.h"
#import "AFPDirectory.h"


@implementation AFPSession (File)


- (void)doSetFileParms:(AFPMessage *)aMessage
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

    AFPNode *sNode;

    if ([sPathname length])
    {
        sNode = [sDirectory nodeForRelativePath:sPathname];

        if (sNode)
        {
            if ([sNode isDirectory])
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
    else
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    uint32_t sResult = [sNode setParameters:sPayload bitmap:sBitmap];

    [aMessage setReplyResult:sResult withBlock:nil];
    [mConnection replyMessage:aMessage];
}


- (void)doCreateFile:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    uint8_t        sFlag;
    NSNumber      *sVolumeID;
    int32_t        sDirectoryID;
    NSString      *sPathname;

    sPayload += 1; /* CommandCode */
    sFlag = *sPayload;
    sPayload += 1;
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

    sResult = [sDirectory createFile:&sNode recreateIfExists:(sFlag ? YES : NO) withName:sPathname];

    [aMessage setReplyResult:sResult withBlock:nil];
    [mConnection replyMessage:aMessage];
}


@end
