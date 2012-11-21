/*
 *  AFPListener.m
 *  MRFS
 *
 *  Created by han9kin on 2011-04-12.
 *
 */

#import <unistd.h>
#import <sys/socket.h>
#import <sys/types.h>
#import <netinet/in.h>
#import <netinet/tcp.h>
#import "AFPSession.h"
#import "AFPConnection.h"
#import "AFPListener.h"
#import "AFPServer.h"
#import "AFPVolume.h"


#ifndef LOG_OFF
#define LOG_LIFECYCLE 0
#endif


@interface AFPListener (Private)
@end


@implementation AFPListener (Private)


void AFPDNSServiceRegisterRecordReply(DNSServiceRef aNameService, DNSRecordRef aRecord, DNSServiceFlags aFlags, DNSServiceErrorType aErrorCode, void *aContext)
{
    if (aErrorCode)
    {
        NSLog(@"Name Service Registration failed (%d)", aErrorCode);
    }
}


- (BOOL)startListening:(NSError **)aError
{
    struct sockaddr_in sAddress;
    socklen_t          sAddrLen;
    int                sSocket;
    int                sFlag;
    int                sRet;

    /*
     * socket
     */
    sSocket = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);

    if (sSocket < 0)
    {
        if (aError)
        {
            *aError = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        }

        return NO;
    }

    /*
     * socket options
     */
    sFlag = 1;
    setsockopt(sSocket, IPPROTO_TCP, TCP_NODELAY, &sFlag, sizeof(sFlag));

    /*
     * bind
     */
    memset(&sAddress, 0, sizeof(sAddress));

    sAddress.sin_len = sizeof(sAddress);
    sAddress.sin_family = AF_INET;
    sAddress.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    sAddress.sin_port = htons(0);

    sRet = bind(sSocket, (struct sockaddr *)&sAddress, sizeof(sAddress));

    if (sRet < 0)
    {
        if (aError)
        {
            *aError = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        }

        close(sSocket);

        return NO;
    }

    /*
     * listen
     */
    sRet = listen(sSocket, 10);

    if (sRet < 0)
    {
        if (aError)
        {
            *aError = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        }

        close(sSocket);

        return NO;
    }

    /*
     * get listening port
     */
    sAddrLen = sizeof(sAddress);

    sRet = getsockname(sSocket, (struct sockaddr *)&sAddress, &sAddrLen);

    if (sRet < 0)
    {
        if (aError)
        {
            *aError = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        }

        close(sSocket);

        return NO;
    }

    mPort = ntohs(sAddress.sin_port);

    NSLog(@"listening from port: %d", mPort);

    /*
     * wait for connection
     */
    mHandle = [[NSFileHandle alloc] initWithFileDescriptor:sSocket closeOnDealloc:YES];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionAccepted:) name:NSFileHandleConnectionAcceptedNotification object:mHandle];

    [mHandle acceptConnectionInBackgroundAndNotify];

    return YES;
}


- (void)stopListening
{
#if LOG_LIFECYCLE
    NSLog(@"AFPListener stop");
#endif
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [mHandle release];
    mHandle = nil;

    [mConnections makeObjectsPerformSelector:@selector(shutdown)];
    [mIdleSessions makeObjectsPerformSelector:@selector(stop)];
}


- (BOOL)registerNameService:(NSError **)aError
{
    DNSServiceErrorType sResult;

    sResult = DNSServiceCreateConnection(&mNameService);

    if (!sResult)
    {
        DNSRecordRef   sRecord;
        struct in_addr sAddress;

        sAddress.s_addr = htonl(INADDR_LOOPBACK);

        [mHost autorelease];
        mHost = [[[mServer serverName] stringByAppendingString:@".mrfs.local"] copy];

        sResult = DNSServiceRegisterRecord(mNameService,
                                           &sRecord,
                                           kDNSServiceFlagsUnique,
                                           kDNSServiceInterfaceIndexLocalOnly,
                                           [mHost UTF8String],
                                           kDNSServiceType_A,
                                           kDNSServiceClass_IN,
                                           sizeof(sAddress),
                                           &sAddress,
                                           0,
                                           AFPDNSServiceRegisterRecordReply,
                                           NULL);

        if (!sResult)
        {
            sResult = DNSServiceProcessResult(mNameService);
        }
    }

    if (sResult)
    {
        *aError = [NSError errorWithDomain:@"DNSServiceErrorDomain" code:sResult userInfo:nil];

        if (mNameService)
        {
            DNSServiceRefDeallocate(mNameService);

            mNameService = NULL;
        }

        return NO;
    }
    else
    {
        return YES;
    }
}


- (void)unregisterNameService
{
    if (mNameService)
    {
        DNSServiceRefDeallocate(mNameService);

        mNameService = NULL;
    }
}


@end


@implementation AFPListener


- (id)initWithServer:(AFPServer *)aServer
{
    self = [super init];

    if (self)
    {
        mServer       = [aServer retain];
        mConnections  = [[NSMutableArray alloc] init];
        mIdleSessions = [[NSMutableArray alloc] init];

        CFUUIDRef sUUID = CFUUIDCreate(NULL);
        mPassword = NSMakeCollectable(CFUUIDCreateString(NULL, sUUID));
        CFRelease(sUUID);

        NSLog(@"password: %@", mPassword);
    }

    return self;
}


- (void)dealloc
{
#if LOG_LIFECYCLE
    NSLog(@"AFPListener deallocated");
#endif
    [self stopListening];
    [self unregisterNameService];
    [mServer release];
    [mConnections release];
    [mIdleSessions release];
    [mPassword release];
    [mHost release];
    [super dealloc];
}


- (AFPServer *)server
{
    return mServer;
}


- (BOOL)start:(NSError **)aError
{
    if (mHandle)
    {
        return YES;
    }

    if ([self startListening:aError])
    {
        return [self registerNameService:aError];
    }
    else
    {
        return NO;
    }
}


- (void)stop
{
    [self stopListening];
    [self unregisterNameService];
}


- (NSString *)password
{
    return mPassword;
}


- (NSString *)host;
{
    return mHost;
}


- (uint32_t)address4
{
    return INADDR_LOOPBACK;
}


- (unsigned short)port
{
    return mPort;
}


- (BOOL)isStatisticsMonitoringEnabled
{
    return mStatisticsMonitoring;
}


- (void)setStatisticsMonitoringEnabled:(BOOL)aEnabled
{
    mStatisticsMonitoring = aEnabled;
}


- (NSUInteger)activeConnectionCount
{
    NSUInteger sCount;

    @synchronized(mConnections)
    {
        sCount = [mConnections count];
    }

    return sCount;
}


- (NSUInteger)idleSessionCount
{
    NSUInteger sCount;

    @synchronized(mIdleSessions)
    {
        sCount = [mIdleSessions count];
    }

    return sCount;
}


- (void)addConnection:(id)aConnection
{
    @synchronized(mConnections)
    {
        [mConnections addObject:aConnection];
    }

    if (mStatisticsMonitoring)
    {
        [self willChangeValueForKey:@"activeConnectionCount"];
        [self didChangeValueForKey:@"activeConnectionCount"];
    }
}


- (void)removeConnection:(id)aConnection
{
    @synchronized(mConnections)
    {
        [mConnections removeObject:aConnection];
    }

    if (mStatisticsMonitoring)
    {
        [self willChangeValueForKey:@"activeConnectionCount"];
        [self didChangeValueForKey:@"activeConnectionCount"];
    }
}


- (void)pushIdleSession:(AFPSession *)aSession
{
    @synchronized(mIdleSessions)
    {
        [mIdleSessions addObject:aSession];
    }

    if (mStatisticsMonitoring)
    {
        [self willChangeValueForKey:@"idleSessionCount"];
        [self didChangeValueForKey:@"idleSessionCount"];
    }
}


- (AFPSession *)popIdleSessionWithToken:(NSString *)aSessionToken
{
    AFPSession *sPopSession = nil;

    @synchronized(mIdleSessions)
    {
        for (AFPSession *sSession in mIdleSessions)
        {
            if ([[sSession sessionToken] isEqualToString:aSessionToken])
            {
                sPopSession = sSession;
                break;
            }
        }

        if (sPopSession)
        {
            [mIdleSessions removeObject:sPopSession];
        }
    }

    if (mStatisticsMonitoring)
    {
        [self willChangeValueForKey:@"idleSessionCount"];
        [self didChangeValueForKey:@"idleSessionCount"];
    }

    return sPopSession;
}


- (void)discardIdleSessionsWithClientID:(NSData *)aClientID
{
    @synchronized(mIdleSessions)
    {
        [mIdleSessions filterUsingPredicate:[NSPredicate predicateWithFormat:@"clientID != %@", aClientID]];
    }

    if (mStatisticsMonitoring)
    {
        [self willChangeValueForKey:@"idleSessionCount"];
        [self didChangeValueForKey:@"idleSessionCount"];
    }
}


#pragma mark -
#pragma mark NSFileHandle Notifications


- (void)connectionAccepted:(NSNotification *)aNotification
{
    if ([aNotification object] == mHandle)
    {
        NSFileHandle *sAcceptedHandle = [[aNotification userInfo] objectForKey:NSFileHandleNotificationFileHandleItem];

        if (sAcceptedHandle)
        {
            [[[AFPConnection alloc] initWithFileHandle:sAcceptedHandle listener:self] release];
        }

        [mHandle acceptConnectionInBackgroundAndNotify];
    }
}


@end
