/* GFOS GNUstep Base experimental native local message-port extensions.
 * LGPL-2.0-or-later; until NSRunLoop integrates this, caller explicitly polls.
 */
#ifndef GFOS_NS_MESSAGE_PORT_H
#define GFOS_NS_MESSAGE_PORT_H
#import <Foundation/NSPort.h>
#import <Foundation/NSPortMessage.h>
#import <Foundation/NSString.h>
@interface NSMessagePort (GFOSNativePort)
- (id)initWithGFOSRemoteName:(NSString *)name;
- (BOOL)gfosPublishName:(NSString *)name;
- (BOOL)gfosUnpublishName;
- (NSPortMessage *)gfosPollMessage;
- (unsigned)gfosPollAcknowledgements;
@end
#endif
