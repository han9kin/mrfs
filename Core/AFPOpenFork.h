/*
 *  AFPOpenFork.h
 *  MRFS
 *
 *  Created by han9kin on 2011-05-02.
 *
 */

#import <Foundation/Foundation.h>


@class AFPFile;


@interface AFPOpenFork : NSObject
{
    BOOL     mResourceFork;
    BOOL     mSymbolicLink;
    int16_t  mAccessMode;
    int16_t  mForkID;

    AFPFile *mFile;
    id       mUserData;
}


- (id)initWithFile:(AFPFile *)aFile flag:(uint8_t)flag accessMode:(int16_t)aAccessMode forkID:(int16_t)aForkID;


- (AFPFile *)file;
- (BOOL)isResourceFork;
- (BOOL)isSymbolicLink;
- (int16_t)accessMode;
- (int16_t)forkID;
- (uint64_t)forkLength;


- (uint32_t)openFork;
- (uint32_t)closeFork;

- (uint32_t)readFork:(void *)aBuffer size:(int64_t)aSize offset:(int64_t)aOffset returnedSize:(int64_t *)aReturnedSize;
- (uint32_t)writeFork:(const void *)aBuffer size:(int64_t)aSize offset:(int64_t)aOffset writtenSize:(int64_t *)aWrittenSize;

- (uint32_t)truncateAtOffset:(int64_t)aOffset;

- (uint32_t)flushFork;


@end
