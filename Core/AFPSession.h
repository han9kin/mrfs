/*
 *  AFPSession.h
 *  MRFS
 *
 *  Created by han9kin on 2011-04-14.
 *
 */

#import <Foundation/Foundation.h>


@class AFPMessage;
@class AFPConnection;
@class AFPFile;
@class AFPOpenFork;


@interface AFPSession : NSThread
{
    BOOL                 mStop;

    int32_t              mTimestamp;
    NSData              *mClientID;
    NSString            *mSessionToken;
    AFPConnection       *mConnection;

    NSMutableDictionary *mVolumesByID;

    NSMutableDictionary *mForksByID;
    NSMutableSet        *mUsedForkIDs;
    int16_t              mLastForkID;
}


- (void)stop;


- (int32_t)timestamp;
- (void)setTimestamp:(int32_t)aTimestamp;

- (NSData *)clientID;
- (void)setClientID:(NSData *)aClientID;

- (NSString *)sessionToken;
- (void)setSessionToken:(NSString *)aSessionToken;

- (AFPConnection *)connection;
- (void)setConnection:(AFPConnection *)aConnection;


- (void)handleMessage:(AFPMessage *)aMessage;


- (AFPOpenFork *)addForkWithFile:(AFPFile *)aFile flag:(uint8_t)aFlag accessMode:(int16_t)aAccessMode;
- (void)removeFork:(AFPOpenFork *)aNode;


@end
