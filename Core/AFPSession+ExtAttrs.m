/*
 *  AFPSession+ExtAttrs.m
 *  MRFS
 *
 *  Created by han9kin on 2011-05-06.
 *
 */

#import "NSMutableData+Additions.h"
#import "NSString+Additions.h"
#import "AFPMessage.h"
#import "AFPSession.h"
#import "AFPConnection.h"
#import "AFPVolume.h"
#import "AFPDirectory.h"


@implementation AFPSession (ExtAttrs)


- (void)doListExtAttrs:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    NSNumber      *sVolumeID;
    int32_t        sDirectoryID;
    uint16_t       sBitmap;
    int32_t        sMaxReplySize;
    NSString      *sPathname;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sVolumeID = [NSNumber numberWithShort:ntohs(*(int16_t *)sPayload)];
    sPayload += 2;
    sDirectoryID = ntohl(*(int32_t *)sPayload);
    sPayload += 4;
    sBitmap = ntohs(*(uint16_t *)sPayload);
    sPayload += 2;
    sPayload += 2; /* ReqCount */
    sPayload += 4; /* StartIndex */
    sMaxReplySize = ntohl(*(int32_t *)sPayload);
    sPayload += 4;
    sPathname = [NSString stringWithPathnameString:sPayload advanced:&sPayload];

    if ((sBitmap & kXAttrNoFollow) != sBitmap)
    {
        [aMessage setReplyResult:kFPBitmapErr withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    if (sMaxReplySize < 0)
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

    AFPNode *sNode;

    if ([sPathname length])
    {
        sNode = [sDirectory nodeForRelativePath:sPathname];

        if (!sNode)
        {
            [aMessage setReplyResult:kFPObjectNotFound withBlock:nil];
            [mConnection replyMessage:aMessage];
            return;
        }
    }
    else
    {
        sNode = sDirectory;
    }

    void     *sBuffer = sMaxReplySize ? malloc(sMaxReplySize) : NULL;
    int64_t   sLength;
    uint32_t  sResult;

    if ([sVolume supportsExtendedAttributes])
    {
        sResult = [sNode listExtendedAttributes:sBuffer size:sMaxReplySize returnedSize:&sLength bitmap:sBitmap];
    }
    else
    {
        sLength = 0;
        sResult = kFPNoErr;
    }

    if (sResult == kFPNoErr)
    {
        NSMutableData *sReplyBlock = [NSMutableData data];

        [sReplyBlock appendUInt16:sBitmap];
        [sReplyBlock appendUInt32:sLength];

        if (sBuffer)
        {
            [sReplyBlock appendData:[NSData dataWithBytesNoCopy:sBuffer length:sLength freeWhenDone:YES]];
        }

        [aMessage setReplyResult:sResult withBlock:sReplyBlock];
    }
    else
    {
        [aMessage setReplyResult:sResult withBlock:nil];

        if (sBuffer)
        {
            free(sBuffer);
        }
    }

    [mConnection replyMessage:aMessage];
}


- (void)doGetExtAttr:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    NSNumber      *sVolumeID;
    int32_t        sDirectoryID;
    uint16_t       sBitmap;
    int32_t        sMaxReplySize;
    NSString      *sPathname;
    NSString      *sName;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sVolumeID = [NSNumber numberWithShort:ntohs(*(int16_t *)sPayload)];
    sPayload += 2;
    sDirectoryID = ntohl(*(int32_t *)sPayload);
    sPayload += 4;
    sBitmap = ntohs(*(uint16_t *)sPayload);
    sPayload += 2;
    sPayload += 8; /* Offset */
    sPayload += 8; /* ReqCount */
    sMaxReplySize = ntohl(*(int32_t *)sPayload);
    sPayload += 4;
    sPathname = [NSString stringWithPathnameString:sPayload advanced:&sPayload];

    if ((sPayload - [aMessage payload]) & 1)
    {
        sPayload += 1;
    }

    sName = [NSString stringWithPSUTF8String:sPayload advanced:&sPayload];


    if ((sBitmap & kXAttrNoFollow) != sBitmap)
    {
        [aMessage setReplyResult:kFPBitmapErr withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    if (sMaxReplySize < 0)
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    if (![sName length])
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

    AFPNode *sNode;

    if ([sPathname length])
    {
        sNode = [sDirectory nodeForRelativePath:sPathname];

        if (!sNode)
        {
            [aMessage setReplyResult:kFPObjectNotFound withBlock:nil];
            [mConnection replyMessage:aMessage];
            return;
        }
    }
    else
    {
        sNode = sDirectory;
    }

    void     *sBuffer = sMaxReplySize ? malloc(sMaxReplySize) : NULL;
    int64_t   sLength;
    uint32_t  sResult;

    if ([sVolume supportsExtendedAttributes])
    {
        sResult = [sNode getExtendedAttribute:[sName fileSystemRepresentation] buffer:sBuffer size:sMaxReplySize offset:0 returnedSize:&sLength bitmap:sBitmap];
    }
    else
    {
        sLength = 0;
        sResult = kFPMiscErr;
    }

    if (sResult == kFPNoErr)
    {
        NSMutableData *sReplyBlock = [NSMutableData data];

        [sReplyBlock appendUInt16:sBitmap];
        [sReplyBlock appendUInt32:sLength];

        if (sBuffer)
        {
            [sReplyBlock appendData:[NSData dataWithBytesNoCopy:sBuffer length:sLength freeWhenDone:YES]];
        }

        [aMessage setReplyResult:sResult withBlock:sReplyBlock];
    }
    else
    {
        [aMessage setReplyResult:sResult withBlock:nil];

        if (sBuffer)
        {
            free(sBuffer);
        }
    }

    [mConnection replyMessage:aMessage];
}


- (void)doSetExtAttr:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    NSNumber      *sVolumeID;
    int32_t        sDirectoryID;
    uint16_t       sBitmap;
    NSString      *sPathname;
    NSString      *sName;
    uint32_t       sAttributeDataLength;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sVolumeID = [NSNumber numberWithShort:ntohs(*(int16_t *)sPayload)];
    sPayload += 2;
    sDirectoryID = ntohl(*(int32_t *)sPayload);
    sPayload += 4;
    sBitmap = ntohs(*(uint16_t *)sPayload);
    sPayload += 2;
    sPayload += 8; /* Offset */
    sPathname = [NSString stringWithPathnameString:sPayload advanced:&sPayload];

    if ((sPayload - [aMessage payload]) & 1)
    {
        sPayload += 1;
    }

    sName = [NSString stringWithPSUTF8String:sPayload advanced:&sPayload];
    sAttributeDataLength = ntohl(*(uint32_t *)sPayload);


    if ((sBitmap & (kXAttrNoFollow | kXAttrCreate | kXAttrReplace)) != sBitmap)
    {
        [aMessage setReplyResult:kFPBitmapErr withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    if (![sName length])
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
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

        if (!sNode)
        {
            [aMessage setReplyResult:kFPObjectNotFound withBlock:nil];
            [mConnection replyMessage:aMessage];
            return;
        }
    }
    else
    {
        sNode = sDirectory;
    }

    int64_t  sLength;
    uint32_t sResult;

    if ([sVolume supportsExtendedAttributes])
    {
        sResult = [sNode setExtendedAttribute:[sName fileSystemRepresentation] buffer:sPayload size:sAttributeDataLength offset:0 writtenSize:&sLength bitmap:sBitmap];
    }
    else
    {
        sResult = kFPMiscErr;
    }

    [aMessage setReplyResult:sResult withBlock:nil];
    [mConnection replyMessage:aMessage];
}


- (void)doRemoveExtAttr:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    NSNumber      *sVolumeID;
    int32_t        sDirectoryID;
    uint16_t       sBitmap;
    NSString      *sPathname;
    NSString      *sName;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sVolumeID = [NSNumber numberWithShort:ntohs(*(int16_t *)sPayload)];
    sPayload += 2;
    sDirectoryID = ntohl(*(int32_t *)sPayload);
    sPayload += 4;
    sBitmap = ntohs(*(uint16_t *)sPayload);
    sPayload += 2;
    sPathname = [NSString stringWithPathnameString:sPayload advanced:&sPayload];

    if ((sPayload - [aMessage payload]) & 1)
    {
        sPayload += 1;
    }

    sName = [NSString stringWithPSUTF8String:sPayload advanced:&sPayload];


    if ((sBitmap & kXAttrNoFollow) != sBitmap)
    {
        [aMessage setReplyResult:kFPBitmapErr withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    if (![sName length])
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
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

        if (!sNode)
        {
            [aMessage setReplyResult:kFPObjectNotFound withBlock:nil];
            [mConnection replyMessage:aMessage];
            return;
        }
    }
    else
    {
        sNode = sDirectory;
    }

    uint32_t sResult;

    if ([sVolume supportsExtendedAttributes])
    {
        sResult = [sNode removeExtendedAttribute:[sName fileSystemRepresentation] bitmap:sBitmap];
    }
    else
    {
        sResult = kFPMiscErr;
    }

    [aMessage setReplyResult:sResult withBlock:nil];
    [mConnection replyMessage:aMessage];
}


@end
