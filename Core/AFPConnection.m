/*
 *  AFPConnection.m
 *  MRFS
 *
 *  Created by han9kin on 2011-04-12.
 *
 */

#import "NSMutableData+Additions.h"
#import "AFPMessage.h"
#import "AFPSession.h"
#import "AFPConnection.h"
#import "AFPListener.h"
#import "AFPDHXContext.h"


#ifndef LOG_OFF
#define LOG_LIFECYCLE   0
#define LOG_STREAMEVENT 0
#define LOG_AFPMESSAGE  1
#endif


#define kTickleTimerInterval 5
#define kTickleTimeout       26


@implementation AFPConnection


+ (NSArray *)supportedAFPVersions
{
    return [NSArray arrayWithObjects:@kAFPVersion_3_2, nil];
}


+ (NSArray *)supportedUAMs
{
    return [NSArray arrayWithObjects:@kDHCAST128UAMStr, @kDHX2UAMStr, nil];
}


- (id)initWithFileHandle:(NSFileHandle *)aFileHandle listener:(AFPListener *)aListener
{
    self = [super init];

    if (self)
    {
        mListener        = [aListener retain];
        mLoginContext    = [[AFPDHXContext alloc] init];
        mFileHandle      = [aFileHandle retain];
        mSendingMessages = [[NSMutableArray alloc] init];

        [self start];
    }

    return self;
}


- (void)dealloc
{
#if LOG_LIFECYCLE
    NSLog(@"AFPConnection deallocated");
#endif
    [mLoginContext release];
    [mListener release];
    [mSendingMessages release];
    [mFileHandle release];
    [super dealloc];
}


- (AFPListener *)listener
{
    return mListener;
}


#pragma mark -
#pragma mark Running Event-Loop


- (void)stop
{
    if ([NSThread currentThread] == self)
    {
#if LOG_LIFECYCLE
        NSLog(@"AFPConnection stop");
#endif

        mStop = YES;

        [mInputStream close];
        [mOutputStream close];

        if (mSession)
        {
            [mSession setConnection:nil];
            [mListener pushIdleSession:mSession];
        }
    }
    else
    {
        [self performSelector:_cmd onThread:self withObject:nil waitUntilDone:NO];
    }
}


- (void)shutdown
{
    if ([NSThread currentThread] == self)
    {
        NSLog(@"AFPConnection sending shutdown attention");

        [self sendAttention:kShutDownNotifyMask];
        [self stop];
    }
    else
    {
        [self performSelector:_cmd onThread:self withObject:nil waitUntilDone:NO];
    }
}


#pragma mark -
#pragma mark Writing Messages


- (uint16_t)nextRequestID
{
    uint16_t sRequestID;

    @synchronized(self)
    {
        sRequestID = ++mLastRequestID;

        if (sRequestID == 0)
        {
            sRequestID     = 1;
            mLastRequestID = 1;
        }
    }

    return sRequestID;
}


- (void)sendMessage:(AFPMessage *)aMessage
{
#if LOG_AFPMESSAGE
    NSLog(@"AFPConnection sending message: %@", aMessage);
#endif

    @synchronized(mOutputStream)
    {
        [aMessage writeOnStream:mOutputStream];

        mLastSentTime = [NSDate timeIntervalSinceReferenceDate];
    }
}


- (void)sendTickle
{
    DSIHeader   sHeader;
    AFPMessage *sMessage;

    sHeader.command     = kDSITickle;
    sHeader.requestID   = [self nextRequestID];

    sMessage = [[AFPMessage alloc] initWithHeader:&sHeader payload:nil];
    [sMessage setRequestBlock:nil];

    [self sendMessage:sMessage];

    [sMessage release];
}


- (void)sendAttention:(uint16_t)aUserBytes
{
    DSIHeader      sHeader;
    NSMutableData *sBlock;
    AFPMessage    *sMessage;

    sHeader.command     = kDSIAttention;
    sHeader.requestID   = [self nextRequestID];

    sBlock = [[NSMutableData alloc] init];
    [sBlock appendUInt16:aUserBytes];

    sMessage = [[AFPMessage alloc] initWithHeader:&sHeader payload:nil];
    [sMessage setRequestBlock:sBlock];

    [self sendMessage:sMessage];

    [sBlock release];
    [sMessage release];
}


- (BOOL)replyQueuedMessage
{
    AFPMessage *sMessage = nil;

    @synchronized(mSendingMessages)
    {
        if ([mSendingMessages count])
        {
            sMessage = [[mSendingMessages objectAtIndex:0] retain];

            [mSendingMessages removeObjectAtIndex:0];
        }
    }

    if (sMessage)
    {
        [self sendMessage:sMessage];

        if (!mSession && ([sMessage dsiCommand] == kDSIGetStatus))
        {
            mTearDown = YES;
        }

        [sMessage release];

        return YES;
    }
    else
    {
        return NO;
    }
}


- (void)replyMessage:(AFPMessage *)aMessage
{
    @synchronized(mSendingMessages)
    {
        [mSendingMessages addObject:aMessage];
    }

    if ([mOutputStream hasSpaceAvailable])
    {
        [self replyQueuedMessage];
    }
}


#pragma mark -
#pragma mark Analyzing Protocol


- (void)analyzeMessage
{
    AFPMessage *sMessage = [[[AFPMessage alloc] initWithHeader:&mReceivedHeader payload:mReceivedPayload] autorelease];

#if LOG_AFPMESSAGE
    NSLog(@"AFPConnection received message: %@", sMessage);
#endif

    SEL sSelector = NULL;

    switch (mReceivedHeader.command)
    {
        case kDSIAttention:
        case kDSITickle:
            break;

        case kDSIGetStatus:
            sSelector = @selector(doGetSrvrInfo:);
            break;

        case kDSIOpenSession:
            sSelector = @selector(doOpenSession:);
            break;

        case kDSICloseSession:
            sSelector = @selector(doCloseSession:);
            break;

        case kDSICommand:
        case kDSIWrite:
            switch (*mReceivedPayload)
            {
                case kFPLoginExt:
                    if (mLoginContext)
                    {
                        if ([mLoginContext contextID]) /* login process is in progress */
                        {
                            [sMessage setReplyResult:kFPNoMoreSessions withBlock:nil];
                            [self replyMessage:sMessage];
                        }
                        else /* ok to proceed */
                        {
                            sSelector = @selector(doLoginExt:);
                        }
                    }
                    else /* already logged in */
                    {
                        [sMessage setReplyResult:kFPMiscErr withBlock:nil];
                        [self replyMessage:sMessage];
                    }
                    break;

                case kFPLoginCont:
                    if (mLoginContext)
                    {
                        if ([mLoginContext contextID]) /* ok to proceed */
                        {
                            sSelector = @selector(doLoginCont:);
                        }
                        else /* login process is not started */
                        {
                            [sMessage setReplyResult:kFPParamErr withBlock:nil];
                            [self replyMessage:sMessage];
                        }
                    }
                    else /* already logged in */
                    {
                        [sMessage setReplyResult:kFPMiscErr withBlock:nil];
                        [self replyMessage:sMessage];
                    }
                    break;

                case kFPGetUserInfo:
                    if (mLoginContext)
                    {
                        [sMessage setReplyResult:kFPParamErr withBlock:nil];
                        [self replyMessage:sMessage];
                    }
                    else
                    {
                        sSelector = @selector(doGetUserInfo:);
                    }
                    break;

                case kFPLogout:
                    sSelector = @selector(doLogout:);
                    break;
                case kFPGetSrvrParms:
                    sSelector = @selector(doGetSrvrParms:);
                    break;
                case kFPGetSrvrMsg:
                    sSelector = @selector(doGetSrvrMsg:);
                    break;
                case kFPGetSessionToken:
                    sSelector = @selector(doGetSessionToken:);
                    break;
                case kFPDisconnectOldSession:
                    sSelector = @selector(doDisconnectOldSession:);
                    break;

                default:
                    if (!mSession && !mLoginContext)
                    {
                        mSession = [[[AFPSession alloc] init] autorelease];
                        [mSession setConnection:self];
                    }

                    if (mSession)
                    {
                        [mSession handleMessage:sMessage];
                    }
                    else
                    {
                        [sMessage setReplyResult:kFPParamErr withBlock:nil];
                        [self replyMessage:sMessage];
                    }
                    break;
            }
            break;
    }

    if (sSelector)
    {
        [self performSelector:sSelector withObject:sMessage];
    }

    mHeaderReady     = NO;
    mReceivedLength  = 0;
    mReceivedPayload = NULL;
}


- (void)readPayload
{
    if (!mReceivedPayload)
    {
        mReceivedPayload = malloc(mReceivedHeader.totalDataLength);
    }

    NSInteger sReadSize;

    sReadSize = [mInputStream read:(mReceivedPayload + mReceivedLength) maxLength:(mReceivedHeader.totalDataLength - mReceivedLength)];

    if (sReadSize > 0)
    {
        mReceivedLength += sReadSize;

        if (mReceivedLength == mReceivedHeader.totalDataLength)
        {
            [self analyzeMessage];
        }
    }
}


- (void)analyzeHeader
{
    DSIHeaderConvertToHostByteOrder(&mReceivedHeader);

    if (mReceivedHeader.totalDataLength)
    {
        mHeaderReady    = YES;
        mReceivedLength = 0;

        if ([mInputStream hasBytesAvailable])
        {
            [self readPayload];
        }
    }
    else
    {
        [self analyzeMessage];
    }
}


- (void)readHeader
{
    NSInteger sReadSize;

    sReadSize = [mInputStream read:((uint8_t *)&mReceivedHeader + mReceivedLength) maxLength:(sizeof(mReceivedHeader) - mReceivedLength)];

    if (sReadSize > 0)
    {
        mReceivedLength += sReadSize;

        if (mReceivedLength == sizeof(mReceivedHeader))
        {
            [self analyzeHeader];
        }
    }
}


- (void)readBytes
{
    if (mHeaderReady)
    {
        [self readPayload];
    }
    else
    {
        [self readHeader];
    }
}


#pragma mark -
#pragma mark Running Event-Loop


- (void)tickleTimerFired:(NSTimer *)aTimer
{
    if (([NSDate timeIntervalSinceReferenceDate] - mLastSentTime) > kTickleTimeout)
    {
        [self sendTickle];
    }
}


- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)aStreamEvent
{
    switch (aStreamEvent)
    {
        case NSStreamEventNone:
#if LOG_STREAMEVENT
            NSLog(@"AFPConnection received stream event NSStreamEventNone (%@)", aStream);
#endif
            break;

        case NSStreamEventOpenCompleted:
#if LOG_STREAMEVENT
            NSLog(@"AFPConnection received stream event NSStreamEventOpenCompleted (%@)", aStream);
#endif
            break;

        case NSStreamEventHasBytesAvailable:
#if LOG_STREAMEVENT
            NSLog(@"AFPConnection received stream event NSStreamEventHasBytesAvailable (%@)", aStream);
#endif
            [self readBytes];
            break;

        case NSStreamEventHasSpaceAvailable:
#if LOG_STREAMEVENT
            NSLog(@"AFPConnection received stream event NSStreamEventHasSpaceAvailable (%@)", aStream);
#endif
            if ([self replyQueuedMessage])
            {
                /* continue */
            }
            else
            {
                if (mTearDown)
                {
                    if (mSession)
                    {
                        mTearDown = NO;
                    }
                    else
                    {
                        [self stop];
                    }
                }
            }
            break;

        case NSStreamEventErrorOccurred:
#if LOG_STREAMEVENT
            NSLog(@"AFPConnection received stream event NSStreamEventErrorOccurred (%@) %@", aStream, [aStream streamError]);
#endif
            [self stop];
            break;

        case NSStreamEventEndEncountered:
#if LOG_STREAMEVENT
            NSLog(@"AFPConnection received stream event NSStreamEventEndEncountered (%@)", aStream);
#endif
            [self stop];
            break;
    }
}


- (void)main
{
    NSAutoreleasePool *sPool = [[NSAutoreleasePool alloc] init];
    NSTimer           *sTimer;

#if LOG_LIFECYCLE
    NSLog(@"AFPConnection starting runloop");
#endif

    [mListener addConnection:self];

    CFStreamCreatePairWithSocket(NULL, [mFileHandle fileDescriptor], (CFReadStreamRef *)&mInputStream, (CFWriteStreamRef *)&mOutputStream);

    [mInputStream setDelegate:self];
    [mOutputStream setDelegate:self];
    [mInputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [mOutputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [mInputStream open];
    [mOutputStream open];

    sTimer = [NSTimer scheduledTimerWithTimeInterval:kTickleTimerInterval target:self selector:@selector(tickleTimerFired:) userInfo:nil repeats:YES];

    while (!mStop)
    {
        if (![[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]])
        {
            break;
        }
    }

    [sTimer invalidate];

    [mInputStream release];
    [mOutputStream release];

    [mListener removeConnection:self];

#if LOG_LIFECYCLE
    NSLog(@"AFPConnection stopped runloop");
#endif

    [sPool drain];
}


@end
