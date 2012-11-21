/*
 *  AFPServer.m
 *  MRFS
 *
 *  Created by han9kin on 2011-04-21.
 *
 */

#import <sys/sysctl.h>
#import "AFPServer.h"
#import "AFPVolume.h"


static NSString *AFPGetDefaultMachineType()
{
    char   *sModel;
    size_t  sLen;
    int     sName[] = { CTL_HW, HW_MODEL };

    sysctl(sName, 2, NULL, &sLen, NULL, 0);

    sModel = malloc(sLen);

    sysctl(sName, 2, sModel, &sLen, NULL, 0);

    NSString *sResult = [NSString stringWithUTF8String:sModel];

    free(sModel);

    if (!sResult)
    {
        sResult = @"Mac";
    }

    return sResult;
}


@implementation AFPServer


- (id)init
{
    self = [super init];

    if (self)
    {
        CFUUIDRef   sSignatureID;
        CFUUIDBytes sSignatureBytes;

        NSAssert((sizeof(CFUUIDBytes) == 16), @"sizeof CFUUID is not equal to sizeof AFP ServerSignature");

        sSignatureID     = CFUUIDCreate(NULL);
        sSignatureBytes  = CFUUIDGetUUIDBytes(sSignatureID);
        mServerSignature = [[NSData alloc] initWithBytes:&sSignatureBytes length:sizeof(sSignatureBytes)];
        CFRelease(sSignatureID);

        mMaxReqSize    = 1024 * 1024;
        mVolumesByName = [[NSMutableDictionary alloc] init];
        mVolumeIDs     = [[NSMutableSet alloc] init];
    }

    return self;
}


- (void)dealloc
{
    [mServerSignature release];
    [mMachineType release];
    [mServerName release];
    [mUTF8ServerName release];
    [mVolumesByName release];
    [mVolumeIDs release];
    [super dealloc];
}


- (NSData *)serverSignature
{
    return mServerSignature;
}


- (uint32_t)maxReqSize
{
    return mMaxReqSize;
}


- (void)setMaxReqSize:(uint32_t)aSize
{
    mMaxReqSize = aSize;
}


- (BOOL)supportsCopyFile
{
    return mSupportsCopyFile;
}


- (void)setSupportsCopyFile:(BOOL)aSupportsCopyFile
{
    mSupportsCopyFile = aSupportsCopyFile;
}


- (NSString *)machineType
{
    return mMachineType ? mMachineType : AFPGetDefaultMachineType();
}


- (void)setMachineType:(NSString *)aMachineType
{
    [mMachineType autorelease];
    mMachineType = [aMachineType copy];
}


- (NSString *)serverName
{
    return mServerName ? mServerName : @"mrfs";
}


- (void)setServerName:(NSString *)aServerName
{
    [mServerName autorelease];
    mServerName = nil;

    if ([aServerName length] && [aServerName canBeConvertedToEncoding:NSASCIIStringEncoding])
    {
        NSCharacterSet  *sSet   = [[NSCharacterSet characterSetWithCharactersInString:@"-01234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz"] invertedSet];
        NSMutableString *sName  = [aServerName mutableCopy];
        NSUInteger       sIndex = 0;

        while (1)
        {
            NSRange sRange;

            sRange = [sName rangeOfCharacterFromSet:sSet options:0 range:NSMakeRange(sIndex, [sName length] - sIndex)];

            if (sRange.location == NSNotFound)
            {
                break;
            }

            [sName deleteCharactersInRange:sRange];

            sIndex = sRange.location;
        }

        if ([sName length])
        {
            mServerName = [sName copy];
        }

        [sName release];
    }

    if (!mUTF8ServerName)
    {
        mUTF8ServerName = [aServerName copy];
    }
}


- (NSString *)UTF8ServerName
{
    return mUTF8ServerName ? mUTF8ServerName : (mServerName ? mServerName : @"MRFS");
}


- (void)setUTF8ServerName:(NSString *)aUTF8ServerName
{
    [mUTF8ServerName autorelease];
    mUTF8ServerName = [aUTF8ServerName copy];
}


- (BOOL)showsMountedVolumesOnly
{
    return mShowsMountedVolumesOnly;
}


- (void)setShowsMountedVolumesOnly:(BOOL)aShowsMountedVolumesOnly
{
    mShowsMountedVolumesOnly = aShowsMountedVolumesOnly;
}


- (NSArray *)volumes
{
    NSArray *sVolumes;

    @synchronized(self)
    {
        sVolumes = [mVolumesByName allValues];
    }

    return sVolumes;
}


- (AFPVolume *)volumeForName:(NSString *)aVolumeName
{
    AFPVolume *sVolume;

    @synchronized(self)
    {
        sVolume = [mVolumesByName objectForKey:aVolumeName];
    }

    return sVolume;
}


- (AFPVolume *)addVolumeWithVolume:(MRFSVolume *)aVolume
{
    AFPVolume *sVolume;

    @synchronized(self)
    {
        uint16_t sVolumeID = ++mVolumeLastID;

        if (sVolumeID == 0)
        {
            sVolumeID     = 1;
            mVolumeLastID = 1;
        }

        while ([mVolumeIDs containsObject:[NSNumber numberWithShort:sVolumeID]])
        {
            sVolumeID++;

            if (sVolumeID == 0)
            {
                sVolumeID = 1;
            }

            if (sVolumeID == mVolumeLastID)
            {
                return nil; /* No more volumes allowed */
            }
        }

        NSString *sVolumeName;
        unsigned  sSuffix = sVolumeID;

        do
        {
            sVolumeName = [NSString stringWithFormat:@"Volume %u", sSuffix++];
        }
        while ([mVolumesByName objectForKey:sVolumeName]);

        sVolume = [[AFPVolume alloc] initWithID:sVolumeID volume:aVolume];

        [sVolume setVolumeName:sVolumeName];

        [mVolumeIDs addObject:[NSNumber numberWithShort:sVolumeID]];
        [mVolumesByName setObject:sVolume forKey:sVolumeName];
        [sVolume release];
    }

    return sVolume;
}


- (void)removeVolume:(AFPVolume *)aVolume
{
    @synchronized(self)
    {
        if ([mVolumesByName objectForKey:[aVolume volumeName]] == aVolume)
        {
            [mVolumeIDs removeObject:[NSNumber numberWithShort:[aVolume volumeID]]];
            [mVolumesByName removeObjectForKey:[aVolume volumeName]];
        }
    }
}


- (BOOL)renameVolume:(AFPVolume *)aVolume toName:(NSString *)aVolumeName
{
    BOOL sSuccess;

    @synchronized(self)
    {
        if ([mVolumesByName objectForKey:[aVolume volumeName]] == aVolume)
        {
            if ([mVolumesByName objectForKey:aVolumeName])
            {
                sSuccess = NO; /* Volume name already exists */
            }
            else
            {
                [aVolume retain];
                [mVolumesByName removeObjectForKey:[aVolume volumeName]];
                [mVolumesByName setObject:aVolume forKey:aVolumeName];
                [aVolume setVolumeName:aVolumeName];
                [aVolume release];

                sSuccess = YES;
            }
        }
        else
        {
            sSuccess = NO; /* Volume is not registered */
        }
    }

    return sSuccess;
}


@end
