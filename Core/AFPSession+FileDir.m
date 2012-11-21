/*
 *  AFPSession+FileDir.m
 *  MRFS
 *
 *  Created by han9kin on 2011-05-02.
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


#ifndef LOG_OFF
#define LOG_PARAMETERS 1
#endif


static int16_t gAllCommonBits    = 0;
static int16_t gAllFileBits      = 0;
static int16_t gAllDirectoryBits = 0;


@implementation AFPSession (FileDir)


+ (void)load
{
    if (!gAllCommonBits)
    {
        gAllCommonBits =
            kFPAttributeBit |
            kFPParentDirIDBit |
            kFPCreateDateBit |
            kFPModDateBit |
            kFPBackupDateBit |
            kFPFinderInfoBit |
            // kFPLongNameBit |
            // kFPShortNameBit |
            kFPNodeIDBit |
            kFPUTF8NameBit |
            kFPUnixPrivsBit;
    }

    if (!gAllFileBits)
    {
        gAllFileBits =
            kFPAttributeBit |
            kFPParentDirIDBit |
            kFPCreateDateBit |
            kFPModDateBit |
            kFPBackupDateBit |
            kFPFinderInfoBit |
            // kFPLongNameBit |
            // kFPShortNameBit |
            kFPNodeIDBit |
            kFPDataForkLenBit |
            kFPRsrcForkLenBit |
            kFPExtDataForkLenBit |
            kFPUTF8NameBit |
            kFPExtRsrcForkLenBit |
            kFPUnixPrivsBit;
    }

    if (!gAllDirectoryBits)
    {
        gAllDirectoryBits =
            kFPAttributeBit |
            kFPParentDirIDBit |
            kFPCreateDateBit |
            kFPModDateBit |
            kFPBackupDateBit |
            kFPFinderInfoBit |
            // kFPLongNameBit |
            // kFPShortNameBit |
            kFPNodeIDBit |
            kFPOffspringCountBit |
            kFPOwnerIDBit |
            kFPGroupIDBit |
            kFPAccessRightsBit |
            kFPUTF8NameBit |
            kFPUnixPrivsBit;
    }
}


- (int16_t)allCommonBits
{
    return gAllCommonBits;
}


- (int16_t)allFileBits
{
    return gAllFileBits;
}


- (int16_t)allDirectoryBits
{
    return gAllDirectoryBits;
}


- (void)fillParameters:(int16_t)aBitmap on:(NSMutableData *)aReplyBlock withFile:(AFPFile *)aFile
{
    NSMutableData *sVariableBlock   = [NSMutableData data];
    uint16_t       sBaseOffset      = [aReplyBlock length];
    uint16_t       sFixedOffset     = 0;
    uint16_t       sVariableOffset  = 0;
    int16_t        sLongNameLoc     = -1;
    int16_t        sLongNameOffset  = -1;
    int16_t        sShortNameLoc    = -1;
    int16_t        sShortNameOffset = -1;
    int16_t        sUTF8NameLoc     = -1;
    int16_t        sUTF8NameOffset  = -1;

#if LOG_PARAMETERS
    NSLog(@"  path: %@", [aFile path]);
#endif


    if (aBitmap & kFPAttributeBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> File:kFPAttributeBit = %#hx", [aFile attribute]);
#endif
        sFixedOffset += [aReplyBlock appendUInt16:[aFile attribute]];
    }

    if (aBitmap & kFPParentDirIDBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> File:kFPParentDirIDBit = %u", [aFile parentID]);
#endif
        sFixedOffset += [aReplyBlock appendUInt32:[aFile parentID]];
    }

    if (aBitmap & kFPCreateDateBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> File:kFPCreateDateBit = %d", [aFile creationDate]);
#endif
        sFixedOffset += [aReplyBlock appendUInt32:[aFile creationDate]];
    }

    if (aBitmap & kFPModDateBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> File:kFPModDateBit = %d", [aFile modificationDate]);
#endif
        sFixedOffset += [aReplyBlock appendUInt32:[aFile modificationDate]];
    }

    if (aBitmap & kFPBackupDateBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> File:kFPBackupDateBit = %d", [aFile backupDate]);
#endif
        sFixedOffset += [aReplyBlock appendUInt32:[aFile backupDate]];
    }

    if (aBitmap & kFPFinderInfoBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> File:kFPFinderInfoBit = %@", [aFile finderInfo]);
#endif
        [aReplyBlock appendData:[aFile finderInfo]];
        sFixedOffset += 32;
    }

    if (aBitmap & kFPLongNameBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> File:kFPLongNameBit = %@", [aFile longName]);
#endif
        sLongNameLoc     = sVariableOffset;
        sLongNameOffset  = sFixedOffset;
        sFixedOffset    += [aReplyBlock appendUInt16:0];
        sVariableOffset += [sVariableBlock appendPascalString:[aFile longName] maxLength:32];
    }

    if (aBitmap & kFPShortNameBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> File:kFPShortNameBit = %@", [aFile shortName]);
#endif
        sShortNameLoc     = sVariableOffset;
        sShortNameOffset  = sFixedOffset;
        sFixedOffset     += [aReplyBlock appendUInt16:0];
        sVariableOffset  += [sVariableBlock appendPascalString:[aFile shortName] maxLength:12];
    }

    if (aBitmap & kFPNodeIDBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> File:kFPNodeIDBit = %u", [aFile nodeID]);
#endif
        sFixedOffset += [aReplyBlock appendUInt32:[aFile nodeID]];
    }

    if (aBitmap & kFPDataForkLenBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> File:kFPDataForkLenBit = %u", [aFile dataForkLen]);
#endif
        sFixedOffset += [aReplyBlock appendUInt32:[aFile dataForkLen]];
    }

    if (aBitmap & kFPRsrcForkLenBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> File:kFPRsrcForkLenBit = %u", [aFile rsrcForkLen]);
#endif
        sFixedOffset += [aReplyBlock appendUInt32:[aFile rsrcForkLen]];
    }

    if (aBitmap & kFPExtDataForkLenBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> File:kFPExtDataForkLenBit = %llu", [aFile dataForkLenExt]);
#endif
        sFixedOffset += [aReplyBlock appendUInt64:[aFile dataForkLenExt]];
    }

    if (aBitmap & kFPUTF8NameBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> File:kFPUTF8NameBit = %@", [aFile nodeName]);
#endif
        sUTF8NameLoc     = sVariableOffset;
        sUTF8NameOffset  = sFixedOffset;
        sFixedOffset    += [aReplyBlock appendUInt16:0];
        sFixedOffset    += [aReplyBlock appendUInt32:0]; /* Pad */
        sVariableOffset += [sVariableBlock appendHintedString:[aFile nodeName]];
    }

    if (aBitmap & kFPExtRsrcForkLenBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> File:kFPExtRsrcForkLenBit = %llu", [aFile rsrcForkLenExt]);
#endif
        sFixedOffset += [aReplyBlock appendUInt64:[aFile rsrcForkLenExt]];
    }

    if (aBitmap & kFPUnixPrivsBit)
    {
        struct FPUnixPrivs sUnixPrivs;

        [aFile getUnixPrivileges:&sUnixPrivs];

#if LOG_PARAMETERS
        NSLog(@"  -> File:kFPUnixPrivsBit = %d, %d, %#o, %#x", sUnixPrivs.uid, sUnixPrivs.gid, sUnixPrivs.permissions, sUnixPrivs.ua_permissions);
#endif
        sFixedOffset += [aReplyBlock appendUInt32:sUnixPrivs.uid];
        sFixedOffset += [aReplyBlock appendUInt32:sUnixPrivs.gid];
        sFixedOffset += [aReplyBlock appendUInt32:sUnixPrivs.permissions];
        sFixedOffset += [aReplyBlock appendUInt32:sUnixPrivs.ua_permissions];
    }


    if (sLongNameLoc >= 0)
    {
        sLongNameLoc = htons(sLongNameLoc + sFixedOffset);
        [aReplyBlock replaceBytesInRange:NSMakeRange(sBaseOffset + sLongNameOffset, 2) withBytes:&sLongNameLoc length:2];
    }

    if (sShortNameLoc >= 0)
    {
        sShortNameLoc = htons(sShortNameLoc + sFixedOffset);
        [aReplyBlock replaceBytesInRange:NSMakeRange(sBaseOffset + sShortNameOffset, 2) withBytes:&sShortNameLoc length:2];
    }

    if (sUTF8NameLoc >= 0)
    {
        sUTF8NameLoc += htons(sUTF8NameLoc + sFixedOffset);
        [aReplyBlock replaceBytesInRange:NSMakeRange(sBaseOffset + sUTF8NameOffset, 2) withBytes:&sUTF8NameLoc length:2];
    }

    [aReplyBlock appendData:sVariableBlock];

    if (([aReplyBlock length] - sBaseOffset) & 1)
    {
        [aReplyBlock appendUInt8:0];
    }
}


- (void)fillParameters:(int16_t)aBitmap on:(NSMutableData *)aReplyBlock withDirectory:(AFPDirectory *)aDirectory
{
    NSMutableData *sVariableBlock   = [NSMutableData data];
    uint16_t       sBaseOffset      = [aReplyBlock length];
    uint16_t       sFixedOffset     = 0;
    uint16_t       sVariableOffset  = 0;
    int16_t        sLongNameLoc     = -1;
    int16_t        sLongNameOffset  = -1;
    int16_t        sShortNameLoc    = -1;
    int16_t        sShortNameOffset = -1;
    int16_t        sUTF8NameLoc     = -1;
    int16_t        sUTF8NameOffset  = -1;

#if LOG_PARAMETERS
    NSLog(@"  path: %@", [aDirectory path]);
#endif


    if (aBitmap & kFPAttributeBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> Directory:kFPAttributeBit = %#hx", [aDirectory attribute]);
#endif
        sFixedOffset += [aReplyBlock appendUInt16:[aDirectory attribute]];
    }

    if (aBitmap & kFPParentDirIDBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> Directory:kFPParentDirIDBit = %u", [aDirectory parentID]);
#endif
        sFixedOffset += [aReplyBlock appendUInt32:[aDirectory parentID]];
    }

    if (aBitmap & kFPCreateDateBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> Directory:kFPCreateDateBit = %d", [aDirectory creationDate]);
#endif
        sFixedOffset += [aReplyBlock appendUInt32:[aDirectory creationDate]];
    }

    if (aBitmap & kFPModDateBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> Directory:kFPModDateBit = %d", [aDirectory modificationDate]);
#endif
        sFixedOffset += [aReplyBlock appendUInt32:[aDirectory modificationDate]];
    }

    if (aBitmap & kFPBackupDateBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> Directory:kFPBackupDateBit = %d", [aDirectory backupDate]);
#endif
        sFixedOffset += [aReplyBlock appendUInt32:[aDirectory backupDate]];
    }

    if (aBitmap & kFPFinderInfoBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> Directory:kFPFinderInfoBit = %@", [aDirectory finderInfo]);
#endif
        [aReplyBlock appendData:[aDirectory finderInfo]];
        sFixedOffset += 32;
    }

    if (aBitmap & kFPLongNameBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> Directory:kFPLongNameBit = %@", [aDirectory longName]);
#endif
        sLongNameLoc     = sVariableOffset;
        sLongNameOffset  = sFixedOffset;
        sFixedOffset    += [aReplyBlock appendUInt16:0];
        sVariableOffset += [sVariableBlock appendPascalString:[aDirectory longName] maxLength:32];
    }

    if (aBitmap & kFPShortNameBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> Directory:kFPShortNameBit = %@", [aDirectory shortName]);
#endif
        sShortNameLoc     = sVariableOffset;
        sShortNameOffset  = sFixedOffset;
        sFixedOffset     += [aReplyBlock appendUInt16:0];
        sVariableOffset  += [sVariableBlock appendPascalString:[aDirectory shortName] maxLength:12];
    }

    if (aBitmap & kFPNodeIDBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> Directory:kFPNodeIDBit = %u", [aDirectory nodeID]);
#endif
        sFixedOffset += [aReplyBlock appendUInt32:[aDirectory nodeID]];
    }

    if (aBitmap & kFPOffspringCountBit)
    {
        uint32_t sOffspringCount = [aDirectory offspringCount];

        if (sOffspringCount > UINT16_MAX)
        {
            sOffspringCount = UINT16_MAX;
        }

#if LOG_PARAMETERS
        NSLog(@"  -> Directory:kFPOffspringCountBit = %u", sOffspringCount);
#endif
        sFixedOffset += [aReplyBlock appendUInt16:sOffspringCount];
    }

    if (aBitmap & kFPOwnerIDBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> Directory:kFPOwnerIDBit = %u", [aDirectory ownerID]);
#endif
        sFixedOffset += [aReplyBlock appendUInt32:[aDirectory ownerID]];
    }

    if (aBitmap & kFPGroupIDBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> Directory:kFPGroupIDBit = %u", [aDirectory groupID]);
#endif
        sFixedOffset += [aReplyBlock appendUInt32:[aDirectory groupID]];
    }

    if (aBitmap & kFPAccessRightsBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> Directory:kFPAccessRightsBit = %#x", [aDirectory accessRights]);
#endif
        sFixedOffset += [aReplyBlock appendUInt32:[aDirectory accessRights]];
    }

    if (aBitmap & kFPUTF8NameBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  -> Directory:kFPUTF8NameBit = %@", [aDirectory nodeName]);
#endif
        sUTF8NameLoc     = sVariableOffset;
        sUTF8NameOffset  = sFixedOffset;
        sFixedOffset    += [aReplyBlock appendUInt16:0];
        sFixedOffset    += [aReplyBlock appendUInt32:0]; /* Pad */
        sVariableOffset += [sVariableBlock appendHintedString:[aDirectory nodeName]];
    }

    if (aBitmap & kFPUnixPrivsBit)
    {
        struct FPUnixPrivs sUnixPrivs;

        [aDirectory getUnixPrivileges:&sUnixPrivs];

#if LOG_PARAMETERS
        NSLog(@"  -> Directory:kFPUnixPrivsBit = %d, %d, %#o, %#x", sUnixPrivs.uid, sUnixPrivs.gid, sUnixPrivs.permissions, sUnixPrivs.ua_permissions);
#endif
        sFixedOffset += [aReplyBlock appendUInt32:sUnixPrivs.uid];
        sFixedOffset += [aReplyBlock appendUInt32:sUnixPrivs.gid];
        sFixedOffset += [aReplyBlock appendUInt32:sUnixPrivs.permissions];
        sFixedOffset += [aReplyBlock appendUInt32:sUnixPrivs.ua_permissions];
    }


    if (sLongNameLoc >= 0)
    {
        sLongNameLoc = htons(sLongNameLoc + sFixedOffset);
        [aReplyBlock replaceBytesInRange:NSMakeRange(sBaseOffset + sLongNameOffset, 2) withBytes:&sLongNameLoc length:2];
    }

    if (sShortNameLoc >= 0)
    {
        sShortNameLoc = htons(sShortNameLoc + sFixedOffset);
        [aReplyBlock replaceBytesInRange:NSMakeRange(sBaseOffset + sShortNameOffset, 2) withBytes:&sShortNameLoc length:2];
    }

    if (sUTF8NameLoc >= 0)
    {
        sUTF8NameLoc += htons(sUTF8NameLoc + sFixedOffset);
        [aReplyBlock replaceBytesInRange:NSMakeRange(sBaseOffset + sUTF8NameOffset, 2) withBytes:&sUTF8NameLoc length:2];
    }

    [aReplyBlock appendData:sVariableBlock];

    if (([aReplyBlock length] - sBaseOffset) & 1)
    {
        [aReplyBlock appendUInt8:0];
    }
}


- (void)doGetFileDirParms:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    NSNumber      *sVolumeID;
    int32_t        sDirectoryID;
    int16_t        sFileBitmap;
    int16_t        sDirectoryBitmap;
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
    sPathname = [NSString stringWithPathnameString:sPayload advanced:&sPayload];

#if LOG_PARAMETERS
    NSLog(@"  request block: %@", [NSData dataWithBytes:[aMessage payload] length:[aMessage payloadLength]]);
    NSLog(@"  VolumeID = %@", sVolumeID);
    NSLog(@"  DirectoryID = %d", sDirectoryID);
    NSLog(@"  FileBitmap = %#hx", sFileBitmap);
    NSLog(@"  DirectoryBitmap = %#hx", sDirectoryBitmap);
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

    AFPVolume *sVolume = [mVolumesByID objectForKey:sVolumeID];

    if (!sVolume)
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    AFPDirectory *sDirectory = [sVolume directoryForID:sDirectoryID];

    if (sDirectory)
    {
        sDirectory = (AFPDirectory *)[sDirectory validateNode];

        if (![sDirectory isDirectory])
        {
            [sVolume updateModificationDate];
            [mConnection sendAttention:kMsgNotifyVolumeChanged];
            sDirectory = nil;
        }
    }

    if (!sDirectory)
    {
        [aMessage setReplyResult:kFPDirNotFound withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    AFPNode *sNode;

    if ([sPathname length])
    {
        sNode = [[sDirectory nodeForRelativePath:sPathname] validateNode];

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

    NSMutableData *sReplyBlock = [NSMutableData data];

    [sReplyBlock appendUInt16:sFileBitmap];
    [sReplyBlock appendUInt16:sDirectoryBitmap];

    if ([sNode isDirectory])
    {
        [sReplyBlock appendUInt16:0x8000];
        [self fillParameters:sDirectoryBitmap on:sReplyBlock withDirectory:(AFPDirectory *)sNode];
    }
    else
    {
        [sReplyBlock appendUInt16:0x0000];
        [self fillParameters:sFileBitmap on:sReplyBlock withFile:(AFPFile *)sNode];
    }

#if LOG_PARAMETERS
    NSLog(@"  reply block: %@", sReplyBlock);
#endif

    [aMessage setReplyResult:kFPNoErr withBlock:sReplyBlock];
    [mConnection replyMessage:aMessage];
}


- (void)doSetFileDirParms:(AFPMessage *)aMessage
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

    if (!sBitmap || ((sBitmap & [self allCommonBits]) != sBitmap))
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

    uint32_t sResult = [sNode setParameters:sPayload bitmap:sBitmap];

    [aMessage setReplyResult:sResult withBlock:nil];
    [mConnection replyMessage:aMessage];
}


- (void)doDelete:(AFPMessage *)aMessage
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

    uint32_t sResult = [sNode deleteNode];

    [aMessage setReplyResult:sResult withBlock:nil];
    [mConnection replyMessage:aMessage];
}


- (void)doRename:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    NSNumber      *sVolumeID;
    int32_t        sDirectoryID;
    NSString      *sPathname;
    NSString      *sNewName;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sVolumeID = [NSNumber numberWithShort:ntohs(*(int16_t *)sPayload)];
    sPayload += 2;
    sDirectoryID = ntohl(*(int32_t *)sPayload);
    sPayload += 4;
    sPathname = [NSString stringWithPathnameString:sPayload advanced:&sPayload];
    sNewName  = [NSString stringWithPathnameString:sPayload advanced:&sPayload];

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

    if (![sPathname length] || ![sNewName length])
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

    AFPNode *sNode = [sDirectory nodeForRelativePath:sPathname];

    if (!sNode)
    {
        [aMessage setReplyResult:kFPObjectNotFound withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    if ([sNewName isEqualToString:[sNode nodeName]])
    {
        [aMessage setReplyResult:kFPCantRename withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    uint32_t sResult = [sNode moveNodeToDirectory:nil withNewName:sNewName];

    [aMessage setReplyResult:sResult withBlock:nil];
    [mConnection replyMessage:aMessage];
}


- (void)doMoveAndRename:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    NSNumber      *sVolumeID;
    int32_t        sSourceDirectoryID;
    int32_t        sDestDirectoryID;
    NSString      *sSourcePathname;
    NSString      *sDestPathname;
    NSString      *sNewName;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sVolumeID = [NSNumber numberWithShort:ntohs(*(int16_t *)sPayload)];
    sPayload += 2;
    sSourceDirectoryID = ntohl(*(int32_t *)sPayload);
    sPayload += 4;
    sDestDirectoryID = ntohl(*(int32_t *)sPayload);
    sPayload += 4;
    sSourcePathname = [NSString stringWithPathnameString:sPayload advanced:&sPayload];
    sDestPathname   = [NSString stringWithPathnameString:sPayload advanced:&sPayload];
    sNewName        = [NSString stringWithPathnameString:sPayload advanced:&sPayload];

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

    AFPDirectory *sSourceDirectory = [sVolume directoryForID:sSourceDirectoryID];

    if (!sSourceDirectory)
    {
        [aMessage setReplyResult:kFPDirNotFound withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    AFPNode *sSourceNode;

    if ([sSourcePathname length])
    {
        sSourceNode = [sSourceDirectory nodeForRelativePath:sSourcePathname];

        if (!sSourceNode)
        {
            [aMessage setReplyResult:kFPObjectNotFound withBlock:nil];
            [mConnection replyMessage:aMessage];
            return;
        }
    }
    else
    {
        sSourceNode = sSourceDirectory;
    }

    AFPDirectory *sDestDirectory = [sVolume directoryForID:sDestDirectoryID];

    if (!sDestDirectory)
    {
        [aMessage setReplyResult:kFPDirNotFound withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    if ([sDestPathname length])
    {
        AFPNode *sNode = [sDestDirectory nodeForRelativePath:sDestPathname];

        if (sNode)
        {
            if ([sNode isDirectory])
            {
                sDestDirectory = (AFPDirectory *)sNode;
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

    if ([sNewName length])
    {
        if ([[sSourceNode nodeName] isEqualToString:sNewName])
        {
            sNewName = nil;
        }
    }
    else
    {
        sNewName = nil;
    }

    if ((sDestDirectory == [sSourceNode parent]) && !sNewName)
    {
        [aMessage setReplyResult:kFPCantMove withBlock:nil];
        [mConnection replyMessage:aMessage];
        return;
    }

    uint32_t sResult = [sSourceNode moveNodeToDirectory:sDestDirectory withNewName:sNewName];

    [aMessage setReplyResult:sResult withBlock:nil];
    [mConnection replyMessage:aMessage];
}


@end
