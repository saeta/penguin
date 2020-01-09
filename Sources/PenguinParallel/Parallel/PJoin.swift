import Foundation


#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#else
import Glibc
#endif

/// A ThreadPool allows efficient use of multi-core CPU machines by managing a collection of threads.
///
/// From first-principles, a (CPU) compute-bound application will run at peak performance when overheads
/// are minimized. Once enough parallelism is exposed to leverage all cores, one of the key overheads to
/// minmiize is context switching, and thead creation & destruction. The optimal system configuration is
/// thus a fixed-size threadpool where there is exactly one thread per CPU core (or rather, hyperthread).
/// This configuration results in zero context switching, no additional kernel calls for thread creation &
/// deletion, and full utilization of the hardware.
///
/// Unfortunately, in practice, it is infeasible to statically schedule work apriori onto a fixed pool of threads.
/// Even when applying the same operation to a homogenous dataset, there will inevitably be variability in
/// execution time. (This can arise from I/O interrupts taking over a core [briefly], or page faults, or even
/// different latencies for memory access across NUMA domains.) As a result, it is important for peak
/// performance to build abstractions that are flexible and dynamic in their work allocation.
///
/// The ThreadPool protocol is a foundational API designed to enable efficient use of hardware resources.
/// There are two APIs exposed to support two kinds of parallelism. For additional details, please see the
/// documentation associated with each.
///
/// Note: while there should be only one "physical" threadpool process-wide, there can be many virtual
/// threadpools that compose on top of this one to allow configuration and tuning. (This is why
/// `ThreadPool` is a protocol and not static methods.) Examples of additional threadpool abstractions
/// could include a separate threadpool per-NUMA domain, to support different priorities for tasks, or
/// higher-level parallelism primitives such as "wait-groups".
protocol ThreadPool {
    /// Submit a task to be executed on the threadpool.
    ///
    /// `prun` will execute task in parallel on the threadpool and it will complete at a future time.
    /// `prun` returns immediately.
    func prun(_ task: (Self) -> Void)

    /// Run two tasks (optionally) in parallel.
    ///
    /// Fork-join parallelism allows for efficient work-stealing parallelism. The two non-escaping
    /// functions will have finished executing before `pjoin` returns. The first function will execute on
    /// the local thread immediately, and the second function will execute on another thread if resources
    /// are available, or on the local thread if there are not available other resources.
    func pjoin(_ a: (Self) -> Void, _ b: (Self) -> Void)
}

/// A Naive ThreadPool.
///
/// It has well-known performance problems, but is used as a reference implementation to: (1) test
/// correctness of alternate implementations, and (2) to allow higher levels of abstraction to be
/// developed (and tested) in parallel with an efficient implementation of `ThreadPool`.
final public class NaiveThreadPool: ThreadPool {
    init(workerCount: Int) {
        workers.reserveCapacity(workerCount)
        for i in 0..<workerCount {
            let worker = Worker(name: "Worker \(i)", allContexts: contexts)
            worker.start()
            workers.append(worker)
        }
    }

    init() {
        let workerCount = ProcessInfo.processInfo.activeProcessorCount
        workers.reserveCapacity(workerCount)
        for i in 0..<workerCount {
            let worker = Worker(name: "Worker \(i)", allContexts: contexts)
            worker.start()
            workers.append(worker)
        }
    }

    public func prun(_ task: (NaiveThreadPool) -> Void) {
        // TODO: Implement me!
        fatalError("SORRY NOT YET IMPLEMENTED!")
    }

    public func pjoin(_ a: (NaiveThreadPool) -> Void, _ b: (NaiveThreadPool) -> Void) {
        withoutActuallyEscaping({ b(self) }) { b in
            var item = WorkItem(op: b)
            contexts.addLocal(item: &item)
            defer {
                let tmp = contexts.popLocal()
                assert(tmp == &item, "Popped something other than item!")
            }
            a(self)
            if item.tryTake() {
                item.execute()
            }
            // In case it was stolen by a background thread, steal other work.
            while !item.isFinished {
                // Prefer local work over remote work.
                if let work = contexts.lookForWorkLocal() {
                    work.pointee.execute()
                    continue
                }
                // Look for local work.
                let ctxs = contexts.allContexts()
                for ctx in ctxs {
                    if let work = ctx.lookForWork() {
                        work.pointee.execute()
                        break
                    }
                }
            }
        }
    }

    private func allContexts() -> AllContexts {
        return contexts
    }

    private var contexts = AllContexts()
    private var workers = [Worker]()

    private final class Worker: Thread {

        init(name: String, allContexts: AllContexts) {
            self.allContexts = allContexts
            super.init()
            self.name = name
        }

        override final func main() {
            // Touch the thread-local context to create it & add it to the AllContext's list.
            allContexts.append(Context.local)
            var foundWork = false // If we're finding work, don't wait on the condition variable.

            // Loop, looking for work.
            while true {
                let ctxs: [Context]
                if !foundWork {
                    ctxs = allContexts.wait()
                } else {
                    ctxs = allContexts.allContexts()
                }

                foundWork = false
                for ctx in ctxs {
                    if let item = ctx.lookForWork() {
                        item.pointee.execute()
                        foundWork = true
                    }
                }
            }
            // TODO: have a good way for a clean shutdown.
        }

        let allContexts: AllContexts
    }

    // Note: this cheap-and-dirty implementation is nowhere close to optimal!
    private final class AllContexts {
        func append(_ context: Context) {
            cond.lock()
            defer { cond.unlock() }
            cond.signal()
            contexts.append(context)
        }

        func addLocal(item: UnsafeMutablePointer<WorkItem>) {
            // This is gross!
            let oid = ObjectIdentifier(Context.local)
            if !sets.contains(oid) {
                cond.lock()
                sets.insert(oid)
                contexts.append(Context.local)
                cond.unlock()
            }
            Context.local.add(item)
            notify()
        }

        func lookForWorkLocal() -> UnsafeMutablePointer<WorkItem>? {
            Context.local.lookForWorkLocal()
        }

        func popLocal() -> UnsafeMutablePointer<WorkItem>? {
            Context.local.popLast()
        }

        func allContexts() -> [Context] {
            cond.lock()
            defer { cond.unlock() }
            return contexts
        }

        func wait() -> [Context] {
            cond.lock()
            defer { cond.unlock() }
            cond.wait()
            return contexts
        }

        func notify() {
            cond.signal()
        }

        func broadcast() {
            cond.broadcast()
        }

        // TODO: Keep track of contexts that might have useful things in order to avoid
        // doing unnecessary work when looking for work if this turns out to be a
        // performance problem.
        private var contexts = [Context]()
        private var sets = Set<ObjectIdentifier>()
        private let cond = NSCondition()
    }


    /// Thread-local contexts
    private final class Context {
        private var lock = NSLock()
        private var workItems = [UnsafeMutablePointer<WorkItem>]()

        // Adds a workitem to the list.
        //
        // Note: the caller must notify potential AllContext's waiters. (This should not be directly called, and
        // only called within `AllContexts.addLocal`.)
        func add(_ item: UnsafeMutablePointer<WorkItem>) {
            lock.lock()
            defer { lock.unlock() }
            workItems.append(item)
        }

        // This should also only be called when
        func popLast() -> UnsafeMutablePointer<WorkItem>? {
            lock.lock()
            defer { lock.unlock() }
            return workItems.popLast()
        }

        func lookForWork() -> UnsafeMutablePointer<WorkItem>? {
            lock.lock()
            defer { lock.unlock() }
            for elem in workItems {
                if elem.pointee.tryTake() {
                    return elem
                }
            }
            return nil
        }

        func lookForWorkLocal() -> UnsafeMutablePointer<WorkItem>? {
            lock.lock()
            defer { lock.unlock() }
            for elem in workItems.reversed() {
                if elem.pointee.tryTake() {
                    return elem
                }
            }
            return nil
        }

        /// The data key for the singleton `Context` in the current thread.
        ///
        /// TODO: figure out what to do vis-a-vis multiple thread pools? Maybe re-structure to avoid using
        /// threadlocal variables, and instead create a map keyed by thread id?
        static let key: pthread_key_t = {
            var key = pthread_key_t()
            pthread_key_create(&key) { obj in
    #if !(os(macOS) || os(iOS) || os(watchOS) || os(tvOS))
                let obj = obj!
    #endif
                Unmanaged<Context>.fromOpaque(obj).release()
            }
            return key
        }()

        /// The thread-local singleton.
        static var local: Context {
            if let address = pthread_getspecific(key) {
                return Unmanaged<Context>.fromOpaque(address).takeUnretainedValue()
            }
            let context = Context()
            pthread_setspecific(key, Unmanaged.passRetained(context).toOpaque())
            return context
        }
    }

    public static let global = NaiveThreadPool()
}

private struct WorkItem {
    enum State {
        case pre
        case ongoing
        case finished
    }
    var op: () -> Void // guarded by lock.
    var state: State = .pre
    let lock = NSLock()  // TODO: use atomic operations on State. (No need for a lock.)

    /// Returns true if this thread should execute op, false otherwise.
    mutating func tryTake() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if state == .pre {
            state = .ongoing
            return true
        }
        return false
    }

    mutating func execute() {
        op()
        markFinished()
    }

    mutating func markFinished() {
        lock.lock()
        defer { lock.unlock() }
        assert(state == .ongoing)
        state = .finished
    }

    var isFinished: Bool {
        lock.lock()
        defer { lock.unlock() }
        return state == .finished
    }
}
