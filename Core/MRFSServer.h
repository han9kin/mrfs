/*
 *  MRFSServer.h
 *  MRFS
 *
 *  Created by han9kin on 2011-04-26.
 *
 */

#import <Foundation/Foundation.h>
#import <DiskArbitration/DiskArbitration.h>


@class AFPServer;
@class AFPListener;


@interface MRFSServer : NSObject
{
    AFPServer    *mServer;
    AFPListener  *mListener;
    NSMutableSet *mVolumes;

    NSString     *mUserName;

    DASessionRef  mDASession;

    BOOL          mStatisticsMonitoring;
}


#pragma mark -
#pragma mark Configuring Properties


- (uint32_t)maxReqSize;
- (void)setMaxReqSize:(uint32_t)aSize;

- (BOOL)supportsCopyFile;
- (void)setSupportsCopyFile:(BOOL)aSupport;

- (NSString *)machineType;
- (void)setMachineType:(NSString *)aMachineType;

- (NSString *)serverName;
- (void)setServerName:(NSString *)aServerName;

- (NSString *)UTF8ServerName;
- (void)setUTF8ServerName:(NSString *)aUTF8ServerName;

- (NSString *)userName;
- (void)setUserName:(NSString *)aUserName;

- (BOOL)showsMountedVolumesOnly;
- (void)setShowsMountedVolumesOnly:(BOOL)aShowsMountedVolumesOnly;


#pragma mark -
#pragma mark Running the Server


- (BOOL)start:(NSError **)aError;
- (void)stop;


#pragma mark -
#pragma mark Getting the Server Statistics


- (BOOL)isStatisticsMonitoringEnabled;
- (void)setStatisticsMonitoringEnabled:(BOOL)aEnabled;

- (NSUInteger)activeConnectionCount;
- (NSUInteger)idleSessionCount;


@end
