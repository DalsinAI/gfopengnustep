/* Experimental GFOS-native GNUstep Base NSMessagePortNameServer.
 * LGPL-2.0-or-later. Local named Exec ports; no distributed remoting.
 */
#import <Foundation/NSPortNameServer.h>
#import <Foundation/NSPort.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSLock.h>

#define BOOL GFOS_ExecBOOL
#include "gfos_transport.h"
#undef BOOL

#import "GFOSNSMessagePort.h"

@implementation NSMessagePortNameServer
static NSMessagePortNameServer *gfosSharedServer;
static NSRecursiveLock *gfosRegistrationLock;
static NSMutableDictionary *gfosLocalNames;

+ (void)initialize
{
    if (self == [NSMessagePortNameServer class]) {
        gfosRegistrationLock = [NSRecursiveLock new];
        gfosLocalNames = [NSMutableDictionary new];
    }
}

+ (id)sharedInstance
{
    [gfosRegistrationLock lock];
    if (!gfosSharedServer) {
        /* NSPortNameServer intentionally forbids ordinary +alloc/+new.
         * Match GNUstep's original singleton construction strategy. */
        gfosSharedServer = (NSMessagePortNameServer *)
            NSAllocateObject(self, 0, NSDefaultMallocZone());
    }
    [gfosRegistrationLock unlock];
    return gfosSharedServer;
}

- (NSPort *)portForName:(NSString *)name
{
    return [self portForName:name onHost:nil];
}

- (NSPort *)portForName:(NSString *)name onHost:(NSString *)host
{
    NSMessagePort *result;
    if (!name || ![name length] || (host && [host length])) return nil;
    [gfosRegistrationLock lock];
    result = [gfosLocalNames objectForKey:name];
    if (result) {
        [[result retain] autorelease];
        [gfosRegistrationLock unlock];
        return result;
    }
    if (!gfos_port_name_exists([name UTF8String])) {
        [gfosRegistrationLock unlock];
        return nil;
    }
    result = [[NSMessagePort alloc] initWithGFOSRemoteName:name];
    [gfosRegistrationLock unlock];
    return [result autorelease];
}

- (BOOL)registerPort:(NSPort *)port forName:(NSString *)name
{
    BOOL ok;
    if (!name || ![name length] || ![port isKindOfClass:[NSMessagePort class]])
        return NO;
    [gfosRegistrationLock lock];
    ok = ![gfosLocalNames objectForKey:name] &&
         [(NSMessagePort *)port gfosPublishName:name];
    if (ok) [gfosLocalNames setObject:port forKey:name];
    [gfosRegistrationLock unlock];
    return ok;
}

- (BOOL)removePortForName:(NSString *)name
{
    NSMessagePort *port;
    BOOL ok;
    if (!name) return NO;
    [gfosRegistrationLock lock];
    port = [gfosLocalNames objectForKey:name];
    ok = port && [port gfosUnpublishName];
    if (ok) [gfosLocalNames removeObjectForKey:name];
    [gfosRegistrationLock unlock];
    return ok;
}
@end
