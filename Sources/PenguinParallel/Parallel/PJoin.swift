// Copyright 2020 Penguin Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation


#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#else
import Glibc
#endif

/// A Naive ThreadPool.
///
/// It has well-known performance problems, but is used as a reference implementation to: (1) test
/// correctness of alternate implementations, and (2) to allow higher levels of abstraction to be
/// developed (and tested) in parallel with an efficient implementation of `ThreadPool`.
final public class NaiveThreadPool: TypedComputeThreadPool {
    init(workerCount: Int) {
        workers.reserveCapacity(workerCount)
        for i in 0..<workerCount {
            let worker = Worker(name: "Worker \(i)", index: i, allContexts: contexts)
            worker.start()
            workers.append(worker)
        }
    }

    init() {
        let workerCount = ProcessInfo.processInfo.activeProcessorCount
        workers.reserveCapacity(workerCount)
        for i in 0..<workerCount {
            let worker = Worker(name: "Worker \(i)", index: i, allContexts: contexts)
            worker.start()
            workers.append(worker)
        }
    }

    public var parallelism: Int { workers.count }

    public var currentThreadIndex: Int? {
        let index = Context.local(index: -1, allContexts: contexts).index
        if index < 0 { return nil }
        return index
    }

    public func dispatch(_ task: (NaiveThreadPool) -> Void) {
        // TODO: Implement me!
        fatalError("SORRY NOT YET IMPLEMENTED!")
    }

    public func join(_ a: (NaiveThreadPool) throws -> Void, _ b: (NaiveThreadPool) throws -> Void) throws {
        // TODO: Avoid extra closure construction!
        try withoutActuallyEscaping({ try b(self) }) { b in
            var item = WorkItem(op: b)
            var aError: Error? = nil
            contexts.addLocal(item: &item)
            defer {
                let tmp = contexts.popLocal()
                assert(tmp == &item, "Popped something other than item!")
            }
            do {
                try a(self)
            } catch {
                if item.tryTake() {
                    throw error
                } else {
                    // Another thread is executing item; can't return!
                    aError = error
                }
            }
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
            if let error = aError {
                throw error
            }
            if let error = item.error {
                throw error
            }
        }
    }

    private func allContexts() -> AllContexts {
        return contexts
    }

    private var contexts = AllContexts()
    private var workers = [Worker]()

    private final class Worker: Thread {

        init(name: String, index: Int, allContexts: AllContexts) {
            self.allContexts = allContexts
            self.index = index
            super.init()
            self.name = name
        }

        override final func main() {
            // Touch the thread-local context to create it & add it to the AllContext's list.
            _ = Context.local(index: index, allContexts: allContexts)
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
        let index: Int
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
            Context.local(index: -1, allContexts: self).add(item)
            notify()
        }

        func lookForWorkLocal() -> UnsafeMutablePointer<WorkItem>? {
            Context.local(index: -1, allContexts: self).lookForWorkLocal()
        }

        func popLocal() -> UnsafeMutablePointer<WorkItem>? {
            Context.local(index: -1, allContexts: self).popLast()
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
        private let cond = NSCondition()
    }


    /// Thread-local contexts
    private final class Context {
        private var lock = NSLock()
        private var workItems = [UnsafeMutablePointer<WorkItem>]()
        let index: Int

        init(index: Int) {
            self.index = index
        }

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
        static func local(index: Int, allContexts: AllContexts) -> Context {
            if let address = pthread_getspecific(key) {
                return Unmanaged<Context>.fromOpaque(address).takeUnretainedValue()
            }
            let context = Context(index: index)
            allContexts.append(context)
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
    var op: () throws -> Void // guarded by lock.
    var error: Error?  // guarded by lock.
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
        do {
            try op()
        } catch {
            self.error = error
        }
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
