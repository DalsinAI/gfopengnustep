/* GFOS experimental GNUstep Base NSMessagePort replacement.
 * LGPL-2.0-or-later. Actual Amiga Exec requests, not placeholder symbols.
 * Local, one NSData component only; explicit polling until NSRunLoop is wired.
 */
#import <Foundation/NSPort.h>
#import <Foundation/NSPortMessage.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>
#import <Foundation/NSLock.h>
#include <stdlib.h>
#include <string.h>
#define BOOL GFOS_ExecBOOL
#include "gfos_transport.h"
#undef BOOL

typedef struct GFOSPortState {
    GFOSPort local;
    char *remoteName;
} GFOSPortState;

#import "GFOSNSMessagePort.h"

@implementation NSMessagePort
- (id)init
{
    GFOSPortState *state;
    self = [super init];
    if (!self) return nil;
    state = (GFOSPortState *)calloc(1, sizeof(*state));
    if (!state || gfos_port_create(&state->local, NULL)) {
        free(state);
        [super dealloc];
        return nil;
    }
    _internal = state;
    _is_valid = YES;
    return self;
}

- (id)initWithGFOSRemoteName:(NSString *)name
{
    const char *raw = [name UTF8String];
    GFOSPortState *state;
    self = [self init];
    if (!self) return nil;
    state = (GFOSPortState *)_internal;
    if (!raw || !raw[0]) { [self release]; return nil; }
    state->remoteName = (char *)malloc(strlen(raw) + 1);
    if (!state->remoteName) { [self release]; return nil; }
    strcpy(state->remoteName, raw);
    return self;
}

- (BOOL)gfosPublishName:(NSString *)name
{
    GFOSPortState *state = (GFOSPortState *)_internal;
    if (!state || !_is_valid || state->remoteName) return NO;
    return gfos_port_publish(&state->local, [name UTF8String]) == 0;
}

- (BOOL)gfosUnpublishName
{
    GFOSPortState *state = (GFOSPortState *)_internal;
    if (!state || !state->local.publicPort) return NO;
    return gfos_port_unpublish(&state->local) == 0;
}

- (BOOL)sendBeforeDate:(NSDate *)when msgid:(NSInteger)msgid
            components:(NSMutableArray *)components from:(NSPort *)receivingPort
              reserved:(NSUInteger)length
{
    GFOSPortState *state = (GFOSPortState *)_internal;
    GFOSPortState *reply;
    NSData *data;
    GFOSMessage *message;
    const char *target;
    (void)length;
    if (!_is_valid || !state || [when timeIntervalSinceNow] < 0 ||
        [components count] != 1 || ![[components objectAtIndex:0] isKindOfClass:[NSData class]] ||
        ![receivingPort isKindOfClass:[NSMessagePort class]]) return NO;
    reply = (GFOSPortState *)((NSMessagePort *)receivingPort)->_internal;
    if (!reply || !reply->local.execPort) return NO;
    target = state->remoteName ? state->remoteName : state->local.name;
    if (!target) return NO;
    data = [components objectAtIndex:0];
    message = gfos_message_alloc((ULONG)[data length], (ULONG)msgid);
    if (!message) return NO;
    memcpy(message->payload, [data bytes], [data length]);
    if (gfos_port_send(target, &reply->local, message)) {
        gfos_message_free(message);
        return NO;
    }
    return YES;
}

- (NSUInteger)reservedSpaceLength { return 0; }

- (NSPortMessage *)gfosPollMessage
{
    GFOSPortState *state = (GFOSPortState *)_internal;
    GFOSMessage *req;
    NSData *data;
    NSPortMessage *msg;
    if (!_is_valid || !state) return nil;
    req = gfos_port_receive(&state->local);
    if (!req) return nil;
    /* Materialize immutable data before returning the Exec envelope. */
    data = [NSData dataWithBytes:req->payload length:req->payloadLength];
    msg = [[NSPortMessage alloc] initWithSendPort:self receivePort:self
                                       components:[NSArray arrayWithObject:data]];
    [msg setMsgid:(unsigned)req->requestId];
    gfos_message_reply(req, msg ? 0 : 1);
    if (msg && [self delegate]) [[self delegate] handlePortMessage:msg];
    return [msg autorelease];
}

- (unsigned)gfosPollAcknowledgements
{
    GFOSPortState *state = (GFOSPortState *)_internal;
    GFOSMessage *reply;
    unsigned count = 0;
    if (!state) return 0;
    while ((reply = gfos_port_poll_reply(&state->local)) != NULL) {
        gfos_message_free(reply);
        count++;
    }
    return count;
}

- (void)invalidate
{
    GFOSPortState *state = (GFOSPortState *)_internal;
    if (!_is_valid) return;
    if (state && state->local.outgoing != 0) return;
    if (state && gfos_port_close(&state->local) != 0) return;
    [super invalidate];
}

- (void)dealloc
{
    GFOSPortState *state = (GFOSPortState *)_internal;
    if (state) {
        [self gfosPollAcknowledgements];
        [self invalidate];
        /* Keep inflight reply port memory alive rather than dereference freed
         * memory: production code must complete cancellation/ownership. */
        if (state->local.execPort) {
            _internal = NULL;
        } else {
            free(state->remoteName);
            free(state);
            _internal = NULL;
        }
    }
    [super dealloc];
}
@end
