/*
 *  AFPConnection.h
 *  MRFS
 *
 *  Created by han9kin on 2011-04-12.
 *
 */

#import <Foundation/Foundation.h>
#import "AFPProtocol.h"


@class AFPMessage;
@class AFPSession;
@class AFPListener;
@class AFPDHXContext;


@interface AFPConnection : NSThread <NSStreamDelegate>
{
    BOOL            mStop;
    BOOL            mTearDown;

    AFPListener    *mListener;
    AFPSession     *mSession;
    AFPDHXContext  *mLoginContext;

    NSFileHandle   *mFileHandle;
    NSInputStream  *mInputStream;
    NSOutputStream *mOutputStream;

    BOOL            mHeaderReady;
    NSInteger       mReceivedLength;
    DSIHeader       mReceivedHeader;
    uint8_t        *mReceivedPayload;
    NSMutableArray *mSendingMessages;

    uint16_t        mLastRequestID;
    NSTimeInterval  mLastSentTime;
}


+ (NSArray *)supportedAFPVersions;
+ (NSArray *)supportedUAMs;


- (id)initWithFileHandle:(NSFileHandle *)aFileHandle listener:(AFPListener *)aListener;


- (AFPListener *)listener;


- (void)stop;
- (void)shutdown;


- (void)sendAttention:(uint16_t)aUserBytes;
- (void)replyMessage:(AFPMessage *)aMessage;


@end
