/*
 *  MRFSPrivates.h
 *  MRFS
 *
 *  Created by han9kin on 2011-04-26.
 *
 */

#import <Foundation/Foundation.h>


@class AFPServer;
@class AFPListener;
@class MRFSVolume;


@interface MRFSServer (AFPAccessing)


- (AFPServer *)server;
- (AFPListener *)listener;


@end


@interface MRFSServer (VolumeRegistration)


- (void)addVolume:(MRFSVolume *)aVolume;
- (void)removeVolume:(MRFSVolume *)aVolume;


@end


@interface MRFSServer (DiskArbitration)


- (void)setupDiskArbitration;
- (void)finalizeDiskArbitration;


- (void)registerDisappearCallbackForVolume:(MRFSVolume *)aVolume;
- (void)unregisterDisappearCallbackForVolume:(MRFSVolume *)aVolume;


@end


@interface MRFSVolume (MountEventHandling)


- (void)didMountAtPath:(NSString *)aMountPoint volumeRefNum:(FSVolumeRefNum)aMountedVolumeRefNum;
- (void)didUnmountAtPath:(NSString *)aMountPoint;


@end
