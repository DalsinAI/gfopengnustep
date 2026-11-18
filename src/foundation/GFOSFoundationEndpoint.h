/* GFOpenGNUstep Foundation/Exec receive bridge (prototype).
 * LGPL-2.0-or-later. This is NOT the full NSPort/NSMessagePort contract.
 */
#ifndef GFOS_FOUNDATION_ENDPOINT_H
#define GFOS_FOUNDATION_ENDPOINT_H
#import <Foundation/NSObject.h>
#import <Foundation/NSData.h>

/* Exec's BOOL is a 16-bit typedef whereas libobjc BOOL is unsigned char. */
#define BOOL GFOS_ExecBOOL
#include "gfos_transport.h"
#undef BOOL

@interface GFOSFoundationEndpoint : NSObject
{
@private
    GFOSPort _port;
    BOOL _open;
}
/* name is nil for a private, unnamed port. */
- (id)initWithPortName:(NSString *)name;
- (NSData *)receiveNextPayloadWithRequestId:(unsigned long *)requestId;
- (void)invalidate;
@end
#endif
