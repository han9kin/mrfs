/*
 *  AFPFile.m
 *  MRFS
 *
 *  Created by han9kin on 2011-04-22.
 *
 */

#import <sys/xattr.h>
#import "AFPProtocol.h"
#import "AFPVolume.h"
#import "AFPFile.h"


#ifndef LOG_OFF
#define LOG_PARAMETERS 1
#endif


@interface AFPFile (SymbolicLink)
@end


@implementation AFPFile (SymbolicLink)


- (uint32_t)makeSymbolicLink
{
    id<MRFSOperations>  sHandler = [self operationHandler];
    MRFSFileStat       *sFileStat;
    int                 sRet;

    [self getFileStat:&sFileStat];

    if ((sFileStat->mode & S_IFMT) != S_IFLNK)
    {
        if ([sHandler respondsToSelector:@selector(createSymbolicLinkAtPath:withDestinationPath:)])
        {
            id        sUserData;
            NSString *sPath;

            sRet = [sHandler openFileAtPath:[self path] accessMode:kMRFSFileRead userData:&sUserData];

            if (!sRet)
            {
                void    *sBuffer;
                int64_t  sSize;

                sBuffer = malloc(sFileStat->size);
                sRet    = [sHandler readFileAtPath:[self path] buffer:sBuffer size:sFileStat->size offset:0 returnedSize:&sSize userData:sUserData];
                [sHandler closeFileAtPath:[self path] userData:sUserData];

                if (sRet)
                {
                    free(sBuffer);
                }
                else
                {
                    sPath = [[[NSString alloc] initWithBytesNoCopy:sBuffer length:sSize encoding:NSUTF8StringEncoding freeWhenDone:YES] autorelease];

                    if (!sPath)
                    {
                        sRet = EFAULT;
                    }
                }
            }

            if (!sRet)
            {
                sRet = [sHandler removeFileAtPath:[self path]];
            }

            if (!sRet)
            {
                sRet = [sHandler createSymbolicLinkAtPath:[self path] withDestinationPath:sPath];
            }

            if (sRet)
            {
                [self deleteNode];

                return kFPMiscErr;
            }
            else
            {
                [self invalidateFileStat];

                return kFPNoErr;
            }
        }
        else
        {
            [self deleteNode];

            return kFPCallNotSupported;
        }
    }
    else
    {
        return kFPNoErr;
    }
}


@end


@implementation AFPFile


- (BOOL)isDirectory
{
    return NO;
}


- (uint16_t)attribute
{
    return kFPMultiUserBit;
}


- (uint32_t)dataForkLen
{
    uint64_t sSize = [self dataForkLenExt];

    if (sSize > UINT32_MAX)
    {
        return UINT32_MAX;
    }
    else
    {
        return sSize;
    }
}


- (uint32_t)rsrcForkLen
{
    uint64_t sSize = [self rsrcForkLenExt];

    if (sSize > UINT32_MAX)
    {
        return UINT32_MAX;
    }
    else
    {
        return sSize;
    }
}


- (uint64_t)dataForkLenExt
{
    MRFSFileStat *sFileStat;

    [self getFileStat:&sFileStat];

    return sFileStat->size;
}


- (uint64_t)rsrcForkLenExt
{
    int64_t sSize;

    if ([[self volume] supportsExtendedAttributes])
    {
        int sRet = [[self operationHandler] getExtendedAttribute:"com.apple.ResourceFork" forItemAtPath:[self path] buffer:NULL size:0 offset:0 returnedSize:&sSize options:XATTR_NOFOLLOW];

        if (sRet)
        {
            sSize = 0;
        }
    }
    else
    {
        sSize = 0;
    }

    return sSize;
}


- (uint32_t)setParameters:(const uint8_t *)aParameters bitmap:(int16_t)aBitmap
{
    MRFSFileStat sStat;
    int          sBitmap  = 0;

    if (aBitmap & kFPAttributeBit)
    {
        uint16_t sAttribute = ntohs(*(uint16_t *)aParameters);

        aParameters += 2;

        // TODO
        NSLog(@"AFPFile setAttribute: %#hx IGNORED [%@]", sAttribute, [self path]);
    }

    if (aBitmap & kFPParentDirIDBit)
    {
        return kFPBitmapErr;
    }

    if (aBitmap & kFPCreateDateBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  <- File:kFPCreateDateBit = %d", ntohl(*(int32_t *)aParameters));
#endif
        sStat.creationDate  = ntohl(*(int32_t *)aParameters);
        sBitmap            |= kMRFSFileCreationDateBit;
        aParameters        += 4;
    }

    if (aBitmap & kFPModDateBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  <- File:kFPModDateBit = %d", ntohl(*(int32_t *)aParameters));
#endif
        sStat.modificationDate  = ntohl(*(int32_t *)aParameters);
        sBitmap                |= kMRFSFileModificationDateBit;
        aParameters            += 4;
    }

    if (aBitmap & kFPBackupDateBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  <- File:kFPBackupDateBit = %d", ntohl(*(int32_t *)aParameters));
#endif
        /* no support for backup date, ignore silently */

        aParameters += 4;
    }

    if (aBitmap & kFPFinderInfoBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  <- File:kFPFinderInfoBit = %@", [NSData dataWithBytesNoCopy:(void *)aParameters length:32 freeWhenDone:NO]);
#endif
        if (memcmp(aParameters, "slnkrhap", 8) == 0)
        {
            uint32_t sResult = [self makeSymbolicLink];

            if (sResult != kFPNoErr)
            {
                return sResult;
            }
        }
        else
        {
            if ([[self volume] supportsExtendedAttributes])
            {
                int64_t sSize;

                [[self operationHandler] setExtendedAttribute:"com.apple.FinderInfo" forItemAtPath:[self path] buffer:aParameters size:32 offset:0 writtenSize:&sSize options:XATTR_NOFOLLOW];
            }
        }

        aParameters += 32;
    }

    if (aBitmap & kFPLongNameBit)
    {
        return kFPBitmapErr;
    }

    if (aBitmap & kFPShortNameBit)
    {
        return kFPBitmapErr;
    }

    if (aBitmap & kFPNodeIDBit)
    {
        return kFPBitmapErr;
    }

    if (aBitmap & kFPDataForkLenBit)
    {
        return kFPBitmapErr;
    }

    if (aBitmap & kFPRsrcForkLenBit)
    {
        return kFPBitmapErr;
    }

    if (aBitmap & kFPExtDataForkLenBit)
    {
        return kFPBitmapErr;
    }

    if (aBitmap & kFPUTF8NameBit)
    {
        return kFPBitmapErr;
    }

    if (aBitmap & kFPExtRsrcForkLenBit)
    {
        return kFPBitmapErr;
    }

    if (aBitmap & kFPUnixPrivsBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  <- File:kFPUnixPrivsBit = %d, %d, %#o, %#x", ntohl(((uint32_t *)aParameters)[0]), ntohl(((uint32_t *)aParameters)[1]), ntohl(((uint32_t *)aParameters)[2]), ntohl(((uint32_t *)aParameters)[3]));
#endif
        sStat.userID  = ntohl(*(uint32_t *)aParameters);
        sBitmap      |= kMRFSFileUserIDBit;
        aParameters  += 4;

        sStat.groupID  = ntohl(*(uint32_t *)aParameters);
        sBitmap       |= kMRFSFileGroupIDBit;
        aParameters   += 4;

        sStat.mode   = ntohl(*(uint32_t *)aParameters);
        sBitmap     |= kMRFSFileModeBit;
        // aParameters += 4;

        /* ignore ua_permissions */
    }

    if (sBitmap)
    {
        int sRet = [[self operationHandler] setFileStat:&sStat bitmap:sBitmap ofItemAtPath:[self path]];

        [self invalidateFileStat];

        if (sRet)
        {
            return kFPAccessDenied; // TODO
        }
        else
        {
            return kFPNoErr;
        }
    }
    else
    {
        return kFPNoErr;
    }
}


@end
