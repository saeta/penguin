import Foundation


#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#else
import Glibc
#endif

/// pjoin is a fundamental abstraction representing [optional] parallelism.
///
/// pjoin runs the first (`a`) closure inline, and `b` on a work stealing shared thread
/// pool if there's available resources, or serially after `a` if there are not available
/// resources.
public func pjoin(_ a: () -> Void, _ b: () -> Void) {
    withoutActuallyEscaping(b) { b in 
        var item = WorkItem(op: b)
        Context.local.add(&item)
        defer {
            let tmp = Context.local.popLast()
            assert(tmp == &item, "Popped something other than item!")
        }
        a()
        if item.tryTake() {
            item.execute()
        }
        // In case it was stolen by a background thread, steal other work.
        while !item.isFinished {
            // Refer local work over remote work.
            if let work = Context.local.lookForLocalWork() {
                work.pointee.execute()
                continue
            }
            // Look for local work.
            let ctxs = AllContexts.allContexts()
            for ctx in ctxs {
                if let work = ctx.lookForWork() {
                    work.pointee.execute()
                    break
                }
            }
        }
    }
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

private final class Worker: Thread {

    init(name: String) {
        super.init()
        self.name = name
    }

    override final func main() {
        do {
            // Touch the thread-local context to create it & add it to the global list.
            _ = Context.local
        }
        var foundWork = false
        while true {
            let ctxs: [Context]
            if !foundWork {
                ctxs = AllContexts.wait()
            } else {
                ctxs = AllContexts.allContexts()
            }

            foundWork = false
            for ctx in ctxs {
                if let item = ctx.lookForWork() {
                    item.pointee.execute()
                    foundWork = true
                }
            }
        }
    }
}

// Note: this cheap-and-dirty implementation is nowhere close to optimal!
private final class AllContexts {
    static let global = AllContexts()

    init() {
        let workerCount = ProcessInfo.processInfo.activeProcessorCount
        workers.reserveCapacity(workerCount)
        for i in 0..<workerCount {
            let worker = Worker(name: "Worker \(i)")
            worker.start()
            workers.append(worker)
        }
    }

    static func add(_ context: Context) {
        global.add(context)
    }

    static func wait() -> [Context] {
        global.wait()
    }

    static func notify() {
        global.notify()
    }

    static func allContexts() -> [Context] {
        global.allContexts()
    }

    func add(_ context: Context) {
        cond.lock()
        defer { cond.unlock() }
        cond.signal()
        contexts.append(context)
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

    private var contexts = [Context]()
    private var workers = [Worker]()
    private let cond = NSCondition()
}

/// Thread-local contexts
private final class Context {
    private var lock = NSLock()
    private var workItems = [UnsafeMutablePointer<WorkItem>]()

    func add(_ item: UnsafeMutablePointer<WorkItem>) {
        lock.lock()
        defer { lock.unlock() }
        workItems.append(item)
        AllContexts.notify()
    }

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

    func lookForLocalWork() -> UnsafeMutablePointer<WorkItem>? {
        lock.lock()
        defer { lock.unlock() }
        for elem in workItems.reversed() {
            if elem.pointee.tryTake() {
                return elem
            }
        }
        return nil
    }

    init() {
        AllContexts.add(self)
    }

    /// The data key for the singleton `Context` in the current thread.
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
