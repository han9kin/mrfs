/*
 *  MRFSOperations.h
 *  MRFS
 *
 *  Created by han9kin on 2011-04-27.
 *
 */

#import <Foundation/Foundation.h>


/*
 * date values in the MRFSFileStat structures are
 * the seconds since the system's absolute reference date
 * (the first instant of 1 January 2001, GMT)
 */


typedef struct MRFSVolumeStat
{
    uint32_t blockSize;
    uint64_t totalSize;
    uint64_t freeSize;
} MRFSVolumeStat;


typedef struct MRFSFileStat
{
    int32_t  creationDate;
    int32_t  modificationDate;
    uint32_t userID;
    uint32_t groupID;
    uint32_t mode;
    uint64_t size;
} MRFSFileStat;


enum MRFSFileStatBitmap
{
    kMRFSFileCreationDateBit     = 0x0001,
    kMRFSFileModificationDateBit = 0x0002,
    kMRFSFileUserIDBit           = 0x0010,
    kMRFSFileGroupIDBit          = 0x0020,
    kMRFSFileModeBit             = 0x0040,
};


enum MRFSFileAccessMode
{
    kMRFSFileRead      = 0x01,
    kMRFSFileWrite     = 0x02,
    kMRFSFileDenyRead  = 0x10,
    kMRFSFileDenyWrite = 0x20,
};


@class MRFSVolume;


@protocol MRFSOperations <NSObject>


#pragma mark Optional Methods to handle Mount Events
@optional;


- (void)volume:(MRFSVolume *)aVolume mountDidFinishAtPath:(NSString *)aMountPoint;
- (void)volume:(MRFSVolume *)aVolume mountDidFailWithError:(NSError *)aError;
- (void)volume:(MRFSVolume *)aVolume unmountDidFinishAtPath:(NSString *)aMountPoint;
- (void)volume:(MRFSVolume *)aVolume unmountDidFailWithError:(NSError *)aError;


#pragma mark Required Methods
@required;


- (int)getVolumeStat:(MRFSVolumeStat *)aVolumeStat;
- (int)getFileStat:(MRFSFileStat *)aFileStat ofItemAtPath:(NSString *)aPath;

- (int)getOffspringNames:(NSArray **)aOffspringNames fileStats:(NSArray **)aFileStats ofDirectoryAtPath:(NSString *)aPath;

- (int)openFileAtPath:(NSString *)aPath accessMode:(int16_t)aAccessMode userData:(id *)aUserData;
- (int)closeFileAtPath:(NSString *)aPath userData:(id)aUserData;

- (int)readFileAtPath:(NSString *)aPath buffer:(void *)aBuffer size:(int64_t)aSize offset:(int64_t)aOffset returnedSize:(int64_t *)aReturnedSize userData:(id)aUserData;


#pragma mark Required Methods to support Writing
@optional;


- (int)setFileStat:(MRFSFileStat *)aFileStat bitmap:(int)aBitmap ofItemAtPath:(NSString *)aPath;

- (int)createDirectoryAtPath:(NSString *)aPath;
- (int)createFileAtPath:(NSString *)aPath;

- (int)removeDirectoryAtPath:(NSString *)aPath;
- (int)removeFileAtPath:(NSString *)aPath;

- (int)moveItemAtPath:(NSString *)aSourcePath toPath:(NSString *)aDestinationPath;

- (int)writeFileAtPath:(NSString *)aPath buffer:(const void *)aBuffer size:(int64_t)aSize offset:(int64_t)aOffset writtenSize:(int64_t *)aWrittenSize userData:(id)aUserData;
- (int)truncateFileAtPath:(NSString *)aPath offset:(int64_t)aOffset userData:(id)aUserData;


#pragma mark Optional Methods to support Symbolic Links
@optional;


- (int)getDestination:(NSString **)aDestinationPath ofSymbolicLinkAtPath:(NSString *)aPath;
- (int)createSymbolicLinkAtPath:(NSString *)aPath withDestinationPath:(NSString *)aDestinationPath;


#pragma mark Required Methods to support Extended Attributes
@optional;


- (int)listExtendedAttributesForItemAtPath:(NSString *)aPath buffer:(void *)aBuffer size:(int64_t)aSize returnedSize:(int64_t *)aReturnedSize options:(int)aOptions;
- (int)getExtendedAttribute:(const char *)aName forItemAtPath:(NSString *)aPath buffer:(void *)aBuffer size:(int64_t)aSize offset:(int64_t)aPosition returnedSize:(int64_t *)aReturnedSize options:(int)aOptions;
- (int)setExtendedAttribute:(const char *)aName forItemAtPath:(NSString *)aPath buffer:(const void *)aBuffer size:(int64_t)aSize offset:(int64_t)aPosition writtenSize:(int64_t *)aWrittenSize options:(int)aOptions;
- (int)removeExtendedAttribute:(const char *)aName forItemAtPath:(NSString *)aPath options:(int)aOptions;


#pragma mark Optional Methods to support Asynchronous I/O
@optional;


- (int)flushVolume;
- (int)flushFileAtPath:(NSString *)aPath userData:(id)aUserData;


@end
