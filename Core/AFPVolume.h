/*
 *  AFPVolume.h
 *  MRFS
 *
 *  Created by han9kin on 2011-04-21.
 *
 */

#import <Foundation/Foundation.h>
#import "MRFSOperations.h"


@class AFPDirectory;
@class AFPNode;


@interface AFPVolume : NSObject
{
    MRFSVolume          *mVolume;
    int                  mIsReadOnly;
    int                  mSupportsCatalogSearch;
    int                  mSupportsExchangeFiles;
    int                  mSupportsExtendedAttributes;

    int16_t              mVolumeID;
    NSString            *mVolumeName;

    NSMutableDictionary *mDirectoriesByID;
    NSMutableSet        *mUsedNodeIDs;
    int32_t              mLastNodeID;
    int32_t              mModificationDate;

    MRFSVolumeStat       mVolumeStat;
    NSTimeInterval       mVolumeStatTime;
}


- (id)initWithID:(int16_t)aVolumeID volume:(MRFSVolume *)aVolume;


- (MRFSVolume *)volume;
- (void)closeVolume;


- (BOOL)isReadOnly;
- (BOOL)supportsCatalogSearch;
- (BOOL)supportsExchangeFiles;
- (BOOL)supportsExtendedAttributes;
- (BOOL)isCaseSensitive;


- (NSString *)volumeName;
- (void)setVolumeName:(NSString *)aVolumeName;


- (int32_t)nextNodeID;
- (void)addNode:(AFPNode *)aNode;
- (void)removeNode:(AFPNode *)aNode;
- (AFPDirectory *)directoryForID:(int32_t)aDirectoryID;


- (void)updateModificationDate;


- (void)getVolumeStat:(MRFSVolumeStat **)aVolumeStat;


- (uint16_t)attribute;
- (int32_t)creationDate;
- (int32_t)modificationDate;
- (int32_t)backupDate;
- (int16_t)volumeID;
- (uint32_t)freeBytes;
- (uint32_t)totalBytes;
- (NSString *)volumeName;
- (uint64_t)freeBytesExt;
- (uint64_t)totalBytesExt;
- (uint32_t)blockSize;


- (uint32_t)flush;


@end
