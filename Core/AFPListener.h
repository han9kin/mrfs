/*
 *  AFPListener.h
 *  MRFS
 *
 *  Created by han9kin on 2011-04-12.
 *
 */

#import <Foundation/Foundation.h>
#import <dns_sd.h>


@class AFPServer;
@class AFPSession;


@interface AFPListener : NSObject
{
    AFPServer      *mServer;
    NSMutableArray *mConnections;
    NSMutableArray *mIdleSessions;

    NSFileHandle   *mHandle;
    DNSServiceRef   mNameService;

    NSString       *mPassword;
    NSString       *mHost;
    unsigned short  mPort;

    BOOL            mStatisticsMonitoring;
}


- (id)initWithServer:(AFPServer *)aServer;


- (AFPServer *)server;


- (BOOL)start:(NSError **)aError;
- (void)stop;


- (NSString *)password;
- (NSString *)host;
- (uint32_t)address4;
- (unsigned short)port;


- (BOOL)isStatisticsMonitoringEnabled;
- (void)setStatisticsMonitoringEnabled:(BOOL)aEnabled;

- (NSUInteger)activeConnectionCount;
- (NSUInteger)idleSessionCount;


- (void)addConnection:(id)aConnection;
- (void)removeConnection:(id)aConnection;


- (void)pushIdleSession:(AFPSession *)aSession;
- (AFPSession *)popIdleSessionWithToken:(NSString *)aSessionToken;
- (void)discardIdleSessionsWithClientID:(NSData *)aClientID;


@end
