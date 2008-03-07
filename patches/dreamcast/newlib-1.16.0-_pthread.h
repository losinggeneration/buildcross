#ifndef __SYS__PTHREAD_H
#define __SYS__PTHREAD_H

// Make sure pthreads compile ok.
#define _POSIX_THREADS
#define _POSIX_TIMEOUTS
#define _POSIX_THREAD_PRIO_PROTECT

// needed for gcc 4.2 (maybe 4.x)
#define PTHREAD_MUTEX_NORMAL 1
#define PTHREAD_MUTEX_ERRORCHECK 2
#define PTHREAD_MUTEX_RECURSIVE 3
#define PTHREAD_MUTEX_DEFAULT 4

// And all this maps pthread types to KOS types for pthread.h.
#include <kos/thread.h>
#include <kos/sem.h>
#include <kos/cond.h>
#include <kos/mutex.h>

#endif	/* __SYS__PTHREAD_H */
