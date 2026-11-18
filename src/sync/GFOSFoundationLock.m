#import "GFOSFoundationLock.h"
@implementation GFOSFoundationLock
- (id)init {
    self = [super init];
    if (self) gfos_mutex_init(&_mutex);
    return self;
}
- (void)lock { gfos_mutex_lock(&_mutex); }
- (BOOL)tryLock { return gfos_mutex_trylock(&_mutex) ? YES : NO; }
- (void)unlock { gfos_mutex_unlock(&_mutex); }
@end
