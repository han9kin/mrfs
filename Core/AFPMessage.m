/*
 *  AFPMessage.m
 *  MRFS
 *
 *  Created by han9kin on 2011-04-14.
 *
 */

#import "NSString+Additions.h"
#import "AFPProtocol.h"
#import "AFPMessage.h"


// #ifndef LOG_OFF
#define LOG_ERROR        0
#define LOG_NOTSUPPORTED 1
#define LOG_REPLY        0
// #endif


@implementation AFPMessage


- (id)initWithHeader:(DSIHeader *)aHeader payload:(const uint8_t *)aPayload
{
    self = [super init];

    if (self)
    {
        mHeader  = *aHeader;
        mPayload = aPayload;
    }

    return self;
}


- (void)dealloc
{
    free((void *)mPayload);
    [mBlock release];
    [super dealloc];
}


- (NSString *)payloadDescription
{
    NSMutableString *sDesc    = [NSMutableString string];
    const uint8_t   *sPayload = mPayload;

    [sDesc appendFormat:@"\n\tAFP command(%hhu:%@)", *sPayload, AFPCommandNameFromCode(*sPayload)];

    switch (*sPayload)
    {
        case kFPLogin:
            sPayload += 1;
            [sDesc appendFormat:@" APFVersion(%@)", [NSString stringWithPascalString:sPayload advanced:&sPayload]];
            [sDesc appendFormat:@" UAM(%@)", [NSString stringWithPascalString:sPayload advanced:&sPayload]];
            [sDesc appendFormat:@" UserName(%@)", [NSString stringWithPascalString:sPayload advanced:&sPayload]];
            break;

        case kFPLoginCont:
            sPayload += 2;
            [sDesc appendFormat:@" ID(%hu)", ntohs(*(uint16_t *)sPayload)];
            break;

        case kFPLoginExt:
            sPayload += 4;
            [sDesc appendFormat:@" APFVersion(%@)", [NSString stringWithPascalString:sPayload advanced:&sPayload]];
            [sDesc appendFormat:@" UAM(%@)", [NSString stringWithPascalString:sPayload advanced:&sPayload]];
            [sDesc appendFormat:@" UserName(%@)", [NSString stringWithTypedString:sPayload advanced:&sPayload]];
            [sDesc appendFormat:@" Pathname(%@)", [NSString stringWithTypedString:sPayload advanced:&sPayload]];
            break;

        case kFPGetUserInfo:
            sPayload += 1;
            [sDesc appendFormat:@" Flags(%#hhx)", *sPayload];
            sPayload += 1;
            [sDesc appendFormat:@" UserID(%d)", ntohl(*(int32_t *)sPayload)];
            sPayload += 4;
            [sDesc appendFormat:@" Bitmap(%#hx)", ntohs(*(int16_t *)sPayload)];
            break;

        case kFPGetSrvrMsg:
            sPayload += 2;
            [sDesc appendFormat:@" MessageType(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" MessageBitmap(%hd)", ntohs(*(int16_t *)sPayload)];
            break;

        case kFPGetSessionToken:
            sPayload += 2;
            [sDesc appendFormat:@" Type(%d)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" IDLength(%d)", ntohl(*(int32_t *)sPayload)];
            break;

        case kFPOpenVol:
            sPayload += 2;
            [sDesc appendFormat:@" Bitmap(%#hx)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" VolumeName(%@)", [NSString stringWithPascalString:sPayload advanced:&sPayload]];
            break;

        case kFPGetVolParms:
            sPayload += 2;
            [sDesc appendFormat:@" VolumeID(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" Bitmap(%#hx)", ntohs(*(int16_t *)sPayload)];
            break;

        case kFPSetVolParms:
            sPayload += 2;
            [sDesc appendFormat:@" VolumeID(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" Bitmap(%#hx)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" BackupDate(%d)", ntohl(*(int32_t *)sPayload)];
            break;

        case kFPFlush:
            sPayload += 2;
            [sDesc appendFormat:@" VolumeID(%hd)", ntohs(*(int16_t *)sPayload)];
            break;

        case kFPListExtAttrs:
            sPayload += 2;
            [sDesc appendFormat:@" VolumeID(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" DirectoryID(%d)", ntohl(*(int32_t *)sPayload)];
            sPayload += 4;
            [sDesc appendFormat:@" Bitmap(%#hx)", ntohs(*(uint16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" ReqCount(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" StartIndex(%d)", ntohl(*(int32_t *)sPayload)];
            sPayload += 4;
            [sDesc appendFormat:@" MaxReplySize(%d)", ntohl(*(int32_t *)sPayload)];
            sPayload += 4;
            [sDesc appendFormat:@" Pathname(%@)", [NSString stringWithPathnameString:sPayload advanced:&sPayload]];
            break;

        case kFPGetExtAttr:
            sPayload += 2;
            [sDesc appendFormat:@" VolumeID(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" DirectoryID(%d)", ntohl(*(int32_t *)sPayload)];
            sPayload += 4;
            [sDesc appendFormat:@" Bitmap(%#hx)", ntohs(*(uint16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" Offset(%lld)", NSSwapBigLongLongToHost(*(int64_t *)sPayload)];
            sPayload += 8;
            [sDesc appendFormat:@" ReqCount(%lld)", NSSwapBigLongLongToHost(*(int64_t *)sPayload)];
            sPayload += 8;
            [sDesc appendFormat:@" MaxReplySize(%d)", ntohl(*(int32_t *)sPayload)];
            sPayload += 4;
            [sDesc appendFormat:@" Pathname(%@)", [NSString stringWithPathnameString:sPayload advanced:&sPayload]];
            if ((sPayload - mPayload) & 1)
            {
                sPayload += 1;
            }
            [sDesc appendFormat:@" Name(%@)", [NSString stringWithPSUTF8String:sPayload advanced:&sPayload]];
            break;

        case kFPSetExtAttr:
            sPayload += 2;
            [sDesc appendFormat:@" VolumeID(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" DirectoryID(%d)", ntohl(*(int32_t *)sPayload)];
            sPayload += 4;
            [sDesc appendFormat:@" Bitmap(%#hx)", ntohs(*(uint16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" Offset(%lld)", NSSwapBigLongLongToHost(*(int64_t *)sPayload)];
            sPayload += 8;
            [sDesc appendFormat:@" Pathname(%@)", [NSString stringWithPathnameString:sPayload advanced:&sPayload]];
            if ((sPayload - mPayload) & 1)
            {
                sPayload += 1;
            }
            [sDesc appendFormat:@" Name(%@)", [NSString stringWithPSUTF8String:sPayload advanced:&sPayload]];
            [sDesc appendFormat:@" AttributeDataLength(%u)", ntohl(*(uint32_t *)sPayload)];
            break;

        case kFPRemoveExtAttr:
            sPayload += 2;
            [sDesc appendFormat:@" VolumeID(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" DirectoryID(%d)", ntohl(*(int32_t *)sPayload)];
            sPayload += 4;
            [sDesc appendFormat:@" Bitmap(%#hx)", ntohs(*(uint16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" Pathname(%@)", [NSString stringWithPathnameString:sPayload advanced:&sPayload]];
            if ((sPayload - mPayload) & 1)
            {
                sPayload += 1;
            }
            [sDesc appendFormat:@" Name(%@)", [NSString stringWithPSUTF8String:sPayload advanced:&sPayload]];
            break;

        case kFPGetFileDirParms:
            sPayload += 2;
            [sDesc appendFormat:@" VolumeID(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" DirectoryID(%d)", ntohl(*(int32_t *)sPayload)];
            sPayload += 4;
            [sDesc appendFormat:@" FileBitmap(%#hx)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" DirectoryBitmap(%#hx)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" Pathname(%@)", [NSString stringWithPathnameString:sPayload advanced:&sPayload]];
            break;

        case kFPSetFileDirParms:
            sPayload += 2;
            [sDesc appendFormat:@" VolumeID(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" DirectoryID(%d)", ntohl(*(int32_t *)sPayload)];
            sPayload += 4;
            [sDesc appendFormat:@" Bitmap(%#hx)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" Pathname(%@)", [NSString stringWithPathnameString:sPayload advanced:&sPayload]];
            break;

        case kFPSetDirParms:
            sPayload += 2;
            [sDesc appendFormat:@" VolumeID(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" DirectoryID(%d)", ntohl(*(int32_t *)sPayload)];
            sPayload += 4;
            [sDesc appendFormat:@" Bitmap(%#hx)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" Pathname(%@)", [NSString stringWithPathnameString:sPayload advanced:&sPayload]];
            break;

        case kFPDelete:
            sPayload += 2;
            [sDesc appendFormat:@" VolumeID(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" DirectoryID(%d)", ntohl(*(int32_t *)sPayload)];
            sPayload += 4;
            [sDesc appendFormat:@" Pathname(%@)", [NSString stringWithPathnameString:sPayload advanced:&sPayload]];
            break;

        case kFPRename:
            sPayload += 2;
            [sDesc appendFormat:@" VolumeID(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" DirectoryID(%d)", ntohl(*(int32_t *)sPayload)];
            sPayload += 4;
            [sDesc appendFormat:@" Pathname(%@)", [NSString stringWithPathnameString:sPayload advanced:&sPayload]];
            [sDesc appendFormat:@" NewName(%@)", [NSString stringWithPathnameString:sPayload advanced:&sPayload]];
            break;

        case kFPMoveAndRename:
            sPayload += 2;
            [sDesc appendFormat:@" VolumeID(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" SourceDirectoryID(%d)", ntohl(*(int32_t *)sPayload)];
            sPayload += 4;
            [sDesc appendFormat:@" DestDirectoryID(%d)", ntohl(*(int32_t *)sPayload)];
            sPayload += 4;
            [sDesc appendFormat:@" SourcePathname(%@)", [NSString stringWithPathnameString:sPayload advanced:&sPayload]];
            [sDesc appendFormat:@" DestPathname(%@)", [NSString stringWithPathnameString:sPayload advanced:&sPayload]];
            [sDesc appendFormat:@" NewName(%@)", [NSString stringWithPathnameString:sPayload advanced:&sPayload]];
            break;

        case kFPEnumerateExt:
            sPayload += 2;
            [sDesc appendFormat:@" VolumeID(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" DirectoryID(%d)", ntohl(*(int32_t *)sPayload)];
            sPayload += 4;
            [sDesc appendFormat:@" FileBitmap(%#hx)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" DirectoryBitmap(%#hx)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" ReqCount(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" StartIndex(%d)", ntohl(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" MaxReplySize(%d)", ntohl(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" Pathname(%@)", [NSString stringWithPathnameString:sPayload advanced:&sPayload]];
            break;

        case kFPEnumerateExt2:
            sPayload += 2;
            [sDesc appendFormat:@" VolumeID(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" DirectoryID(%d)", ntohl(*(int32_t *)sPayload)];
            sPayload += 4;
            [sDesc appendFormat:@" FileBitmap(%#hx)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" DirectoryBitmap(%#hx)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" ReqCount(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" StartIndex(%d)", ntohl(*(int32_t *)sPayload)];
            sPayload += 4;
            [sDesc appendFormat:@" MaxReplySize(%d)", ntohl(*(int32_t *)sPayload)];
            sPayload += 4;
            [sDesc appendFormat:@" Pathname(%@)", [NSString stringWithPathnameString:sPayload advanced:&sPayload]];
            break;

        case kFPCreateDir:
            sPayload += 2;
            [sDesc appendFormat:@" VolumeID(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" DirectoryID(%d)", ntohl(*(int32_t *)sPayload)];
            sPayload += 4;
            [sDesc appendFormat:@" Pathname(%@)", [NSString stringWithPathnameString:sPayload advanced:&sPayload]];
            break;

        case kFPSetFileParms:
            sPayload += 2;
            [sDesc appendFormat:@" VolumeID(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" DirectoryID(%d)", ntohl(*(int32_t *)sPayload)];
            sPayload += 4;
            [sDesc appendFormat:@" Bitmap(%#hx)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" Pathname(%@)", [NSString stringWithPathnameString:sPayload advanced:&sPayload]];
            break;

        case kFPCreateFile:
            sPayload += 1;
            [sDesc appendFormat:@" Flag(%hhx)", *sPayload];
            sPayload += 1;
            [sDesc appendFormat:@" VolumeID(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" DirectoryID(%d)", ntohl(*(int32_t *)sPayload)];
            sPayload += 4;
            [sDesc appendFormat:@" Pathname(%@)", [NSString stringWithPathnameString:sPayload advanced:&sPayload]];
            break;

        case kFPOpenFork:
            sPayload += 1;
            [sDesc appendFormat:@" Flag(%#hhx)", *sPayload];
            sPayload += 1;
            [sDesc appendFormat:@" VolumeID(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" DirectoryID(%d)", ntohl(*(int32_t *)sPayload)];
            sPayload += 4;
            [sDesc appendFormat:@" Bitmap(%#hx)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" AccessMode(%#hx)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" Pathname(%@)", [NSString stringWithPathnameString:sPayload advanced:&sPayload]];
            break;

        case kFPCloseFork:
            sPayload += 2;
            [sDesc appendFormat:@" OForkRefNum(%hd)", ntohs(*(int16_t *)sPayload)];
            break;

        case kFPGetForkParms:
            sPayload += 2;
            [sDesc appendFormat:@" OForkRefNum(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" Bitmap(%#hx)", ntohs(*(int16_t *)sPayload)];
            break;

        case kFPSetForkParms:
            sPayload += 2;
            [sDesc appendFormat:@" OForkRefNum(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" Bitmap(%#hx)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            if (ntohs(*(int16_t *)sPayload) & (kFPExtDataForkLenBit | kFPExtRsrcForkLenBit))
            {
                [sDesc appendFormat:@" ForkLen(%lld)", NSSwapBigLongLongToHost(*(int64_t *)sPayload)];
            }
            else if (ntohs(*(int16_t *)sPayload) & (kFPDataForkLenBit | kFPRsrcForkLenBit))
            {
                [sDesc appendFormat:@" ForkLen(%d)", ntohl(*(int32_t *)sPayload)];
            }
            break;

        case kFPReadExt:
            sPayload += 2;
            [sDesc appendFormat:@" OForkRefNum(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" Offset(%lld)", NSSwapBigLongLongToHost(*(int64_t *)sPayload)];
            sPayload += 8;
            [sDesc appendFormat:@" ReqCount(%lld)", NSSwapBigLongLongToHost(*(int64_t *)sPayload)];
            break;

        case kFPWriteExt:
            sPayload += 1;
            [sDesc appendFormat:@" Flag(%#hhx)", *sPayload];
            sPayload += 1;
            [sDesc appendFormat:@" OForkRefNum(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" Offset(%lld)", NSSwapBigLongLongToHost(*(int64_t *)sPayload)];
            sPayload += 8;
            [sDesc appendFormat:@" ReqCount(%lld)", NSSwapBigLongLongToHost(*(int64_t *)sPayload)];
            break;

        case kFPByteRangeLockExt:
            sPayload += 1;
            [sDesc appendFormat:@" Flags(%#hhx)", *sPayload];
            sPayload += 1;
            [sDesc appendFormat:@" OForkRefNum(%hd)", ntohs(*(int16_t *)sPayload)];
            sPayload += 2;
            [sDesc appendFormat:@" Offset(%lld)", NSSwapBigLongLongToHost(*(int64_t *)sPayload)];
            sPayload += 8;
            [sDesc appendFormat:@" Length(%lld)", NSSwapBigLongLongToHost(*(int64_t *)sPayload)];
            break;

        case kFPFlushFork:
            sPayload += 2;
            [sDesc appendFormat:@" OForkRefNum(%hd)", ntohs(*(int16_t *)sPayload)];
            break;
    }

    return sDesc;
}


- (NSString *)resultDescription
{
    if (mHasReply)
    {
        return [NSString stringWithFormat:@"errorCode(%@)", AFPErrorNameFromCode(mResult)];
    }
    else
    {
        if ([self isRequest])
        {
            return [NSString stringWithFormat:@"writeOffset(%u)", mHeader.writeOffset];
        }
        else
        {
            return [NSString stringWithFormat:@"errorCode(%@)", AFPErrorNameFromCode(mHeader.errorCode)];
        }
    }
}


- (NSString *)description
{
    NSString *sDesc1;
    NSString *sDesc2;

    sDesc1 = [NSString stringWithFormat:@"\tDSI %@ command(%hhu:%@) requestID(%hu) %@ totalDataLength(%lu) reserved(%u)",
                       ((mHasReply || ![self isRequest]) ? @"REPLY" : @"REQUEST"),
                       mHeader.command,
                       DSICommandNameFromCode(mHeader.command),
                       mHeader.requestID,
                       [self resultDescription],
                       (unsigned long)(mHasReply ? [mBlock length] : mHeader.totalDataLength),
                       mHeader.reserved];

    if (mHeader.command == kDSIAttention)
    {
        sDesc2 = @"";
    }
    else if (mHeader.command == kDSIOpenSession)
    {
        const uint8_t *sPayload = mBlock ? [mBlock bytes] : mPayload;
        NSString      *sData;

        switch (*(sPayload + 1))
        {
            case 1:
                sData = [NSString stringWithFormat:@"%hhu", *(sPayload + 2)];
                break;
            case 2:
                sData = [NSString stringWithFormat:@"%hu", ntohs(*(uint16_t *)(sPayload + 2))];
                break;
            case 4:
                sData = [NSString stringWithFormat:@"%u", ntohl(*(uint32_t *)(sPayload + 2))];
                break;
            default:
                sData = @"?";
                break;
        }

        sDesc2 = [NSString stringWithFormat:@"\n\tDSI payload option type(%hhu) length(%hhu) data(%@)", *sPayload, *(sPayload + 1), sData];
    }
    else if (!mHasReply && mPayload)
    {
        sDesc2 = [self payloadDescription];
    }
    else
    {
        sDesc2 = @"";
    }

    return [NSString stringWithFormat:@"<%@: %p>\n%@%@", NSStringFromClass([self class]), self, sDesc1, sDesc2];
}


- (BOOL)isRequest
{
    return mHeader.flags ? NO : YES;
}


- (uint8_t)dsiCommand
{
    return mHeader.command;
}


- (uint8_t)afpCommand
{
    if (mPayload)
    {
        return *mPayload;
    }
    else
    {
        return 0;
    }
}


- (uint32_t)payloadLength
{
    return mHeader.totalDataLength;
}


- (const uint8_t *)payload
{
    return mPayload;
}


- (void)setRequestBlock:(NSData *)aData
{
    mBlock                  = [aData retain];
    mHeader.flags           = 0;
    mHeader.writeOffset     = 0;
    mHeader.totalDataLength = [aData length];
    mHeader.reserved        = 0;
}


- (void)setReplyResult:(uint32_t)aResult withBlock:(NSData *)aData
{
#if LOG_REPLY
    NSLog(@"Request: %@", self);
#elif LOG_ERROR
    if (aResult != kFPNoErr)
    {
        NSLog(@"Error(%@): %@", AFPErrorNameFromCode(aResult), self);
    }
#elif LOG_NOTSUPPORTED
    if (aResult == kFPCallNotSupported)
    {
        NSLog(@"CallNotSupported: %@", self);
    }
#endif

    mHasReply = YES;
    mResult   = aResult;
    mBlock    = [aData retain];

#if LOG_REPLY
    NSLog(@"Reply: %@", self);
#endif
}


#pragma mark -
#pragma mark Writing to the Stream


- (BOOL)write:(const uint8_t *)aBuffer length:(NSUInteger)aLength on:(NSOutputStream *)aOutputStream
{
    NSInteger sLength = aLength;

    while (sLength)
    {
        NSInteger sResult = [aOutputStream write:(aBuffer + (aLength - sLength)) maxLength:sLength];

        if (sResult < 0)
        {
            NSLog(@"writeReplyOnStream Error: %@", [aOutputStream streamError]);

            return NO;
        }
        else
        {
            sLength -= sResult;
        }
    }

    return YES;
}


- (BOOL)writeOnStream:(NSOutputStream *)aOutputStream
{
    DSIHeader sHeader;

    if (mHasReply)
    {
        DSIHeaderMakeReply(&sHeader, &mHeader, mResult, [mBlock length]);
    }
    else
    {
        DSIHeaderMakeRequest(&sHeader, &mHeader);
    }

    if (![self write:(const uint8_t *)&sHeader length:sizeof(sHeader) on:aOutputStream])
    {
        return NO;
    }

    if ([mBlock length])
    {
        if (![self write:[mBlock bytes] length:[mBlock length] on:aOutputStream])
        {
            return NO;
        }
    }

    return YES;
}


@end
