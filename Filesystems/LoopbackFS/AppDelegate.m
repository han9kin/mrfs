/*
 *  AppDelegate.m
 *  MRFS
 *
 *  Created by han9kin on 2011-04-12.
 *
 */

#import "AppDelegate.h"
#import "LoopbackFileSystem.h"


@implementation AppDelegate


@synthesize window      = mWindow;
@synthesize server      = mServer;
@synthesize fileSystems = mFileSystems;


- (void)setupFileSystems
{
    NSFileManager *sFileManager = [[NSFileManager alloc] init];

    for (NSString *sName in [sFileManager contentsOfDirectoryAtPath:NSHomeDirectory() error:NULL])
    {
        if (![sName hasPrefix:@"."])
        {
            NSString *sPath = [NSHomeDirectory() stringByAppendingPathComponent:sName];

            if ([[[sFileManager attributesOfItemAtPath:sPath error:NULL] fileType] isEqualToString:NSFileTypeDirectory] &&
                ![[NSWorkspace sharedWorkspace] isFilePackageAtPath:sPath])
            {
                LoopbackFileSystem *sFileSystem;

                sFileSystem = [[LoopbackFileSystem alloc] initWithName:[sFileManager displayNameAtPath:sPath] path:sPath server:mServer];
                [mFileSystems addObject:sFileSystem];
                [sFileSystem release];
            }
        }
    }

    [sFileManager release];

    [mFileSystems sortUsingDescriptors:[NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES selector:@selector(localizedCompare:)] autorelease]]];
}


- (id)init
{
    self = [super init];

    if (self)
    {
        mServer      = [[MRFSServer alloc] init];
        mFileSystems = [[NSMutableArray alloc] init];

        [mServer setServerName:@"LoopbackFS"];
        [mServer setStatisticsMonitoringEnabled:YES];

        [self setupFileSystems];
    }

    return self;
}


#pragma mark -
#pragma mark NSApplicationDelegate


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self start:nil];
}


- (BOOL)applicationShouldHandleReopen:(NSApplication *)aApplication hasVisibleWindows:(BOOL)aFlag
{
    if (!aFlag)
    {
        [mWindow makeKeyAndOrderFront:nil];
    }

    return YES;
}


- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [mFileSystems release];
    [mServer stop];
    [mServer release];
}


#pragma mark -
#pragma mark Actions


- (IBAction)start:(id)aSender
{
    NSError *sError;

    if (![mServer start:&sError])
    {
        [[NSApplication sharedApplication] presentError:sError];
    }
}


- (IBAction)stop:(id)aSender
{
    [mServer stop];
}


- (void)mountFileSystem:(LoopbackFileSystem *)aFileSystem
{
    if (![aFileSystem isMounted])
    {
        [[aFileSystem volume] mountAtPath:nil];
    }
}


@end
