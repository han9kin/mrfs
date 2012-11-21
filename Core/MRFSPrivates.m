/*
 *  MRFSPrivates.m
 *  MRFS
 *
 *  Created by han9kin on 2011-04-26.
 *
 */

#import <netinet/in.h>
#import "AFPListener.h"
#import "MRFSServer.h"
#import "MRFSVolume.h"
#import "MRFSPrivates.h"


static void MRFSVolumeAppeared(DADiskRef aDisk, void *aContext);
static void MRFSVolumeDisappeared(DADiskRef aDisk, void *aContext);


@implementation MRFSServer (AFPAccessing)


- (AFPServer *)server
{
    return mServer;
}


- (AFPListener *)listener
{
    return mListener;
}


@end


@implementation MRFSServer (VolumeRegistration)


- (void)addVolume:(MRFSVolume *)aVolume
{
    [mVolumes addObject:[NSNumber numberWithUnsignedLong:(unsigned long)aVolume]];
}


- (void)removeVolume:(MRFSVolume *)aVolume
{
    [mVolumes removeObject:[NSNumber numberWithUnsignedLong:(unsigned long)aVolume]];
}


@end


@implementation MRFSServer (DiskArbitration)


- (void)setupDiskArbitration
{
    mDASession = DASessionCreate(NULL);

    DASessionScheduleWithRunLoop(mDASession, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);

    NSMutableDictionary *sDiskDescription = [NSMutableDictionary dictionary];

    [sDiskDescription setObject:@"afpfs" forKey:(id)kDADiskDescriptionVolumeKindKey];

    DARegisterDiskAppearedCallback(mDASession, (CFDictionaryRef)sDiskDescription, MRFSVolumeAppeared, self);
}


- (void)finalizeDiskArbitration
{
    DASessionUnscheduleFromRunLoop(mDASession, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);

    CFRelease(mDASession);
}


- (void)registerDisappearCallbackForVolume:(MRFSVolume *)aVolume
{
    NSMutableDictionary *sDiskDescription = [NSMutableDictionary dictionary];

    [sDiskDescription setObject:[NSURL fileURLWithPath:[aVolume mountPoint]] forKey:(id)kDADiskDescriptionVolumePathKey];

    DARegisterDiskDisappearedCallback(mDASession, (CFDictionaryRef)sDiskDescription, MRFSVolumeDisappeared, aVolume);
}


- (void)unregisterDisappearCallbackForVolume:(MRFSVolume *)aVolume
{
    DAUnregisterCallback(mDASession, MRFSVolumeDisappeared, aVolume);
}


- (void)volumeAppearedAtPath:(NSString *)aMountPath
{
    OSStatus       sStatus;
    FSRef          sVolumeRef;
    FSCatalogInfo  sVolumeCatInfo;
    NSURL         *sVolumeURL;

    sStatus = FSPathMakeRef((const UInt8 *)[aMountPath fileSystemRepresentation], &sVolumeRef, NULL);

    if (!sStatus)
    {
        sStatus = FSGetCatalogInfo(&sVolumeRef, kFSCatInfoVolume, &sVolumeCatInfo, NULL, NULL, NULL);
    }

    if (!sStatus)
    {
        CFURLRef sURL;

        sStatus = FSCopyURLForVolume(sVolumeCatInfo.volume, &sURL);

        if (!sStatus)
        {
            sVolumeURL = [NSMakeCollectable(sURL) autorelease];
        }
    }

    if (!sStatus && [[sVolumeURL scheme] isEqualToString:@"afp"] && [[sVolumeURL host] isEqualToString:[mListener host]] && ([[sVolumeURL port] unsignedShortValue] == [mListener port]) && ([[sVolumeURL path] length] > 1))
    {
        NSString *sVolumeName = [[[sVolumeURL path] substringFromIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

        for (NSNumber *sNumber in mVolumes)
        {
            MRFSVolume *sVolume = (MRFSVolume *)[sNumber unsignedLongValue];

            if ([[sVolume volumeName] isEqualToString:sVolumeName])
            {
                [sVolume didMountAtPath:aMountPath volumeRefNum:sVolumeCatInfo.volume];
                break;
            }
        }
    }
}


@end


static void MRFSVolumeAppeared(DADiskRef aDisk, void *aContext)
{
    MRFSServer *sServer = aContext;

    [sServer volumeAppearedAtPath:[[[NSMakeCollectable(DADiskCopyDescription(aDisk)) autorelease] objectForKey:(id)kDADiskDescriptionVolumePathKey] path]];
}


static void MRFSVolumeDisappeared(DADiskRef aDisk, void *aContext)
{
    MRFSVolume *sVolume = aContext;

    [sVolume didUnmountAtPath:[[[NSMakeCollectable(DADiskCopyDescription(aDisk)) autorelease] objectForKey:(id)kDADiskDescriptionVolumePathKey] path]];
}
