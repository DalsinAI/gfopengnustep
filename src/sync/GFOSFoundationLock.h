/* Foundation-consumable lock via native Exec SignalSemaphore.
 * Not a substitute for all NSLock/NSThread implementation details.
 */
#ifndef GFOS_FOUNDATION_LOCK_H
#define GFOS_FOUNDATION_LOCK_H
#import <Foundation/NSObject.h>
#define BOOL GFOS_ExecBOOL
#include "gfos_sync.h"
#undef BOOL
@interface GFOSFoundationLock : NSObject {
@private
    GFOSMutex _mutex;
}
- (void)lock;
- (BOOL)tryLock;
- (void)unlock;
@end
#endif
