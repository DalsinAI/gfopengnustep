/* GFOpenGNUstep Foundation/Exec receive bridge, LGPL-2.0-or-later. */
#import <Foundation/NSString.h>
#import <Foundation/NSData.h>
#import "GFOSFoundationEndpoint.h"
#include <string.h>

@implementation GFOSFoundationEndpoint
- (id)initWithPortName:(NSString *)name
{
    self = [super init];
    if (self != nil) {
        const char *cname = name ? [name UTF8String] : NULL;
        memset(&_port, 0, sizeof(_port));
        if (gfos_port_create(&_port, cname) != 0) {
            [self release];
            return nil;
        }
        _open = YES;
    }
    return self;
}

- (NSData *)receiveNextPayloadWithRequestId:(unsigned long *)requestId
{
    GFOSMessage *message;
    NSData *data;
    if (!_open) return nil;
    message = gfos_port_receive(&_port);
    if (!message) return nil;
    /* Copy before ReplyMsg returns buffer ownership to the sender. */
    data = [NSData dataWithBytes:message->payload
                        length:message->payloadLength];
    if (requestId) *requestId = message->requestId;
    gfos_message_reply(message, data ? 0 : 1);
    return data;
}

- (void)invalidate
{
    if (_open) {
        _open = NO;
        gfos_port_close(&_port);
    }
}

- (void)dealloc
{
    [self invalidate];
    [super dealloc];
}
@end
