/*
 *  AFPServer.h
 *  MRFS
 *
 *  Created by han9kin on 2011-04-21.
 *
 */

#import <Foundation/Foundation.h>


@class AFPVolume;
@class MRFSVolume;


@interface AFPServer : NSObject
{
    NSData              *mServerSignature;

    uint32_t             mMaxReqSize;
    BOOL                 mSupportsCopyFile;
    NSString            *mMachineType;
    NSString            *mServerName;
    NSString            *mUTF8ServerName;
    BOOL                 mShowsMountedVolumesOnly;

    NSMutableDictionary *mVolumesByName;
    NSMutableSet        *mVolumeIDs;
    uint16_t             mVolumeLastID;
}


- (NSData *)serverSignature;


- (uint32_t)maxReqSize;
- (void)setMaxReqSize:(uint32_t)aSize;

- (BOOL)supportsCopyFile;
- (void)setSupportsCopyFile:(BOOL)aSupportCopyFile;

- (NSString *)machineType;
- (void)setMachineType:(NSString *)aMachineType;

- (NSString *)serverName;
- (void)setServerName:(NSString *)aServerName;

- (NSString *)UTF8ServerName;
- (void)setUTF8ServerName:(NSString *)aUTF8ServerName;

- (BOOL)showsMountedVolumesOnly;
- (void)setShowsMountedVolumesOnly:(BOOL)aShowsMountedVolumesOnly;


- (NSArray *)volumes;
- (AFPVolume *)volumeForName:(NSString *)aVolumeName;

- (AFPVolume *)addVolumeWithVolume:(MRFSVolume *)aVolume;
- (void)removeVolume:(AFPVolume *)aVolume;
- (BOOL)renameVolume:(AFPVolume *)aVolume toName:(NSString *)aVolumeName;


@end
