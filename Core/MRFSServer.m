/*
 *  MRFSServer.m
 *  MRFS
 *
 *  Created by han9kin on 2011-04-26.
 *
 */

#import "AFPListener.h"
#import "AFPServer.h"
#import "MRFSServer.h"
#import "MRFSVolume.h"
#import "MRFSPrivates.h"


@implementation MRFSServer


- (id)init
{
    self = [super init];

    if (self)
    {
        mServer   = [[AFPServer alloc] init];
        mListener = [[AFPListener alloc] initWithServer:mServer];
        mVolumes  = [[NSMutableSet alloc] init];

        [self setupDiskArbitration];
    }

    return self;
}


- (void)dealloc
{
    if (mStatisticsMonitoring)
    {
        [mListener removeObserver:self forKeyPath:@"activeConnectionCount"];
        [mListener removeObserver:self forKeyPath:@"idleSessionCount"];
    }

    [self finalizeDiskArbitration];
    [mListener release];
    [mServer release];
    [mVolumes release];
    [mUserName release];
    [super dealloc];
}


#pragma mark -
#pragma mark Configuring Properties


- (uint32_t)maxReqSize
{
    return [mServer maxReqSize];
}


- (void)setMaxReqSize:(uint32_t)aSize
{
    [mServer setMaxReqSize:aSize];
}


- (BOOL)supportsCopyFile
{
    return [mServer supportsCopyFile];
}


- (void)setSupportsCopyFile:(BOOL)aSupportsCopyFile
{
    [mServer setSupportsCopyFile:aSupportsCopyFile];
}


- (NSString *)machineType
{
    return [mServer machineType];
}


- (void)setMachineType:(NSString *)aMachineType
{
    [mServer setMachineType:aMachineType];
}


- (NSString *)serverName
{
    return [mServer serverName];
}


- (void)setServerName:(NSString *)aServerName
{
    [mServer setServerName:aServerName];
}


- (NSString *)UTF8ServerName
{
    return [mServer UTF8ServerName];
}


- (void)setUTF8ServerName:(NSString *)aUTF8ServerName
{
    [mServer setUTF8ServerName:aUTF8ServerName];
}


- (NSString *)userName
{
    return mUserName ? mUserName : NSUserName();
}


- (void)setUserName:(NSString *)aUserName
{
    [mUserName autorelease];
    mUserName = [aUserName copy];
}


- (BOOL)showsMountedVolumesOnly
{
    return [mServer showsMountedVolumesOnly];
}


- (void)setShowsMountedVolumesOnly:(BOOL)aShowsMountedVolumesOnly
{
    [mServer setShowsMountedVolumesOnly:aShowsMountedVolumesOnly];
}


#pragma mark -
#pragma mark Running the Server


- (BOOL)start:(NSError **)aError
{
    return [mListener start:aError];
}


- (void)stop
{
    [mListener stop];
}


#pragma mark -
#pragma mark Getting the Server Status


- (BOOL)isStatisticsMonitoringEnabled
{
    return mStatisticsMonitoring;
}


- (void)setStatisticsMonitoringEnabled:(BOOL)aEnabled
{
    if (mStatisticsMonitoring != aEnabled)
    {
        mStatisticsMonitoring = aEnabled;

        [mListener setStatisticsMonitoringEnabled:mStatisticsMonitoring];

        if (mStatisticsMonitoring)
        {
            [mListener addObserver:self forKeyPath:@"activeConnectionCount" options:0 context:NULL];
            [mListener addObserver:self forKeyPath:@"idleSessionCount" options:0 context:NULL];
        }
        else
        {
            [mListener removeObserver:self forKeyPath:@"activeConnectionCount"];
            [mListener removeObserver:self forKeyPath:@"idleSessionCount"];
        }
    }
}


- (NSUInteger)activeConnectionCount
{
    return [mListener activeConnectionCount];
}


- (NSUInteger)idleSessionCount
{
    return [mListener idleSessionCount];
}


- (void)observeValueForKeyPath:(NSString *)aKeyPath ofObject:(id)aObject change:(NSDictionary *)aChange context:(void *)aContext
{
    [self willChangeValueForKey:aKeyPath];
    [self didChangeValueForKey:aKeyPath];
}


@end
