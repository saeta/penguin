# Non blocking compute thread pool #

The non-blocking platform is made up from 5 key pieces:

 - **`ConcurrencyPlatform`** which provides key OS-specific functionality, such as locks,
   condition variables, and a factory for creating threads.
 - **`Atomics`** (internal only) make C atomic instructions available to Swift.
 - **`TaskDeque`** (internal only) represents a fixed-size queue of tasks to execute. The front is
   unsynchronized, and must only be accessed by a single thread. The back synchronizes access from
   multiple threads. Each thread in the thread pool has a thread-specific `TaskDeque` upon which it
   processes work items. Other threads may push work items or steal work items from the back.
   `TaskDeque` uses `Atomics` for non-blocking access, and `ConcurrencyPlatform` to synchromize the
   back of the queue. Additionally, the pool threads execute work in "LIFO" fashion, which improves
   cache locality. Because `TaskDeque` is fixed-size, it avoids unbounded queues.
 - **`NonblockingCondition`** is a logical condition variable with an API that supports atomic
   algorithms. Please see its doc comment for how to use this abstraction. It builds upon `Atomics`
   to coordinate between threads, and `ConcurrencyPlatform` to put waiting threads to sleep (to
   avoid wasting resources).
 - **`NonBlockingThreadPool`** builds upon the previous infrastructure and implements
   `ComputeThreadPool`. It supports expressing both fork-join and fire-and-forget parallelism
   efficiently. Any method on `ComputeThreadPool` (except `shutDown`) can be called from any thread,
   making the abstraction difficult to misuse, and (more importantly) trivial to express nested or
   hierarchical parallelism. Finally, pool threads spin for a bounded amount of time, saving CPU
   cycles for other applications.

For more details on each abstraction, please consult its associated documentation.

## Life of a parallel program ##

Let's walk through what happens when we use `NonBlockingThreadPool` in an application. We'll use the
following motivating example:

```swift
let pool = NonBlockingThreadPool<PosixConcurrencyPlatform>(name: "mypool", threadCount: 15)
let buffer: UnsafeMutableBufferPointer<Bool> = // ...
pool.parallelFor(n: buffer.count) { (index, n) in
  buffer[index] = true  // Sophisticated computation!
}
pool.shutDown()
```

1. First the application creates the `NonBlockingThreadPool`. The initializer creates all the pool
   threads, but often returns before all the worker threads have started executing. This allows for
   fast startup.

2. Next, the application wants to compute something using the thread pool. In this case, we're using
   the `parallelFor` API, which builds on top of the `join` API. The user's thread will divide the
   range `0..<buffer.count` in half, pick a random thread pool thread, and insert a task at the
   front of its `TaskQueue` to compute the second half of the range. The user's thread immediately
   starts working on the first half of the range. (To be continued...)

3. When the "back-half" task that was submitted in the previous step, a notification was set on the
   thread pool's `condition` variable. This triggers a worker thread to wake up. Either (a) the
   worker thread that was woken up or (b) a worker thread that was previously spinning (and looking
   to steal work) will steal the "back-half" task and begin executing it.

4. The user thread after step 2 and the worker thread that picks up the task from step 3 will both
   now further subdivide their ranges. The user's thread will pick a new thread pool thread and add
   a work item to its queue corresponding to the "back half" of the "front half" (or the second
   quarter) of the range. The thread pool thread will add the "back half" (or fourth quarter) of the
   range as a task to its own queue.

5. The above process continues until the work has been broken down. Once the ranges have been fully
   broken down, the user's function is executed for the given index. This occurs in parallel across
   all threads.

6. Finally, as threads finish executing the "first half" of their tasks, they check to see if their
   corresponding "second half" has finished executing. If it has already, then they can immediately
   return. If it hasn't, worker threads work on other tasks in their local queue, or try and steal
   work from other threads if there is no local work available (e.g. that another thread stole the
   "second half" of their work). Once their "second half" work has finished, they return. The
   threads work their way up the stacks of subdivisions until everything is complete.

7. If there is absolutely no work to do and the "second half" task isn't complete yet, workers or
   the user's thread will put themselves to sleep to efficiently wait. The user's thread typically
   works to divide all the work among the thread pool threads and executes the first element of the
   parallelFor computation before going to sleep.

8. Finally, all work has finished on the thread pool. The call to `parallelFor` returns, and the
   user's program is free to continue on its merry way!
