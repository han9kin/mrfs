/*
 *  AFPNode.m
 *  MRFS
 *
 *  Created by han9kin on 2011-04-22.
 *
 */

#import <sys/xattr.h>
#import "ObjC+Util.h"
#import "AFPProtocol.h"
#import "AFPVolume.h"
#import "AFPDirectory.h"
#import "AFPNode.h"


#define kStatTimeout 2.0


@implementation AFPNode


- (id)initWithNodeID:(int32_t)aNodeID volume:(AFPVolume *)aVolume stat:(const MRFSFileStat *)aFileStat
{
    self = [super init];

    if (self)
    {
        mNodeID = aNodeID;

        if (aFileStat)
        {
            mFileStat     = *aFileStat;
            mFileStatTime = [NSDate timeIntervalSinceReferenceDate];
        }
        else
        {
            mFileStatTime = [[NSDate distantPast] timeIntervalSinceReferenceDate];
        }

        [aVolume addNode:self];
    }

    return self;
}


- (void)dealloc
{
    [mParent release];
    [mNodeName release];
    [super dealloc];
}


- (AFPVolume *)volume
{
    return [mParent volume];
}


- (NSString *)path
{
    NSMutableArray *sComps = [NSMutableArray array];

    for (AFPNode *sNode = self; [[sNode parent] nodeName]; sNode = [sNode parent])
    {
        [sComps insertObject:[sNode nodeName] atIndex:0];
    }

    [sComps insertObject:@"/" atIndex:0];

    return [NSString pathWithComponents:sComps];
}


- (id<MRFSOperations>)operationHandler
{
    return [[[mParent volume] volume] delegate];
}


- (BOOL)isDirectory
{
    SubclassResponsibility();

    return NO;
}


- (NSString *)nodeName
{
    return mNodeName;
}


- (void)setNodeName:(NSString *)aNodeName
{
    [mNodeName autorelease];
    mNodeName = [aNodeName copy];
}


- (AFPDirectory *)parent
{
    return mParent;
}


- (void)setParent:(AFPDirectory *)aParent
{
    [mParent autorelease];
    mParent = [aParent retain];
}


- (AFPNode *)validateNode
{
    AFPNode      *sNode = self;
    MRFSFileStat *sFileStat;
    int           sResult;

    sResult = [self getFileStat:&sFileStat];

    if (sResult)
    {
        if (sResult == ENOENT)
        {
            [mParent removeOffspringNode:self];

            sNode = nil;
        }
    }
    else
    {
        BOOL sIsDir = ((sFileStat->mode & S_IFMT) == S_IFDIR) ? YES : NO;

        if ([self isDirectory] != sIsDir)
        {
            AFPDirectory *sParent   = [mParent retain];
            NSString     *sNodeName = [mNodeName copy];
            MRFSFileStat  sNodeStat = *sFileStat;

            [sParent removeOffspringNode:self];

            sNode = [sParent addOffspringNodeWithName:sNodeName isDirectory:sIsDir stat:&sNodeStat];

            [sParent release];
            [sNodeName release];
        }
    }

    return sNode;
}


- (int)getFileStat:(MRFSFileStat **)aFileStat
{
    NSTimeInterval sCurrentTime = [NSDate timeIntervalSinceReferenceDate];
    int            sResult      = 0;

    if ((sCurrentTime - mFileStatTime) > kStatTimeout)
    {
        sResult = [[self operationHandler] getFileStat:&mFileStat ofItemAtPath:[self path]];

        mFileStatTime = sCurrentTime;
    }

    *aFileStat = &mFileStat;

    return sResult;
}


- (void)setFileStat:(const MRFSFileStat *)aFileStat
{
    mFileStat     = *aFileStat;
    mFileStatTime = [NSDate timeIntervalSinceReferenceDate];
}


- (void)invalidateFileStat
{
    mFileStatTime = [[NSDate distantPast] timeIntervalSinceReferenceDate];
}


- (uint32_t)accessRightsFromMode:(uint32_t)aMode userID:(uint32_t)aUserID
{
    uint32_t sAccessRights = 0;

    if (aMode & S_IRUSR)
    {
        sAccessRights |= kRPOwner;
    }

    if (aMode & S_IWUSR)
    {
        sAccessRights |= kWROwner;
    }

    if (aMode & S_IXUSR)
    {
        sAccessRights |= kSPOwner;
    }

    if (aMode & S_IRGRP)
    {
        sAccessRights |= kRPGroup;
    }

    if (aMode & S_IWGRP)
    {
        sAccessRights |= kWRGroup;
    }

    if (aMode & S_IXGRP)
    {
        sAccessRights |= kSPGroup;
    }

    if (aMode & S_IROTH)
    {
        sAccessRights |= kRPOther;
    }

    if (aMode & S_IWOTH)
    {
        sAccessRights |= kWROther;
    }

    if (aMode & S_IXOTH)
    {
        sAccessRights |= kSPOther;
    }

    if (aUserID == getuid())
    {
        if (aMode & S_IRUSR)
        {
            sAccessRights |= kRPUser;
        }

        if (aMode & S_IWUSR)
        {
            sAccessRights |= kWRUser;
        }

        if (aMode & S_IXUSR)
        {
            sAccessRights |= kSPUser;
        }

        sAccessRights |= kUserIsOwner;
    }
    else
    {
        if (aMode & S_IROTH)
        {
            sAccessRights |= kRPUser;
        }

        if (aMode & S_IWOTH)
        {
            sAccessRights |= kWRUser;
        }

        if (aMode & S_IXOTH)
        {
            sAccessRights |= kSPUser;
        }
    }

    return sAccessRights;
}


- (uint32_t)modeFromAccessRights:(uint32_t)aAccessRights
{
    uint32_t sMode = 0;

    if (aAccessRights & kRPOwner)
    {
        sMode |= S_IRUSR;
    }

    if (aAccessRights & kWROwner)
    {
        sMode |= S_IWUSR;
    }

    if (aAccessRights & kSPOwner)
    {
        sMode |= S_IXUSR;
    }

    if (aAccessRights & kRPGroup)
    {
        sMode |= S_IRGRP;
    }

    if (aAccessRights & kWRGroup)
    {
        sMode |= S_IWGRP;
    }

    if (aAccessRights & kSPGroup)
    {
        sMode |= S_IXGRP;
    }

    if (aAccessRights & kRPOther)
    {
        sMode |= S_IROTH;
    }

    if (aAccessRights & kWROther)
    {
        sMode |= S_IWOTH;
    }

    if (aAccessRights & kSPOther)
    {
        sMode |= S_IXOTH;
    }

    return sMode;
}


- (uint16_t)attribute
{
    SubclassResponsibility();

    return 0;
}


- (uint32_t)parentID
{
    return [mParent nodeID];
}


- (uint32_t)creationDate
{
    MRFSFileStat *sFileStat;

    [self getFileStat:&sFileStat];

    return sFileStat->creationDate;
}


- (uint32_t)modificationDate
{
    MRFSFileStat *sFileStat;

    [self getFileStat:&sFileStat];

    return sFileStat->modificationDate;
}


- (uint32_t)backupDate
{
    return 0x80000000;
}


- (NSData *)finderInfo
{
    char    sBuffer[32];
    int64_t sSize;

    if ([[self volume] supportsExtendedAttributes])
    {
        int sRet = [[self operationHandler] getExtendedAttribute:"com.apple.FinderInfo" forItemAtPath:[self path] buffer:sBuffer size:sizeof(sBuffer) offset:0 returnedSize:&sSize options:XATTR_NOFOLLOW];

        if (sRet)
        {
            sSize = 0;
        }
    }
    else
    {
        sSize = 0;
    }

    if (sSize != sizeof(sBuffer))
    {
        memset(sBuffer, 0, sizeof(sBuffer));
    }

    return [NSData dataWithBytes:sBuffer length:sizeof(sBuffer)];
}


- (NSString *)longName
{
    return nil;
}


- (NSString *)shortName
{
    return nil;
}


- (int32_t)nodeID
{
    return mNodeID;
}


- (void)getUnixPrivileges:(struct FPUnixPrivs *)aUnixPrivs
{
    MRFSFileStat *sFileStat;

    [self getFileStat:&sFileStat];

    aUnixPrivs->uid            = sFileStat->userID;
    aUnixPrivs->gid            = sFileStat->groupID;
    aUnixPrivs->permissions    = sFileStat->mode;
    aUnixPrivs->ua_permissions = [self accessRightsFromMode:sFileStat->mode userID:sFileStat->userID];
}


- (uint32_t)setParameters:(const uint8_t *)aParameters bitmap:(int16_t)aBitmap
{
    SubclassResponsibility();

    return kFPNoErr;
}


- (uint32_t)deleteNode
{
    int sRet;

    if (mNodeID <= 16)
    {
        return kFPAccessDenied;
    }

    if ([self isDirectory])
    {
        sRet = [[self operationHandler] removeDirectoryAtPath:[self path]];
    }
    else
    {
        sRet = [[self operationHandler] removeFileAtPath:[self path]];
    }

    if (sRet)
    {
        if ((sRet == EACCES) || (sRet == EPERM))
        {
            return kFPAccessDenied;
        }
        else if (sRet == EBUSY)
        {
            return kFPObjectLocked;
        }
        else if ((sRet == ENOENT) || (sRet == ENOTDIR))
        {
            return kFPObjectNotFound;
        }
        else if (sRet == ENOTEMPTY)
        {
            return kFPDirNotEmpty;
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
        [mParent removeOffspringNode:self];

        return kFPNoErr;
    }
}


- (uint32_t)moveNodeToDirectory:(AFPDirectory *)aDirectory withNewName:(NSString *)aNodeName
{
    int sRet;

    if (mNodeID <= 16)
    {
        return aDirectory ? kFPCantMove : kFPCantRename;
    }

    if (aNodeName)
    {
        NSAssert([[aNodeName pathComponents] count] == 1, @"New node name have multiple path components");

        if ([(aDirectory ? aDirectory : mParent) offspringNodeForName:aNodeName])
        {
            return kFPObjectExists;
        }
    }

    sRet = [[self operationHandler] moveItemAtPath:[self path] toPath:[[(aDirectory ? aDirectory : mParent) path] stringByAppendingPathComponent:(aNodeName ? aNodeName : mNodeName)]];

    if (sRet)
    {
        if ((sRet == EACCES) || (sRet == EPERM))
        {
            return kFPAccessDenied;
        }
        else if (sRet == EDQUOT)
        {
            return kFPDiskQuotaExceeded;
        }
        else if (sRet == EINVAL)
        {
            return aDirectory ? kFPCantMove : kFPCantRename;
        }
        else if ((sRet == ENOENT) || (sRet == ENOTDIR))
        {
            return kFPObjectNotFound;
        }
        else if (sRet == ENOSPC)
        {
            return kFPDiskFull;
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
        [mParent moveOffspringNode:self toDirectory:aDirectory withNewName:aNodeName];

        if (aDirectory && (aDirectory != mParent))
        {
            [self setParent:aDirectory];
        }

        if (aNodeName && ![aNodeName isEqualToString:mNodeName])
        {
            [self setNodeName:aNodeName];
        }

        return kFPNoErr;
    }
}


- (uint32_t)listExtendedAttributes:(void *)aBuffer size:(int64_t)aSize returnedSize:(int64_t *)aReturnedSize bitmap:(uint16_t)aBitmap
{
    int sOptions = 0;
    int sRet;

    if (aBitmap & kXAttrNoFollow)
    {
        sOptions |= XATTR_NOFOLLOW;
    }

    sRet = [[self operationHandler] listExtendedAttributesForItemAtPath:[self path] buffer:aBuffer size:aSize returnedSize:aReturnedSize options:sOptions];

    if (sRet)
    {
        if (sRet == ENOTSUP)
        {
            return kFPCallNotSupported;
        }
        else if (sRet == EACCES)
        {
            return kFPAccessDenied;
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


- (uint32_t)getExtendedAttribute:(const char *)aName buffer:(void *)aBuffer size:(int64_t)aSize offset:(int64_t)aOffset returnedSize:(int64_t *)aReturnedSize bitmap:(uint16_t)aBitmap
{
    int sOptions = 0;
    int sRet;

    if (aBitmap & kXAttrNoFollow)
    {
        sOptions |= XATTR_NOFOLLOW;
    }

    sRet = [[self operationHandler] getExtendedAttribute:aName forItemAtPath:[self path] buffer:aBuffer size:aSize offset:aOffset returnedSize:aReturnedSize options:sOptions];

    if (sRet)
    {
        if (sRet == ENOTSUP)
        {
            return kFPCallNotSupported;
        }
        else if (sRet == EACCES)
        {
            return kFPAccessDenied;
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


- (uint32_t)setExtendedAttribute:(const char *)aName buffer:(const void *)aBuffer size:(int64_t)aSize offset:(int64_t)aOffset writtenSize:(int64_t *)aWrittenSize bitmap:(uint16_t)aBitmap
{
    int sOptions = 0;
    int sRet;

    if (aBitmap & kXAttrNoFollow)
    {
        sOptions |= XATTR_NOFOLLOW;
    }

    if (aBitmap & kXAttrCreate)
    {
        sOptions |= XATTR_CREATE;
    }

    if (aBitmap & kXAttrReplace)
    {
        sOptions |= XATTR_REPLACE;
    }

    sRet = [[self operationHandler] setExtendedAttribute:aName forItemAtPath:[self path] buffer:aBuffer size:aSize offset:aOffset writtenSize:aWrittenSize options:sOptions];

    if (sRet)
    {
        if (sRet == ENOTSUP)
        {
            return kFPCallNotSupported;
        }
        else if (sRet == EACCES)
        {
            return kFPAccessDenied;
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


- (uint32_t)removeExtendedAttribute:(const char *)aName bitmap:(uint16_t)aBitmap
{
    int sOptions = 0;
    int sRet;

    if (aBitmap & kXAttrNoFollow)
    {
        sOptions |= XATTR_NOFOLLOW;
    }

    sRet = [[self operationHandler] removeExtendedAttribute:aName forItemAtPath:[self path] options:sOptions];

    if (sRet)
    {
        if (sRet == ENOTSUP)
        {
            return kFPCallNotSupported;
        }
        else if (sRet == EACCES)
        {
            return kFPAccessDenied;
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


@end
