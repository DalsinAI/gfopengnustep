/* Executable guest smoke for real GFOS Exec-backed GNUstep NSMessagePort.
 * Built and linked on daletop; guest execution is a separate gate.
 */
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <Foundation/NSPortNameServer.h>
#import "GFOSNSMessagePort.h"
#include <string.h>
#include <stdio.h>

int main(int argc, char **argv)
{
    char *gfos_environment[] = { NULL };
    GSInitializeProcess(argc, argv, gfos_environment);
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSMessagePort *listener = [[NSMessagePort alloc] init];
    NSMessagePort *replies = [[NSMessagePort alloc] init];
    NSMessagePortNameServer *names = [NSMessagePortNameServer sharedInstance];
    NSString *name = [NSString stringWithUTF8String:"GFOS.FOUNDATION.IPC.SMOKE"];
    NSData *payload = [NSData dataWithBytes:"ping" length:4];
    NSPortMessage *received = nil;
    BOOL ok = [names registerPort:listener forName:name];
    if (!ok) goto cleanup;
    if (![names portForName:name]) { ok = NO; goto cleanup; }
    ok = [listener sendBeforeDate:[NSDate dateWithTimeIntervalSinceNow:5]
                           msgid:77
                      components:[NSMutableArray arrayWithObject:payload]
                            from:replies
                        reserved:0];
    if (!ok) goto cleanup;
    received = [listener gfosPollMessage];
    ok = received != nil && [received msgid] == 77 &&
         [[received components] count] == 1 &&
         [[[received components] objectAtIndex:0] isEqualToData:payload] &&
         [replies gfosPollAcknowledgements] == 1;
cleanup:
    if (ok) ok = [names removePortForName:name];
    else [names removePortForName:name];
    [listener invalidate];
    [replies invalidate];
    [listener release];
    [replies release];
    puts(ok ? "GFOS_FOUNDATION_IPC_PASS" : "GFOS_FOUNDATION_IPC_FAIL");
    [pool drain];
    return ok ? 0 : 2;
}
