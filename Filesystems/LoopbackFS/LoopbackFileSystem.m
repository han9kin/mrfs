/*
 *  LoopbackFileSystem.m
 *  MRFS
 *
 *  Created by han9kin on 2011-04-27.
 *
 */

#import <sys/stat.h>
#import <sys/param.h>
#import <sys/mount.h>
#import <sys/xattr.h>
#import "LoopbackFileSystem.h"


static int32_t gTimeDiff = 0;


@implementation LoopbackFileSystem


+ (void)initialize
{
    if (!gTimeDiff)
    {
        NSDate *sDate = [NSDate date];

        gTimeDiff = (int32_t)[sDate timeIntervalSince1970] - (int32_t)[sDate timeIntervalSinceReferenceDate];
    }
}


- (id)initWithName:(NSString *)aName path:(NSString *)aPath server:(MRFSServer *)aServer
{
    self = [super init];

    if (self)
    {
        mName = [aName copy];
        mPath = [aPath copy];

        mVolume = [[MRFSVolume alloc] initWithServer:aServer];
        [mVolume setDelegate:self];
        [mVolume setVolumeName:mName];
    }

    return self;
}


- (void)dealloc
{
    [mVolume release];
    [mName release];
    [mPath release];
    [super dealloc];
}


- (NSString *)name
{
    return mName;
}


- (NSString *)path
{
    return mPath;
}


- (MRFSVolume *)volume
{
    return mVolume;
}


- (BOOL)isMounted
{
    return [mVolume isMounted];
}


- (void)setMounted:(BOOL)aMounted
{
    if (aMounted)
    {
        if (![mVolume isMounted])
        {
            [mVolume mountAtPath:nil];
        }
    }
    else
    {
        if ([mVolume isMounted])
        {
            [mVolume unmount];
        }
    }
}


#pragma mark -


- (NSString *)pathForPath:(NSString *)aPath
{
    return [mPath stringByAppendingPathComponent:aPath];
}


- (const char *)systemPathForPath:(NSString *)aPath
{
    return [[self pathForPath:aPath] fileSystemRepresentation];
}


#pragma mark -
#pragma mark MRFSOperations


- (void)volume:(MRFSVolume *)aVolume mountDidFinishAtPath:(NSString *)aMountPoint
{
    [self willChangeValueForKey:@"mounted"];
    [self didChangeValueForKey:@"mounted"];
}


- (void)volume:(MRFSVolume *)aVolume mountDidFailWithError:(NSError *)aError
{
    [[NSApplication sharedApplication] presentError:aError];
}


- (void)volume:(MRFSVolume *)aVolume unmountDidFinishAtPath:(NSString *)aMountPoint
{
    [self willChangeValueForKey:@"mounted"];
    [self didChangeValueForKey:@"mounted"];
}


- (void)volume:(MRFSVolume *)aVolume unmountDidFailWithError:(NSError *)aError
{
    [[NSApplication sharedApplication] presentError:aError];
}


- (int)getVolumeStat:(MRFSVolumeStat *)aVolumeStat
{
    struct statfs64 sVolumeStat;

    statfs64("/", &sVolumeStat);

    aVolumeStat->blockSize = sVolumeStat.f_bsize;
    aVolumeStat->totalSize = sVolumeStat.f_bsize * sVolumeStat.f_blocks;
    aVolumeStat->freeSize  = sVolumeStat.f_bsize * sVolumeStat.f_bavail;

    return 0;
}


- (int)getFileStat:(MRFSFileStat *)aFileStat ofItemAtPath:(NSString *)aPath
{
    struct stat64 sFileStat;

    if (lstat64([self systemPathForPath:aPath], &sFileStat))
    {
        return errno;
    }
    else
    {
        aFileStat->creationDate     = sFileStat.st_birthtime - gTimeDiff;
        aFileStat->modificationDate = sFileStat.st_mtime - gTimeDiff;
        aFileStat->userID           = sFileStat.st_uid;
        aFileStat->groupID          = sFileStat.st_gid;
        aFileStat->mode             = sFileStat.st_mode;
        aFileStat->size             = sFileStat.st_size;

        return 0;
    }
}


- (int)getOffspringNames:(NSArray **)aOffspringNames fileStats:(NSArray **)aFileStats ofDirectoryAtPath:(NSString *)aPath
{
    NSFileManager *sFileManager;
    NSArray       *sContents;
    NSError       *sError;

    sFileManager = [[NSFileManager alloc] init];
    sContents    = [sFileManager contentsOfDirectoryAtPath:[self pathForPath:aPath] error:&sError];
    [sFileManager release];

    if (sContents)
    {
        *aOffspringNames = sContents;

        return 0;
    }
    else
    {
        if ([[sError domain] isEqualToString:NSPOSIXErrorDomain])
        {
            return [sError code];
        }
        else
        {
            NSLog(@"LoopbackFileSystem getOffspringNames error: %@", sError);
            return EACCES;
        }
    }
}


- (int)openFileAtPath:(NSString *)aPath accessMode:(int16_t)aAccessMode userData:(id *)aUserData
{
    int sFileDescriptor;

    if ((aAccessMode & kMRFSFileRead) && (aAccessMode & kMRFSFileWrite))
    {
        sFileDescriptor = open([self systemPathForPath:aPath], (O_RDWR | O_NOFOLLOW));
    }
    else if (aAccessMode & kMRFSFileWrite)
    {
        sFileDescriptor = open([self systemPathForPath:aPath], (O_WRONLY | O_NOFOLLOW));
    }
    else
    {
        sFileDescriptor = open([self systemPathForPath:aPath], (O_RDONLY | O_NOFOLLOW));
    }

    if (sFileDescriptor != -1)
    {
        *aUserData = [[[NSFileHandle alloc] initWithFileDescriptor:sFileDescriptor closeOnDealloc:YES] autorelease];

        return 0;
    }
    else
    {
        return errno;
    }
}


- (int)closeFileAtPath:(NSString *)aPath userData:(id)aUserData
{
    [aUserData closeFile];

    return 0;
}


- (int)readFileAtPath:(NSString *)aPath buffer:(void *)aBuffer size:(int64_t)aSize offset:(int64_t)aOffset returnedSize:(int64_t *)aReturnedSize userData:(id)aUserData
{
    int64_t sLength = 0;

    while (sLength < aSize)
    {
        ssize_t sRet = pread([aUserData fileDescriptor], (char *)aBuffer + sLength, aSize - sLength, aOffset + sLength);

        if (sRet < 0)
        {
            if (sLength)
            {
                break;
            }
            else
            {
                return errno;
            }
        }
        else if (sRet == 0)
        {
            break;
        }
        else
        {
            sLength += sRet;
        }
    }

    *aReturnedSize = sLength;

    return 0;
}


- (int)setFileStat:(MRFSFileStat *)aFileStat bitmap:(int)aBitmap ofItemAtPath:(NSString *)aPath
{
    NSMutableDictionary *sAttributes = [NSMutableDictionary dictionary];
    int                  sResult     = 0;

    if (aBitmap & kMRFSFileCreationDateBit)
    {
        [sAttributes setObject:[NSDate dateWithTimeIntervalSinceReferenceDate:aFileStat->creationDate] forKey:NSFileCreationDate];
    }

    if (aBitmap & kMRFSFileModificationDateBit)
    {
        [sAttributes setObject:[NSDate dateWithTimeIntervalSinceReferenceDate:aFileStat->modificationDate] forKey:NSFileModificationDate];
    }

    if (aBitmap & kMRFSFileUserIDBit)
    {
        [sAttributes setObject:[NSNumber numberWithUnsignedLong:aFileStat->userID] forKey:NSFileOwnerAccountID];
    }

    if (aBitmap & kMRFSFileGroupIDBit)
    {
        [sAttributes setObject:[NSNumber numberWithUnsignedLong:aFileStat->groupID] forKey:NSFileGroupOwnerAccountID];
    }

    if (aBitmap & kMRFSFileModeBit)
    {
        [sAttributes setObject:[NSNumber numberWithUnsignedLong:aFileStat->mode] forKey:NSFilePosixPermissions];
    }

    if ([sAttributes count])
    {
        NSFileManager *sFileManager = [[NSFileManager alloc] init];
        NSError       *sError;

        if (![sFileManager setAttributes:sAttributes ofItemAtPath:[self pathForPath:aPath] error:&sError])
        {
            if ([[sError domain] isEqualToString:NSPOSIXErrorDomain])
            {
                sResult = [sError code];
            }
            else
            {
                NSLog(@"LoopbackFileSystem setFileStat error: %@", sError);
                sResult = EACCES;
            }
        }

        [sFileManager release];
    }

    return sResult;
}


- (int)createDirectoryAtPath:(NSString *)aPath
{
    NSFileManager *sFileManager = [[NSFileManager alloc] init];
    NSError       *sError;
    int            sResult;

    if ([sFileManager createDirectoryAtPath:[self pathForPath:aPath] withIntermediateDirectories:NO attributes:nil error:&sError])
    {
        sResult = 0;
    }
    else
    {
        if ([[sError domain] isEqualToString:NSPOSIXErrorDomain])
        {
            sResult = [sError code];
        }
        else
        {
            NSLog(@"LoopbackFileSystem createDirectoryAtPath error: %@", sError);
            sResult = EACCES;
        }
    }

    [sFileManager release];

    return sResult;
}


- (int)createFileAtPath:(NSString *)aPath
{
    NSFileManager *sFileManager = [[NSFileManager alloc] init];
    int            sResult;

    if ([sFileManager createFileAtPath:[self pathForPath:aPath] contents:nil attributes:nil])
    {
        sResult = 0;
    }
    else
    {
        sResult = EACCES;
    }

    [sFileManager release];

    return sResult;
}


- (int)removeDirectoryAtPath:(NSString *)aPath
{
    int sRet;

    sRet = rmdir([self systemPathForPath:aPath]);

    if (sRet)
    {
        return errno;
    }
    else
    {
        return 0;
    }
}


- (int)removeFileAtPath:(NSString *)aPath
{
    int sRet;

    sRet = unlink([self systemPathForPath:aPath]);

    if (sRet)
    {
        return errno;
    }
    else
    {
        return 0;
    }
}


- (int)moveItemAtPath:(NSString *)aSourcePath toPath:(NSString *)aDestinationPath
{
    int sRet;

    sRet = rename([self systemPathForPath:aSourcePath], [self systemPathForPath:aDestinationPath]);

    if (sRet)
    {
        return errno;
    }
    else
    {
        return 0;
    }
}


- (int)writeFileAtPath:(NSString *)aPath buffer:(const void *)aBuffer size:(int64_t)aSize offset:(int64_t)aOffset writtenSize:(int64_t *)aWrittenSize userData:(id)aUserData
{
    int64_t sLength = 0;

    while (sLength < aSize)
    {
        ssize_t sRet = pwrite([aUserData fileDescriptor], (const char *)aBuffer + sLength, aSize - sLength, aOffset + sLength);

        if (sRet < 0)
        {
            if (sLength)
            {
                break;
            }
            else
            {
                return errno;
            }
        }
        else
        {
            sLength += sRet;
        }
    }

    *aWrittenSize = sLength;

    return 0;
}


- (int)truncateFileAtPath:(NSString *)aPath offset:(int64_t)aOffset userData:(id)aUserData
{
    int sRet;

    sRet = ftruncate([aUserData fileDescriptor], aOffset);

    if (sRet)
    {
        return errno;
    }
    else
    {
        return 0;
    }
}


- (int)getDestination:(NSString **)aDestinationPath ofSymbolicLinkAtPath:(NSString *)aPath
{
    char    sBuffer[PATH_MAX];
    ssize_t sRet;

    sRet = readlink([self systemPathForPath:aPath], sBuffer, sizeof(sBuffer));

    if (sRet == -1)
    {
        return errno;
    }
    else
    {
        *aDestinationPath = [[[NSString alloc] initWithBytes:sBuffer length:sRet encoding:NSUTF8StringEncoding] autorelease];

        return 0;
    }
}


- (int)createSymbolicLinkAtPath:(NSString *)aPath withDestinationPath:(NSString *)aDestinationPath
{
    int sRet;

    sRet = symlink([aDestinationPath fileSystemRepresentation], [self systemPathForPath:aPath]);

    if (sRet)
    {
        return errno;
    }
    else
    {
        return 0;
    }
}


- (int)listExtendedAttributesForItemAtPath:(NSString *)aPath buffer:(void *)aBuffer size:(int64_t)aSize returnedSize:(int64_t *)aReturnedSize options:(int)aOptions
{
    ssize_t sRet;

    sRet = listxattr([self systemPathForPath:aPath], aBuffer, aSize, aOptions);

    if (sRet == -1)
    {
        return errno;
    }
    else
    {
        *aReturnedSize = sRet;

        return 0;
    }
}


- (int)getExtendedAttribute:(const char *)aName forItemAtPath:(NSString *)aPath buffer:(void *)aBuffer size:(int64_t)aSize offset:(int64_t)aPosition returnedSize:(int64_t *)aReturnedSize options:(int)aOptions
{
    ssize_t sRet;

    sRet = getxattr([self systemPathForPath:aPath], aName, aBuffer, aSize, aPosition, aOptions);

    if (sRet == -1)
    {
        return errno;
    }
    else
    {
        *aReturnedSize = sRet;

        return 0;
    }
}


- (int)setExtendedAttribute:(const char *)aName forItemAtPath:(NSString *)aPath buffer:(const void *)aBuffer size:(int64_t)aSize offset:(int64_t)aPosition writtenSize:(int64_t *)aWrittenSize options:(int)aOptions
{
    int sRet;

    sRet = setxattr([self systemPathForPath:aPath], aName, aBuffer, aSize, aPosition, aOptions);

    if (sRet)
    {
        return errno;
    }
    else
    {
        *aWrittenSize = aSize;

        return 0;
    }
}


- (int)removeExtendedAttribute:(const char *)aName forItemAtPath:(NSString *)aPath options:(int)aOptions
{
    int sRet;

    sRet = removexattr([self systemPathForPath:aPath], aName, aOptions);

    if (sRet)
    {
        return errno;
    }
    else
    {
        return 0;
    }
}


@end
