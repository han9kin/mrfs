/*
 *  AFPVolume.m
 *  MRFS
 *
 *  Created by han9kin on 2011-04-21.
 *
 */

#import "AFPProtocol.h"
#import "AFPVolume.h"
#import "AFPDirectory.h"
#import "MRFSVolume.h"


#define kStatTimeout 2.0


@interface AFPVolume (DirectoryHierarchy)
@end


@implementation AFPVolume (DirectoryHierarchy)


- (void)setupInitialDirectoryHierarchy
{
    AFPDirectory *sDirectory1; /* parent directory of root directory */
    AFPDirectory *sDirectory2; /* root directory of volume */

    sDirectory1 = [[[AFPDirectory alloc] initWithNodeID:1 volume:self stat:NULL] autorelease];

    sDirectory2 = [[[AFPDirectory alloc] initWithNodeID:2 volume:self stat:NULL] autorelease];
    [sDirectory2 setNodeName:mVolumeName];
    [sDirectory2 setParent:sDirectory1];

    [sDirectory1 setupRoot:sDirectory2];
}


@end


@implementation AFPVolume


- (id)initWithID:(int16_t)aVolumeID volume:(MRFSVolume *)aVolume
{
    self = [super init];

    if (self)
    {
        mVolume           = aVolume;
        mVolumeID         = aVolumeID;

        mDirectoriesByID  = [[NSMutableDictionary alloc] init];
        mUsedNodeIDs      = [[NSMutableSet alloc] init];
        mLastNodeID       = 16;
        mModificationDate = [NSDate timeIntervalSinceReferenceDate];
        mVolumeStatTime   = [[NSDate distantPast] timeIntervalSinceReferenceDate];

        [self setupInitialDirectoryHierarchy];
    }

    return self;
}


- (void)dealloc
{
    [mVolumeName release];
    [mDirectoriesByID release];
    [mUsedNodeIDs release];
    [super dealloc];
}


- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> {ID=%d, Name=%@}", NSStringFromClass([self class]), self, mVolumeID, mVolumeName];
}


- (MRFSVolume *)volume
{
    return mVolume;
}


- (void)closeVolume
{
    mVolume = nil;
}


- (BOOL)isReadOnly
{
    if (!mIsReadOnly)
    {
        id<MRFSOperations> sHandler = [mVolume delegate];

        if ([sHandler respondsToSelector:@selector(setFileStat:bitmap:ofItemAtPath:)] &&
            [sHandler respondsToSelector:@selector(createDirectoryAtPath:)] &&
            [sHandler respondsToSelector:@selector(createFileAtPath:)] &&
            [sHandler respondsToSelector:@selector(removeDirectoryAtPath:)] &&
            [sHandler respondsToSelector:@selector(removeFileAtPath:)] &&
            [sHandler respondsToSelector:@selector(moveItemAtPath:toPath:)] &&
            [sHandler respondsToSelector:@selector(writeFileAtPath:buffer:size:offset:writtenSize:userData:)] &&
            [sHandler respondsToSelector:@selector(truncateFileAtPath:offset:userData:)])
        {
            mIsReadOnly = -1;
        }
        else
        {
            mIsReadOnly = 1;
        }
    }

    return (mIsReadOnly > 0) ? YES : NO;
}


- (BOOL)supportsCatalogSearch
{
    if (!mSupportsCatalogSearch)
    {
        // TODO

        mSupportsCatalogSearch = -1;
    }

    return (mSupportsCatalogSearch > 0) ? YES : NO;
}


- (BOOL)supportsExchangeFiles
{
    if (!mSupportsExchangeFiles)
    {
        // TODO

        mSupportsExchangeFiles = -1;
    }

    return (mSupportsExchangeFiles > 0) ? YES : NO;
}


- (BOOL)supportsExtendedAttributes
{
    if (!mSupportsExtendedAttributes)
    {
        id<MRFSOperations> sHandler = [mVolume delegate];

        if ([sHandler respondsToSelector:@selector(listExtendedAttributesForItemAtPath:buffer:size:returnedSize:options:)] &&
            [sHandler respondsToSelector:@selector(getExtendedAttribute:forItemAtPath:buffer:size:offset:returnedSize:options:)])
        {
            if ([self isReadOnly])
            {
                mSupportsExtendedAttributes = 1;
            }
            else
            {
                if ([sHandler respondsToSelector:@selector(setExtendedAttribute:forItemAtPath:buffer:size:offset:writtenSize:options:)] &&
                    [sHandler respondsToSelector:@selector(removeExtendedAttribute:forItemAtPath:options:)])
                {
                    mSupportsExtendedAttributes = 1;
                }
                else
                {
                    mSupportsExtendedAttributes = -1;
                }
            }
        }
        else
        {
            mSupportsExtendedAttributes = -1;
        }
    }

    return (mSupportsExtendedAttributes > 0) ? YES : NO;
}


- (BOOL)isCaseSensitive
{
    // TODO

    return NO;
}


- (NSString *)volumeName
{
    return mVolumeName;
}


- (void)setVolumeName:(NSString *)aVolumeName
{
    AFPDirectory *sDirectory1 = [mDirectoriesByID objectForKey:[NSNumber numberWithInt:1]];
    AFPDirectory *sDirectory2 = [mDirectoriesByID objectForKey:[NSNumber numberWithInt:2]];

    [mVolumeName autorelease];
    mVolumeName = [aVolumeName copy];

    [sDirectory2 setNodeName:mVolumeName];
    [sDirectory1 setupRoot:sDirectory2];
}


- (int32_t)nextNodeID
{
    int32_t sNextNodeID;

    @synchronized(self)
    {
        do
        {
            sNextNodeID = ++mLastNodeID;

            if (sNextNodeID <= 0)
            {
                sNextNodeID = 17;
                mLastNodeID = 17;
            }
        } while ([mUsedNodeIDs containsObject:[NSNumber numberWithInt:sNextNodeID]]);
    }

    return sNextNodeID;
}


- (void)addNode:(AFPNode *)aNode
{
    NSNumber *sNodeID = [NSNumber numberWithInt:[aNode nodeID]];

    @synchronized(self)
    {
        if ([aNode isDirectory])
        {
            [mDirectoriesByID setObject:aNode forKey:sNodeID];
        }

        [mUsedNodeIDs addObject:sNodeID];
    }

    [self updateModificationDate];
}


- (void)removeNode:(AFPNode *)aNode
{
    NSNumber *sNodeID = [NSNumber numberWithInt:[aNode nodeID]];

    @synchronized(self)
    {
        [mDirectoriesByID removeObjectForKey:sNodeID];
        [mUsedNodeIDs removeObject:sNodeID];
    }

    [self updateModificationDate];
}


- (AFPDirectory *)directoryForID:(int32_t)aDirectoryID
{
    return [mDirectoriesByID objectForKey:[NSNumber numberWithInt:aDirectoryID]];
}


- (void)updateModificationDate
{
    @synchronized(self)
    {
        mModificationDate = [NSDate timeIntervalSinceReferenceDate];
    }
}


- (void)getVolumeStat:(MRFSVolumeStat **)aVolumeStat
{
    NSTimeInterval sCurrentTime = [NSDate timeIntervalSinceReferenceDate];

    if ((sCurrentTime - mVolumeStatTime) > kStatTimeout)
    {
        [[mVolume delegate] getVolumeStat:&mVolumeStat];

        mVolumeStatTime = sCurrentTime;
    }

    *aVolumeStat = &mVolumeStat;
}


- (uint16_t)attribute
{
    uint16_t sAttr = 0;

    if ([self isReadOnly])
    {
        sAttr |= kReadOnly;
    }

    if ([self supportsCatalogSearch])
    {
        sAttr |= kSupportsCatSearch;
    }

    if (![self supportsExchangeFiles])
    {
        sAttr |= kNoExchangeFiles;
    }

    if ([self isCaseSensitive])
    {
        sAttr |= kCaseSensitive;
    }

    sAttr |= kSupportsUnixPrivs;
    sAttr |= kSupportsUTF8Names;
    sAttr |= kSupportsExtAttrs;

    return sAttr;
}


- (int32_t)creationDate
{
    return 0;
}


- (int32_t)modificationDate
{
    return mModificationDate;
}


- (int32_t)backupDate
{
    return 0x80000000;
}


- (int16_t)volumeID
{
    return mVolumeID;
}


- (uint32_t)freeBytes
{
    uint64_t sSize = [self freeBytesExt];

    if (sSize > UINT32_MAX)
    {
        return UINT32_MAX;
    }
    else
    {
        return sSize;
    }
}


- (uint32_t)totalBytes
{
    uint64_t sSize = [self totalBytesExt];

    if (sSize > UINT32_MAX)
    {
        return UINT32_MAX;
    }
    else
    {
        return sSize;
    }
}


- (uint64_t)freeBytesExt
{
    MRFSVolumeStat *sVolumeStat;

    [self getVolumeStat:&sVolumeStat];

    return sVolumeStat->freeSize;
}


- (uint64_t)totalBytesExt
{
    MRFSVolumeStat *sVolumeStat;

    [self getVolumeStat:&sVolumeStat];

    return sVolumeStat->totalSize;
}


- (uint32_t)blockSize
{
    MRFSVolumeStat *sVolumeStat;

    [self getVolumeStat:&sVolumeStat];

    return sVolumeStat->blockSize;
}


- (uint32_t)flush
{
    id<MRFSOperations> sHandler = [mVolume delegate];

    if ([sHandler respondsToSelector:@selector(flushVolume)])
    {
        int sRet = [sHandler flushVolume];

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


@end
