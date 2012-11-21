/*
 *  MRFSVolume.m
 *  MRFS
 *
 *  Created by han9kin on 2011-04-26.
 *
 */

#import "AFPServer.h"
#import "AFPListener.h"
#import "AFPVolume.h"
#import "MRFSOperations.h"
#import "MRFSServer.h"
#import "MRFSVolume.h"
#import "MRFSPrivates.h"


static void MRFSVolumeMountProc(FSVolumeOperation aVolumeOp, void *aClientData, OSStatus aErr, FSVolumeRefNum aMountedVolumeRefNum);
static void MRFSVolumeUnmountProc(FSVolumeOperation aVolumeOp, void *aClientData, OSStatus aErr, FSVolumeRefNum aVolumeRefNum, pid_t aDissenter);


@implementation MRFSVolume


#pragma mark -
#pragma mark Initializing a File System Object


- (id)initWithServer:(MRFSServer *)aServer
{
    self = [super init];

    if (self)
    {
        mVolume = [[aServer server] addVolumeWithVolume:self];

        if (!mVolume)
        {
            [self release];
            return nil;
        }

        mServer = [aServer retain];

        [mServer addVolume:self];
    }

    return self;
}


- (void)dealloc
{
    [mVolume closeVolume];
    [mServer removeVolume:self];
    [[mServer server] removeVolume:mVolume];
    [mServer release];
    [super dealloc];
}


#pragma mark -
#pragma mark Setting the Delegate


- (id<MRFSOperations>)delegate
{
    return mDelegate;
}


- (void)setDelegate:(id<MRFSOperations>)aDelegate
{
    mDelegate = aDelegate;
}


#pragma mark -
#pragma mark Configuring Properties


- (NSString *)volumeName
{
    return [mVolume volumeName];
}


- (BOOL)setVolumeName:(NSString *)aVolumeName
{
    if ([aVolumeName length])
    {
        if ([self isMounted])
        {
            return NO;
        }
        else
        {
            return [[mServer server] renameVolume:mVolume toName:[NSString stringWithUTF8String:[aVolumeName fileSystemRepresentation]]];
        }
    }
    else
    {
        return NO;
    }
}


#pragma mark -
#pragma mark Getting the File System Status


- (BOOL)isMounted
{
    return mMountPoint ? YES : NO;
}


- (NSString *)mountPoint
{
    return mMountPoint;
}


- (FSVolumeRefNum)volumeRefNum
{
    return mMountedVolumeRefNum;
}


#pragma mark -
#pragma mark Mounting and Unmounting the File System


- (void)mountAtPath:(NSString *)aMountPoint
{
    NSError *sError = nil;

    if (mMountPoint)
    {
        sError = [NSError errorWithDomain:NSPOSIXErrorDomain code:EALREADY userInfo:nil];
    }
    else if (mVolumeOperation)
    {
        sError = [NSError errorWithDomain:NSPOSIXErrorDomain code:EINPROGRESS userInfo:nil];
    }
    else
    {
        OSStatus sStatus;

        sStatus = FSCreateVolumeOperation(&mVolumeOperation);

        if (sStatus)
        {
            NSLog(@"FSCreateVolumeOperation error = %ld", (long)sStatus);

            sError = [NSError errorWithDomain:NSOSStatusErrorDomain code:sStatus userInfo:nil];
        }
        else
        {
            sStatus = FSMountServerVolumeAsync(
                (CFURLRef)[NSURL URLWithString:[NSString stringWithFormat:@"afp://%@:%hu/%@", [[mServer listener] host], [[mServer listener] port], [[self volumeName] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]],
                (aMountPoint ? (CFURLRef)[NSURL fileURLWithPath:aMountPoint] : NULL),
                (CFStringRef)[mServer userName],
                (CFStringRef)[[mServer listener] password],
                mVolumeOperation,
                self,
                0,
                MRFSVolumeMountProc,
                CFRunLoopGetCurrent(),
                kCFRunLoopCommonModes);

            if (sStatus)
            {
                NSLog(@"FSMountServerVolumeAsync failed with status %ld", (long)sStatus);

                sError = [NSError errorWithDomain:NSOSStatusErrorDomain code:sStatus userInfo:nil];

                FSDisposeVolumeOperation(mVolumeOperation);
                mVolumeOperation = NULL;
            }
        }
    }

    if (sError && [mDelegate respondsToSelector:@selector(volume:mountDidFailWithError:)])
    {
        [mDelegate volume:self mountDidFailWithError:sError];
    }
}


- (void)unmount
{
    NSError *sError = nil;

    if (!mMountPoint)
    {
        return;
    }
    else if (mVolumeOperation)
    {
        sError = [NSError errorWithDomain:NSPOSIXErrorDomain code:EINPROGRESS userInfo:nil];
    }
    else
    {
        OSStatus sStatus;

        sStatus = FSCreateVolumeOperation(&mVolumeOperation);

        if (sStatus)
        {
            NSLog(@"FSCreateVolumeOperation error = %ld", (long)sStatus);

            sError = [NSError errorWithDomain:NSOSStatusErrorDomain code:sStatus userInfo:nil];
        }
        else
        {
            sStatus = FSUnmountVolumeAsync(
                mMountedVolumeRefNum,
                0,
                mVolumeOperation,
                self,
                MRFSVolumeUnmountProc,
                CFRunLoopGetCurrent(),
                kCFRunLoopCommonModes);

            if (sStatus)
            {
                NSLog(@"FSUnmountVolumeAsync failed with status %ld", (long)sStatus);

                sError = [NSError errorWithDomain:NSOSStatusErrorDomain code:sStatus userInfo:nil];

                FSDisposeVolumeOperation(mVolumeOperation);
                mVolumeOperation = NULL;
            }
        }
    }

    if (sError && [mDelegate respondsToSelector:@selector(volume:unmountDidFailWithError:)])
    {
        [mDelegate volume:self unmountDidFailWithError:sError];
    }
}


- (void)cancel
{
    if (mVolumeOperation)
    {
        FSCancelVolumeOperation(mVolumeOperation);
        FSDisposeVolumeOperation(mVolumeOperation);
        mVolumeOperation = NULL;
    }
}


@end


@interface MRFSVolume (MountOperationCallback)
@end


@implementation MRFSVolume (MountOperationCallback)


- (void)mountOperationDidFinishWithStatus:(OSStatus)aStatus
{
    @synchronized(self)
    {
        FSDisposeVolumeOperation(mVolumeOperation);
        mVolumeOperation = NULL;
    }

    if (aStatus && [mDelegate respondsToSelector:@selector(volume:mountDidFailWithError:)])
    {
        [mDelegate volume:self mountDidFailWithError:[NSError errorWithDomain:NSOSStatusErrorDomain code:aStatus userInfo:nil]];
    }
}


- (void)unmountOperationDidFinishWithStatus:(OSStatus)aStatus dissenter:(pid_t)aDissenter
{
    @synchronized(self)
    {
        FSDisposeVolumeOperation(mVolumeOperation);
        mVolumeOperation = NULL;
    }

    if (aStatus && [mDelegate respondsToSelector:@selector(volume:unmountDidFailWithError:)])
    {
        [mDelegate volume:self unmountDidFailWithError:[NSError errorWithDomain:NSOSStatusErrorDomain code:aStatus userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:aDissenter], @"dissenter", nil]]];
    }
}


@end


@implementation MRFSVolume (MountEventHandling)


- (void)didMountAtPath:(NSString *)aMountPoint volumeRefNum:(FSVolumeRefNum)aMountedVolumeRefNum
{
    @synchronized(self)
    {
        [mMountPoint autorelease];
        mMountPoint = [aMountPoint copy];

        mMountedVolumeRefNum = aMountedVolumeRefNum;

        [mServer registerDisappearCallbackForVolume:self];
    }

    if ([mDelegate respondsToSelector:@selector(volume:mountDidFinishAtPath:)])
    {
        [mDelegate volume:self mountDidFinishAtPath:aMountPoint];
    }
}


- (void)didUnmountAtPath:(NSString *)aMountPoint
{
    @synchronized(self)
    {
        [mServer unregisterDisappearCallbackForVolume:self];

        [mMountPoint release];
        mMountPoint = nil;

        mMountedVolumeRefNum = 0;
    }

    if ([mDelegate respondsToSelector:@selector(volume:unmountDidFinishAtPath:)])
    {
        [mDelegate volume:self unmountDidFinishAtPath:aMountPoint];
    }
}


@end


static void MRFSVolumeMountProc(FSVolumeOperation aVolumeOp, void *aClientData, OSStatus aStatus, FSVolumeRefNum aMountedVolumeRefNum)
{
    MRFSVolume *sVolume = aClientData;

    [sVolume mountOperationDidFinishWithStatus:aStatus];
}


static void MRFSVolumeUnmountProc(FSVolumeOperation aVolumeOp, void *aClientData, OSStatus aStatus, FSVolumeRefNum aVolumeRefNum, pid_t aDissenter)
{
    MRFSVolume *sVolume = aClientData;

    [sVolume unmountOperationDidFinishWithStatus:aStatus dissenter:aDissenter];
}
