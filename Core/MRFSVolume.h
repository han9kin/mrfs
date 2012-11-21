/*
 *  MRFSVolume.h
 *  MRFS
 *
 *  Created by han9kin on 2011-04-26.
 *
 */

#import <Foundation/Foundation.h>


@class AFPVolume;
@class MRFSServer;
@protocol MRFSOperations;


@interface MRFSVolume : NSObject
{
    AFPVolume          *mVolume;

    MRFSServer         *mServer;
    id<MRFSOperations>  mDelegate;

    NSString           *mMountPoint;
    FSVolumeRefNum      mMountedVolumeRefNum;
    FSVolumeOperation   mVolumeOperation;
}


#pragma mark -
#pragma mark Initializing a File System Object


- (id)initWithServer:(MRFSServer *)aServer;


#pragma mark -
#pragma mark Setting the Delegate


- (id<MRFSOperations>)delegate;
- (void)setDelegate:(id<MRFSOperations>)aDelegate;


#pragma mark -
#pragma mark Configuring Properties


- (NSString *)volumeName;
- (BOOL)setVolumeName:(NSString *)aVolumeName;


#pragma mark -
#pragma mark Getting the File System Status


- (BOOL)isMounted;
- (NSString *)mountPoint;
- (FSVolumeRefNum)volumeRefNum;


#pragma mark -
#pragma mark Mounting and Unmounting the File System


- (void)mountAtPath:(NSString *)aMountPoint;
- (void)unmount;
- (void)cancel;


@end
