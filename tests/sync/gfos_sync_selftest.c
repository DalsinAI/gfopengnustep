/* Single task semaphore smoke; concurrent guest tests still required. */
#include "gfos_sync.h"
#include <stdio.h>
int main(void) {
    GFOSMutex lock;
    gfos_mutex_init(&lock);
    if (!gfos_mutex_trylock(&lock)) return 2;
    if (!gfos_mutex_trylock(&lock)) return 3; /* Exec nested owner */
    gfos_mutex_unlock(&lock);
    gfos_mutex_unlock(&lock);
    gfos_mutex_lock(&lock);
    gfos_mutex_unlock(&lock);
    puts("GFOS_SYNC_SINGLE_TASK_PASS");
    return 0;
}
