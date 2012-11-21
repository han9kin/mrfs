/*
 *  AFPSession.m
 *  MRFS
 *
 *  Created by han9kin on 2011-04-14.
 *
 */

#import "AFPProtocol.h"
#import "AFPMessage.h"
#import "AFPSession.h"
#import "AFPConnection.h"
#import "AFPOpenFork.h"


#ifndef LOG_OFF
#define LOG_LIFECYCLE 0
#endif


@implementation AFPSession


- (id)init
{
    self = [super init];

    if (self)
    {
        mVolumesByID = [[NSMutableDictionary alloc] init];
        mForksByID   = [[NSMutableDictionary alloc] init];
        mUsedForkIDs = [[NSMutableSet alloc] init];

        [self start];
    }

    return self;
}


- (void)dealloc
{
#if LOG_LIFECYCLE
    NSLog(@"AFPSession deallocated");
#endif
    [mClientID release];
    [mSessionToken release];
    [mVolumesByID release];
    [mForksByID release];
    [mUsedForkIDs release];
    [super dealloc];
}


#pragma mark -
#pragma mark Stopping Session


- (void)stop
{
#if LOG_LIFECYCLE
    NSLog(@"AFPSession stop");
#endif

    mStop       = YES;
    mConnection = nil;

    [self performSelector:@selector(self) onThread:self withObject:nil waitUntilDone:NO];
}


#pragma mark -
#pragma mark Establishing Connection with Client


- (int32_t)timestamp
{
    return mTimestamp;
}


- (void)setTimestamp:(int32_t)aTimestamp
{
    mTimestamp = aTimestamp;
}


- (NSData *)clientID
{
    return mClientID;
}


- (void)setClientID:(NSData *)aClientID
{
    [mClientID autorelease];
    mClientID = [aClientID copy];
}


- (NSString *)sessionToken
{
    return mSessionToken;
}


- (void)setSessionToken:(NSString *)aSessionToken
{
    [mSessionToken autorelease];
    mSessionToken = [aSessionToken copy];
}


- (AFPConnection *)connection
{
    return mConnection;
}


- (void)setConnection:(AFPConnection *)aConnection
{
    mConnection = aConnection;
}


#pragma mark -
#pragma mark Handling Message


- (SEL)selectorForMessage:(AFPMessage *)aMessage
{
    SEL sSelector;

    switch ([aMessage afpCommand])
    {
        case kFPOpenVol:
            sSelector = @selector(doOpenVol:);
            break;
        case kFPCloseVol:
            sSelector = @selector(doCloseVol:);
            break;
        case kFPGetVolParms:
            sSelector = @selector(doGetVolParms:);
            break;
        case kFPSetVolParms:
            sSelector = @selector(doSetVolParms:);
            break;
        case kFPFlush:
            sSelector = @selector(doFlush:);
            break;
        case kFPOpenDT:
            sSelector = @selector(doOpenDT:);
            break;
        case kFPCloseDT:
            sSelector = @selector(doCloseDT:);
            break;

        case kFPListExtAttrs:
            sSelector = @selector(doListExtAttrs:);
            break;
        case kFPGetExtAttr:
            sSelector = @selector(doGetExtAttr:);
            break;
        case kFPSetExtAttr:
            sSelector = @selector(doSetExtAttr:);
            break;
        case kFPRemoveExtAttr:
            sSelector = @selector(doRemoveExtAttr:);
            break;

        case kFPGetFileDirParms:
            sSelector = @selector(doGetFileDirParms:);
            break;
        case kFPSetFileDirParms:
            sSelector = @selector(doSetFileDirParms:);
            break;
        case kFPDelete:
            sSelector = @selector(doDelete:);
            break;
        case kFPRename:
            sSelector = @selector(doRename:);
            break;
        case kFPMoveAndRename:
            sSelector = @selector(doMoveAndRename:);
            break;

        case kFPSetDirParms:
            sSelector = @selector(doSetDirParms:);
            break;
        case kFPEnumerateExt:
        case kFPEnumerateExt2:
            sSelector = @selector(doEnumerateExt2:);
            break;
        case kFPCreateDir:
            sSelector = @selector(doCreateDir:);
            break;

        case kFPSetFileParms:
            sSelector = @selector(doSetFileParms:);
            break;
        case kFPCreateFile:
            sSelector = @selector(doCreateFile:);
            break;

        case kFPOpenFork:
            sSelector = @selector(doOpenFork:);
            break;
        case kFPCloseFork:
            sSelector = @selector(doCloseFork:);
            break;
        case kFPGetForkParms:
            sSelector = @selector(doGetForkParms:);
            break;
        case kFPSetForkParms:
            sSelector = @selector(doSetForkParms:);
            break;
        case kFPReadExt:
            sSelector = @selector(doReadExt:);
            break;
        case kFPWriteExt:
            sSelector = @selector(doWriteExt:);
            break;
        case kFPByteRangeLockExt:
            sSelector = @selector(doByteRangeLockExt:);
            break;
        case kFPFlushFork:
            sSelector = @selector(doFlushFork:);
            break;

        default:
            sSelector = NULL;
            break;
    }

    return sSelector;
}


- (void)handleMessage:(AFPMessage *)aMessage
{
    SEL sSelector = [self selectorForMessage:aMessage];

    if (sSelector)
    {
        [self performSelector:sSelector onThread:self withObject:aMessage waitUntilDone:NO];
    }
    else
    {
        [aMessage setReplyResult:kFPCallNotSupported withBlock:nil];
        [mConnection replyMessage:aMessage];
    }
}


#pragma mark -
#pragma mark Managing Open Forks


- (int16_t)nextForkID
{
    int16_t sNextForkID;

    @synchronized(self)
    {
        do
        {
            sNextForkID = ++mLastForkID;

            if (sNextForkID <= 0)
            {
                sNextForkID = 1;
                mLastForkID = 1;
            }
        } while ([mUsedForkIDs containsObject:[NSNumber numberWithInt:sNextForkID]]);
    }

    return sNextForkID;
}


- (AFPOpenFork *)addForkWithFile:(AFPFile *)aFile flag:(uint8_t)aFlag accessMode:(int16_t)aAccessMode
{
    int16_t      sNextForkID;
    NSNumber    *sForkID;
    AFPOpenFork *sFork = nil;

    @synchronized(self)
    {
        do
        {
            sNextForkID = ++mLastForkID;

            if (sNextForkID <= 0)
            {
                sNextForkID = 1;
                mLastForkID = 1;
            }

            sForkID = [NSNumber numberWithInt:sNextForkID];
        } while ([mUsedForkIDs containsObject:sForkID]);

        if (sForkID)
        {
            sFork = [[AFPOpenFork alloc] initWithFile:aFile flag:aFlag accessMode:aAccessMode forkID:sNextForkID];

            [mForksByID setObject:sFork forKey:sForkID];
            [mUsedForkIDs addObject:sForkID];
        }
    }

    return [sFork autorelease];
}


- (void)removeFork:(AFPOpenFork *)aFork
{
    NSNumber *sForkID = [NSNumber numberWithInt:[aFork forkID]];

    @synchronized(self)
    {
        [mForksByID removeObjectForKey:sForkID];
        [mUsedForkIDs removeObject:sForkID];
    }
}


#pragma mark -
#pragma mark Session Main RunLoop


- (void)main
{
    NSAutoreleasePool *sPool = [[NSAutoreleasePool alloc] init];

#if LOG_LIFECYCLE
    NSLog(@"AFPSession starting runloop");
#endif

    [self performSelector:@selector(self) onThread:self withObject:nil waitUntilDone:NO];

    while (!mStop)
    {
        if (![[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]])
        {
            break;
        }
    }

#if LOG_LIFECYCLE
    NSLog(@"AFPSession stopped runloop");
#endif

    [sPool drain];
}


@end
