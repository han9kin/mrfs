/*
 *  AFPDirectory.m
 *  MRFS
 *
 *  Created by han9kin on 2011-04-21.
 *
 */

#import <sys/xattr.h>
#import "NSString+Additions.h"
#import "AFPProtocol.h"
#import "AFPVolume.h"
#import "AFPDirectory.h"
#import "AFPFile.h"


#ifndef LOG_OFF
#define LOG_PARAMETERS 1
#endif


@interface AFPDirectory (Private)
@end


@implementation AFPDirectory (Private)


- (void)addOffspringNode:(AFPNode *)aNode withName:(NSString *)aNodeName
{
    [mOffspringNodes setObject:aNode forKey:aNodeName];
    [mOffspringNames addObject:aNodeName];
}


- (AFPNode *)offspringNodeForNodeID:(int32_t)aNodeID
{
    for (AFPNode *sNode in [mOffspringNodes allValues])
    {
        if ([sNode nodeID] == aNodeID)
        {
            return sNode;
        }
    }

    return nil;
}


- (void)removeOffspringNodes
{
    for (AFPNode *sNode in [mOffspringNodes allValues])
    {
        if ([sNode isDirectory])
        {
            [(AFPDirectory *)sNode removeOffspringNodes];
        }

        [mVolume removeNode:sNode];
    }

    [mOffspringNames removeAllObjects];
    [mOffspringNodes removeAllObjects];
}


@end


@implementation AFPDirectory


- (void)setupRoot:(AFPDirectory *)aDirectory
{
    if ((mNodeID == 1) && ([aDirectory nodeID] == 2) && [[aDirectory nodeName] length])
    {
        [mOffspringNames removeAllObjects];
        [mOffspringNames addObject:[aDirectory nodeName]];
        [mOffspringNodes removeAllObjects];
        [mOffspringNodes setObject:aDirectory forKey:[aDirectory nodeName]];
    }
}


- (id)initWithNodeID:(int32_t)aNodeID volume:(AFPVolume *)aVolume stat:(const MRFSFileStat *)aFileStat
{
    self = [super initWithNodeID:aNodeID volume:aVolume stat:aFileStat];

    if (self)
    {
        mVolume         = [aVolume retain];
        mOffspringNames = [[NSMutableArray alloc] init];
        mOffspringNodes = [[NSMutableDictionary alloc] init];
        mOffspringTime  = [[NSDate distantPast] timeIntervalSinceReferenceDate];
    }

    return self;
}


- (void)dealloc
{
    [mOffspringNames release];
    [mOffspringNodes release];
    [mVolume release];
    [super dealloc];
}


- (AFPVolume *)volume
{
    return mVolume;
}


- (id<MRFSOperations>)operationHandler
{
    return [[mVolume volume] delegate];
}


- (BOOL)isDirectory
{
    return YES;
}


- (uint16_t)attribute
{
    uint16_t sAttr = 0;

    return sAttr;
}


- (uint32_t)ownerID
{
    MRFSFileStat *sFileStat;

    [self getFileStat:&sFileStat];

    return sFileStat->userID;
}


- (uint32_t)groupID
{
    MRFSFileStat *sFileStat;

    [self getFileStat:&sFileStat];

    return sFileStat->groupID;
}


- (uint32_t)accessRights
{
    MRFSFileStat *sFileStat;

    [self getFileStat:&sFileStat];

    return [self accessRightsFromMode:sFileStat->mode userID:sFileStat->userID];
}


- (uint32_t)offspringCount
{
    [self refreshOffspringNodes];

    return [mOffspringNames count];
}


- (AFPNode *)offspringNodeForName:(NSString *)aNodeName
{
    AFPNode *sNode;

    sNode = [mOffspringNodes objectForKey:aNodeName];

    if (!sNode)
    {
        MRFSFileStat sFileStat;
        int          sRet;

        sRet = [[self operationHandler] getFileStat:&sFileStat ofItemAtPath:[[self path] stringByAppendingPathComponent:aNodeName]];

        if (sRet)
        {
            [mOffspringNames removeObject:aNodeName];
        }
        else
        {
            sNode = [self addOffspringNodeWithName:aNodeName isDirectory:(((sFileStat.mode & S_IFMT) == S_IFDIR) ? YES : NO) stat:&sFileStat];
        }
    }

    return sNode;
}


- (NSArray *)offspringNodesWithRange:(NSRange)aRange option:(AFPEnumerateOption)aOption
{
    NSArray        *sNames;
    NSMutableArray *sNodes;
    uint32_t        sCount;

    sCount = [mOffspringNames count];

    if (aOption == AFPEnumerateAll)
    {
        if (NSMaxRange(aRange) > sCount)
        {
            if (aRange.location < sCount)
            {
                aRange.length = sCount - aRange.location;
            }
            else
            {
                return nil;
            }
        }

        sNames = [mOffspringNames subarrayWithRange:aRange];
        sNodes = [NSMutableArray arrayWithCapacity:aRange.length];
    }
    else
    {
        sNames = mOffspringNames;
        sNodes = [NSMutableArray arrayWithCapacity:sCount];
    }

    for (NSString *sName in sNames)
    {
        AFPNode *sNode = [self offspringNodeForName:sName];

        if (sNode)
        {
            [sNodes addObject:sNode];
        }
    }

    if (aOption == AFPEnumerateAll)
    {
        return sNodes;
    }
    else
    {
        if (aOption == AFPEnumerateDirectories)
        {
            [sNodes filterUsingPredicate:[NSPredicate predicateWithFormat:@"isDirectory == TRUE"]];
        }
        else
        {
            [sNodes filterUsingPredicate:[NSPredicate predicateWithFormat:@"isDirectory == FALSE"]];
        }

        if (NSMaxRange(aRange) > [sNodes count])
        {
            if (aRange.location < [sNodes count])
            {
                aRange.length = [sNodes count] - aRange.location;
            }
            else
            {
                return nil;
            }
        }

        return [sNodes subarrayWithRange:aRange];
    }
}


- (AFPNode *)nodeForRelativePath:(NSString *)aPath
{
    AFPNode *sNode = self;

    for (NSString *sName in [aPath pathComponents])
    {
        if ([sName isEqualToString:@"."])
        {
        }
        else if ([sName isEqualToString:@".."])
        {
            sNode = [sNode parent];
        }
        else
        {
            if ([sNode isDirectory])
            {
                AFPNode *sOffspringNode;

                sOffspringNode = [(AFPDirectory *)sNode offspringNodeForName:sName];

                if (sOffspringNode)
                {
                    sNode = sOffspringNode;
                }
                else
                {
                    NSString *sPrefix;
                    NSString *sSuffix;
                    uint32_t  sNodeID;

                    if ([sName demangleFilenamePrefix:&sPrefix suffix:&sSuffix nodeID:&sNodeID])
                    {
                        // TODO: offspring nodes should be filled before following search

                        sOffspringNode = [(AFPDirectory *)sNode offspringNodeForNodeID:sNodeID];

                        if (sOffspringNode)
                        {
                            if ([[sOffspringNode nodeName] hasPrefix:sPrefix] && [[sOffspringNode nodeName] hasSuffix:sSuffix])
                            {
                                sNode = sOffspringNode;
                            }
                            else
                            {
                                sNode = nil;
                            }
                        }
                        else
                        {
                            sNode = nil;
                        }
                    }
                    else
                    {
                        sNode = nil;
                    }
                }
            }
            else
            {
                sNode = nil;
            }
        }

        if (!sNode)
        {
            break;
        }
    }

    return sNode;
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
        NSLog(@"AFPDirectory setAttribute: %#hx IGNORED [%@]", sAttribute, [self path]);
    }

    if (aBitmap & kFPParentDirIDBit)
    {
        return kFPBitmapErr;
    }

    if (aBitmap & kFPCreateDateBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  <- Directory:kFPCreateDateBit = %d", ntohl(*(int32_t *)aParameters));
#endif
        sStat.creationDate  = ntohl(*(int32_t *)aParameters);
        sBitmap            |= kMRFSFileCreationDateBit;
        aParameters        += 4;
    }

    if (aBitmap & kFPModDateBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  <- Directory:kFPModDateBit = %d", ntohl(*(int32_t *)aParameters));
#endif
        sStat.modificationDate  = ntohl(*(int32_t *)aParameters);
        sBitmap                |= kMRFSFileModificationDateBit;
        aParameters            += 4;
    }

    if (aBitmap & kFPBackupDateBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  <- Directory:kFPBackupDateBit = %d", ntohl(*(int32_t *)aParameters));
#endif
        /* no support for backup date, ignore silently */

        aParameters += 4;
    }

    if (aBitmap & kFPFinderInfoBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  <- Directory:kFPFinderInfoBit = %@", [NSData dataWithBytesNoCopy:(void *)aParameters length:32 freeWhenDone:NO]);
#endif
        if ([mVolume supportsExtendedAttributes])
        {
            int64_t sSize;

            [[self operationHandler] setExtendedAttribute:"com.apple.FinderInfo" forItemAtPath:[self path] buffer:aParameters size:32 offset:0 writtenSize:&sSize options:XATTR_NOFOLLOW];
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

    if (aBitmap & kFPOffspringCountBit)
    {
        return kFPBitmapErr;
    }

    if (aBitmap & kFPOwnerIDBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  <- Directory:kFPOwnerIDBit = %d", ntohl(*(int32_t *)aParameters));
#endif
        sStat.userID  = ntohl(*(uint32_t *)aParameters);
        sBitmap      |= kMRFSFileUserIDBit;
        aParameters  += 4;
    }

    if (aBitmap & kFPGroupIDBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  <- Directory:kFPGroupIDBit = %d", ntohl(*(int32_t *)aParameters));
#endif
        sStat.groupID  = ntohl(*(uint32_t *)aParameters);
        sBitmap       |= kMRFSFileGroupIDBit;
        aParameters   += 4;
    }

    if (aBitmap & kFPAccessRightsBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  <- Directory:kFPAccessRightsBit = %#x", ntohl(*(int32_t *)aParameters));
#endif
        sStat.mode   = [self modeFromAccessRights:ntohl(*(uint32_t *)aParameters)];
        sBitmap     |= kMRFSFileModeBit;
        aParameters += 4;
    }

    if (aBitmap & kFPUTF8NameBit)
    {
        return kFPBitmapErr;
    }

    if (aBitmap & kFPUnixPrivsBit)
    {
#if LOG_PARAMETERS
        NSLog(@"  <- Directory:kFPUnixPrivsBit = %d, %d, %#o, %#x", ntohl(((uint32_t *)aParameters)[0]), ntohl(((uint32_t *)aParameters)[1]), ntohl(((uint32_t *)aParameters)[2]), ntohl(((uint32_t *)aParameters)[3]));
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


- (uint32_t)createDirectory:(AFPNode **)aNode withName:(NSString *)aNodeName
{
    if ([mVolume isReadOnly])
    {
        return kFPVolLocked;
    }
    else
    {
        int sRet = [[self operationHandler] createDirectoryAtPath:[[self path] stringByAppendingPathComponent:aNodeName]];

        if (sRet)
        {
            if (sRet == EACCES)
            {
                return kFPAccessDenied;
            }
            else if (sRet == EDQUOT)
            {
                return kFPDiskQuotaExceeded;
            }
            else if (sRet == EEXIST)
            {
                return kFPObjectExists;
            }
            else if (sRet == ENAMETOOLONG)
            {
                return kFPParamErr;
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
            *aNode = [self addOffspringNodeWithName:aNodeName isDirectory:YES stat:NULL];

            return kFPNoErr;
        }
    }
}


- (uint32_t)createFile:(AFPNode **)aNode recreateIfExists:(BOOL)aRecreate withName:(NSString *)aNodeName
{
    if ([mVolume isReadOnly])
    {
        return kFPVolLocked;
    }
    else
    {
        int sRet = [[self operationHandler] createFileAtPath:[[self path] stringByAppendingPathComponent:aNodeName]];

        if (sRet)
        {
            if (sRet == EACCES)
            {
                return kFPAccessDenied;
            }
            else if (sRet == EDQUOT)
            {
                return kFPDiskQuotaExceeded;
            }
            else if (sRet == EEXIST)
            {
                if (aRecreate)
                {
                    return kFPCallNotSupported; // TODO
                }
                else
                {
                    return kFPObjectExists;
                }
            }
            else if (sRet == ENAMETOOLONG)
            {
                return kFPParamErr;
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
            *aNode = [self addOffspringNodeWithName:aNodeName isDirectory:NO stat:NULL];

            return kFPNoErr;
        }
    }
}


- (AFPNode *)addOffspringNodeWithName:(NSString *)aNodeName isDirectory:(BOOL)aIsDirectory stat:(const MRFSFileStat *)aStat
{
    AFPNode *sNode;

    if (aIsDirectory)
    {
        sNode = [[AFPDirectory alloc] initWithNodeID:[mVolume nextNodeID] volume:mVolume stat:aStat];
    }
    else
    {
        sNode = [[AFPFile alloc] initWithNodeID:[mVolume nextNodeID] volume:mVolume stat:aStat];
    }

    [mOffspringNodes setObject:sNode forKey:aNodeName];
    [sNode setNodeName:aNodeName];
    [sNode setParent:self];
    [sNode release];

    if (![mOffspringNames containsObject:aNodeName])
    {
        [mOffspringNames addObject:aNodeName];
    }

    return sNode;
}


- (void)removeOffspringNode:(AFPNode *)aNode
{
    NSString *sNodeName = [[aNode nodeName] copy];

    if ([aNode isDirectory])
    {
        [(AFPDirectory *)aNode removeOffspringNodes];
    }

    [mVolume removeNode:aNode];
    [mOffspringNames removeObject:sNodeName];
    [mOffspringNodes removeObjectForKey:sNodeName];

    [sNodeName release];
}


- (void)moveOffspringNode:(AFPNode *)aNode toDirectory:(AFPDirectory *)aDirectory withNewName:(NSString *)aNodeName
{
    NSString *sNodeName = [aNode nodeName];

    if (!aDirectory)
    {
        aDirectory = self;
    }

    if ((aDirectory != self) || (aNodeName && ![aNodeName isEqualToString:sNodeName]))
    {
        [aDirectory addOffspringNode:aNode withName:(aNodeName ? aNodeName : sNodeName)];
        [mOffspringNames removeObject:sNodeName];
        [mOffspringNodes removeObjectForKey:sNodeName];
    }
}


- (BOOL)refreshOffspringNodes
{
    MRFSFileStat *sFileStat;

    if ([self getFileStat:&sFileStat] != 0)
    {
        return NO;
    }

    if (sFileStat->modificationDate == mOffspringTime)
    {
        return NO;
    }

    mOffspringTime = sFileStat->modificationDate;

    NSArray *sNames     = nil;
    NSArray *sFileStats = nil;
    int      sRet;
    BOOL     sNeedsNotify = NO;

    sRet = [[self operationHandler] getOffspringNames:&sNames fileStats:&sFileStats ofDirectoryAtPath:[self path]];

    if (sRet)
    {
        [mOffspringNames removeAllObjects];
        [mOffspringNodes removeAllObjects];
    }
    else
    {
        NSSet          *sSet          = [[NSSet alloc] initWithArray:sNames];
        NSMutableArray *sRemovedNames = [[NSMutableArray alloc] init];

        for (NSString *sName in mOffspringNodes)
        {
            if (![sSet containsObject:sName])
            {
                [sRemovedNames addObject:sName];
            }
        }

        [mOffspringNames setArray:sNames];

        if ([sRemovedNames count])
        {
            for (NSString *sName in sRemovedNames)
            {
                AFPNode *sNode = [mOffspringNodes objectForKey:sName];

                if (sNode)
                {
                    [self removeOffspringNode:sNode];
                }
            }

            sNeedsNotify = YES;
        }

        if (sFileStats && ([sNames count] == [sFileStats count]))
        {
            for (NSUInteger sIndex = 0; sIndex < [sNames count]; sIndex++)
            {
                NSString           *sName     = [sNames objectAtIndex:sIndex];
                const MRFSFileStat *sFileStat = [[sFileStats objectAtIndex:sIndex] bytes];
                AFPNode            *sNode     = [mOffspringNodes objectForKey:sName];
                BOOL                sIsDir    = ((sFileStat->mode & S_IFMT) == S_IFDIR) ? YES : NO;

                if (sNode)
                {
                    if ([sNode isDirectory] == sIsDir)
                    {
                        [sNode setFileStat:sFileStat];
                    }
                    else
                    {
                        [self removeOffspringNode:sNode];
                        sNode = nil;
                    }
                }

                if (!sNode)
                {
                    [self addOffspringNodeWithName:sName isDirectory:sIsDir stat:sFileStat];
                }
            }
        }

        [sSet release];
        [sRemovedNames release];

        mOffspringTime = [NSDate timeIntervalSinceReferenceDate];
    }

    return sNeedsNotify;
}


@end
