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
public func pjoin(a: () -> Void, b: () -> Void) {
    withoutActuallyEscaping(b) { b in 
        var item = WorkItem(op: b, state)
        Context.local.workItems.append(item)
    }
}


struct WorkItem {
    enum State {
        case pre
        case ongoing
        case finished
    }
    var op: () -> Void // guarded by lock.
    var state: State = .pre
    let lock = NSLock()  // TODO: use atomic operations on State. (No need for a lock.)
}

private final class Worker: Thread {

    override final func main() {
        print("TODO: do background work.")
    }
}

/// Thread-local contexts
private final class Context {
    var workItems: [WorkItem]

    /// The data key for the singleton `Context` in the current thread.
    static let key: pthread_key_t = {
        var key = pthread_key_t()
        pthread_key_create(&key) { obj in
#if !(os(macOS) || os(iOS) || os(watchOS) || os(tvOS))
            let obj = obj!
#endif
            Unmanaged<ContextManager>.fromOpaque(obj).release()
        }
        return key
    }()

    /// The thread-local singleton.
    static var local: ContextManager {
        if let address = pthread_getspecific(key) {
            return Unmanaged<ContextManager>.fromOpaque(address).takeUnretainedValue()
        }
        let context = ContextManager()
        pthread_setspecific(key, Unmanaged.passRetained(context).toOpaque())
        return context
    }
}