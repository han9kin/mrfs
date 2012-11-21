/*
 *  AppDelegate.h
 *  MRFS
 *
 *  Created by han9kin on 2011-04-12.
 *
 */

#import <Cocoa/Cocoa.h>
#import <MRFS/MRFS.h>


@interface AppDelegate : NSObject
{
    NSWindow       *mWindow;

    MRFSServer     *mServer;
    NSMutableArray *mFileSystems;
}

@property(assign)   IBOutlet NSWindow *window;

@property(readonly) MRFSServer        *server;
@property(readonly) NSArray           *fileSystems;


- (IBAction)start:(id)aSender;
- (IBAction)stop:(id)aSender;


@end
