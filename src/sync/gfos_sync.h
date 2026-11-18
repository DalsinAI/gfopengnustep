/* GFOS native semaphore primitives for Foundation / GNUstep.
 * LGPL-2.0-or-later. No pthread emulation; Exec SignalSemaphore.
 */
#ifndef GFOS_FOUNDATION_SYNC_H
#define GFOS_FOUNDATION_SYNC_H
#include <exec/semaphores.h>
typedef struct GFOSMutex {
    struct SignalSemaphore semaphore;
} GFOSMutex;
void gfos_mutex_init(GFOSMutex *mutex);
void gfos_mutex_lock(GFOSMutex *mutex);
int gfos_mutex_trylock(GFOSMutex *mutex);
void gfos_mutex_unlock(GFOSMutex *mutex);
#endif
