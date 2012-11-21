/*
 *  AFPOpenFork.m
 *  MRFS
 *
 *  Created by han9kin on 2011-05-02.
 *
 */

#import <sys/xattr.h>
#import "AFPProtocol.h"
#import "AFPVolume.h"
#import "AFPFile.h"
#import "AFPOpenFork.h"


@interface AFPOpenFork (UserData)
@end


@implementation AFPOpenFork (UserData)


- (id)userData
{
    return mUserData;
}


- (void)setUserData:(id)aUserData
{
    [mUserData autorelease];
    mUserData = [aUserData retain];
}


@end


@interface AFPOpenFork (SymbolicLink)
@end


@implementation AFPOpenFork (SymbolicLink)


- (void)readSymbolicLink
{
    if (!mUserData)
    {
        NSString *sDestination = nil;

        [[mFile operationHandler] getDestination:&sDestination ofSymbolicLinkAtPath:[mFile path]];

        [self setUserData:(sDestination ? sDestination : @"")];
    }
}


@end


@implementation AFPOpenFork


- (id)initWithFile:(AFPFile *)aFile flag:(uint8_t)aFlag accessMode:(int16_t)aAccessMode forkID:(int16_t)aForkID
{
    self = [super init];

    if (self)
    {
        MRFSFileStat *sFileStat;

        [aFile getFileStat:&sFileStat];

        mFile         = [aFile retain];
        mResourceFork = aFlag ? YES : NO;
        mSymbolicLink = ((sFileStat->mode & S_IFMT) == S_IFLNK) ? YES : NO;
        mAccessMode   = aAccessMode;
        mForkID       = aForkID;
    }

    return self;
}


- (void)dealloc
{
    [mFile release];
    [mUserData release];
    [super dealloc];
}


- (AFPFile *)file
{
    return mFile;
}


- (BOOL)isResourceFork
{
    return mResourceFork;
}


- (BOOL)isSymbolicLink
{
    return mSymbolicLink;
}


- (int16_t)accessMode
{
    return mAccessMode;
}


- (int16_t)forkID
{
    return mForkID;
}


- (uint64_t)forkLength
{
    if (mResourceFork)
    {
        return [mFile rsrcForkLenExt];
    }
    else if (mSymbolicLink)
    {
        [self readSymbolicLink];

        if (mUserData)
        {
            return strlen([mUserData fileSystemRepresentation]);
        }
        else
        {
            return 0;
        }
    }
    else
    {
        return [mFile dataForkLenExt];
    }
}


- (uint32_t)openFork
{
    if (mResourceFork)
    {
        return kFPNoErr;
    }
    else if (mSymbolicLink)
    {
        if ([[mFile operationHandler] respondsToSelector:@selector(getDestination:ofSymbolicLinkAtPath:)])
        {
            return kFPNoErr;
        }
        else
        {
            return kFPMiscErr;
        }
    }
    else
    {
        id  sUserData = nil;
        int sRet;

        sRet = [[mFile operationHandler] openFileAtPath:[mFile path] accessMode:mAccessMode userData:&sUserData];

        if (sRet)
        {
            if (sRet == EACCES)
            {
                return kFPAccessDenied;
            }
            else if (sRet == ENOENT)
            {
                return kFPObjectNotFound;
            }
            else if ((sRet == EISDIR) || (sRet == ELOOP))
            {
                return kFPObjectTypeErr;
            }
            else if ((sRet == EMFILE) || (sRet == ENFILE))
            {
                return kFPTooManyFilesOpen;
            }
            else if (sRet == EROFS)
            {
                return kFPVolLocked;
            }
            else
            {
                return kFPMiscErr;
            }
        }
        else
        {
            [self setUserData:sUserData];

            return kFPNoErr;
        }
    }
}


- (uint32_t)closeFork
{
    if (mResourceFork || mSymbolicLink)
    {
        return kFPNoErr;
    }
    else
    {
        int sRet;

        sRet = [[mFile operationHandler] closeFileAtPath:[mFile path] userData:mUserData];

        if (sRet)
        {
            return kFPMiscErr;
        }
        else
        {
            return kFPNoErr;
        }
    }
}


- (uint32_t)readFork:(void *)aBuffer size:(int64_t)aSize offset:(int64_t)aOffset returnedSize:(int64_t *)aReturnedSize
{
    int sRet;

    if (mResourceFork)
    {
        if ([[mFile volume] supportsExtendedAttributes])
        {
            sRet = [[mFile operationHandler] getExtendedAttribute:"com.apple.ResourceFork" forItemAtPath:[mFile path] buffer:aBuffer size:aSize offset:aOffset returnedSize:aReturnedSize options:XATTR_NOFOLLOW];
        }
        else
        {
            *aReturnedSize = 0;
            sRet           = 0;
        }
    }
    else if (mSymbolicLink)
    {
        [self readSymbolicLink];

        if (mUserData)
        {
            const char *sDestination = [mUserData fileSystemRepresentation];
            size_t      sLength      = strlen(sDestination);

            if (aOffset < sLength)
            {
                memcpy(aBuffer, sDestination + aOffset, sLength - aOffset);

                *aReturnedSize = sLength - aOffset;
                sRet           = 0;
            }
            else
            {
                *aReturnedSize = 0;
                sRet           = 0;
            }
        }
        else
        {
            sRet = EPERM;
        }
    }
    else
    {
        sRet = [[mFile operationHandler] readFileAtPath:[mFile path] buffer:aBuffer size:aSize offset:aOffset returnedSize:aReturnedSize userData:mUserData];
    }

    if (sRet)
    {
        return kFPMiscErr;
    }
    else
    {
        if (*aReturnedSize < aSize)
        {
            return kFPEOFErr;
        }
        else
        {
            return kFPNoErr;
        }
    }
}


- (uint32_t)writeFork:(const void *)aBuffer size:(int64_t)aSize offset:(int64_t)aOffset writtenSize:(int64_t *)aWrittenSize
{
    int sRet;

    if (mResourceFork)
    {
        if ([[mFile volume] supportsExtendedAttributes])
        {
            sRet = [[mFile operationHandler] setExtendedAttribute:"com.apple.ResourceFork" forItemAtPath:[mFile path] buffer:aBuffer size:aSize offset:aOffset writtenSize:aWrittenSize options:XATTR_NOFOLLOW];
        }
        else
        {
            sRet = EPERM;
        }
    }
    else if (mSymbolicLink)
    {
        sRet = EPERM;
    }
    else
    {
        sRet = [[mFile operationHandler] writeFileAtPath:[mFile path] buffer:aBuffer size:aSize offset:aOffset writtenSize:aWrittenSize userData:mUserData];
    }

    [mFile invalidateFileStat];

    if (sRet)
    {
        if ((sRet == EDQUOT) || (sRet == EFBIG))
        {
            return kFPDiskQuotaExceeded;
        }
        else if (sRet == ENOSPC)
        {
            return kFPDiskFull;
        }
        else if (sRet == EROFS)
        {
            return kFPVolLocked;
        }
        else if (sRet == ENOTSUP)
        {
            return kFPCallNotSupported;
        }
        else
        {
            return kFPMiscErr;
        }
    }
    else
    {
        return kFPNoErr;
    }
}


- (uint32_t)truncateAtOffset:(int64_t)aOffset
{
    int sRet;

    if (mResourceFork)
    {
        if ([[mFile volume] supportsExtendedAttributes])
        {
            char    *sBuffer = malloc(aOffset);
            int64_t  sLength = 0;

            sRet = [[mFile operationHandler] getExtendedAttribute:"com.apple.ResoureFork" forItemAtPath:[mFile path] buffer:sBuffer size:aOffset offset:0 returnedSize:&sLength options:XATTR_NOFOLLOW];

            if ((sRet == 0) || (sRet == ENOATTR))
            {
                int sOptions = (sRet == ENOATTR) ? (XATTR_NOFOLLOW) : (XATTR_NOFOLLOW | XATTR_REPLACE);

                if (sLength < aOffset)
                {
                    memset(sBuffer + sLength, 0, aOffset - sLength);
                }

                sRet = [[mFile operationHandler] setExtendedAttribute:"com.apple.ResourceFork" forItemAtPath:[mFile path] buffer:sBuffer size:aOffset offset:0 writtenSize:&sLength options:sOptions];
            }

            free(sBuffer);
        }
        else
        {
            sRet = EPERM;
        }
    }
    else if (mSymbolicLink)
    {
        sRet = EPERM;
    }
    else
    {
        sRet = [[mFile operationHandler] truncateFileAtPath:[mFile path] offset:aOffset userData:mUserData];
    }

    if (sRet)
    {
        if ((sRet == EDQUOT) || (sRet == EFBIG))
        {
            return kFPDiskQuotaExceeded;
        }
        else if (sRet == ENOSPC)
        {
            return kFPDiskFull;
        }
        else if (sRet == EROFS)
        {
            return kFPVolLocked;
        }
        else if (sRet == ENOTSUP)
        {
            return kFPCallNotSupported;
        }
        else
        {
            return kFPMiscErr;
        }
    }
    else
    {
        return kFPNoErr;
    }
}


- (uint32_t)flushFork
{
    if (mResourceFork || mSymbolicLink)
    {
        return kFPNoErr;
    }
    else
    {
        id<MRFSOperations> sHandler = [mFile operationHandler];

        if ([sHandler respondsToSelector:@selector(flushFileAtPath:userData:)])
        {
            int sRet = [sHandler flushFileAtPath:[mFile path] userData:mUserData];

            if (sRet)
            {
                return kFPMiscErr;
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
}


@end
