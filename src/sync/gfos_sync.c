/* GFOS Exec native synchronisation, LGPL-2.0-or-later. */
#include "gfos_sync.h"
#include <proto/exec.h>
void gfos_mutex_init(GFOSMutex *mutex) { InitSemaphore(&mutex->semaphore); }
void gfos_mutex_lock(GFOSMutex *mutex) { ObtainSemaphore(&mutex->semaphore); }
int gfos_mutex_trylock(GFOSMutex *mutex) { return AttemptSemaphore(&mutex->semaphore) ? 1 : 0; }
void gfos_mutex_unlock(GFOSMutex *mutex) { ReleaseSemaphore(&mutex->semaphore); }
