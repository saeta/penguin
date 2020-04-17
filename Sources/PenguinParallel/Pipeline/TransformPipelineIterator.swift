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


/// TransformPipelineIterator is used to run arbitrary user-supplied transformations in a pipelined fashion.
///
/// The transform function should return nil to skip the element.
// TODO: Add threading to pipeline the transformation!
// TODO: Add early stopping control flow.
public struct TransformPipelineIterator<Underlying: PipelineIteratorProtocol, Output>: PipelineIteratorProtocol {
    public typealias Element = Output
    public typealias TransformFunction = (Underlying.Element) throws -> Output?

    public init(_ underlying: Underlying, name: String?, threadCount: Int, bufferSize: Int, transform: @escaping TransformFunction) {
        self.impl = Impl(underlying, name: name, threadCount: threadCount, bufferSize: bufferSize, transform: transform)
    }

    public mutating func next() throws -> Output? {
        while let output = impl.buffer.consume() {
            switch output {
            case let .success(output):
                if output == nil {
                    continue  // Get another element, as this one should be filtered out.
                }
                return output
            case let .failure(err):
                throw err
            }
        }
        return nil // Iteration is complete.
    }

    /// The implementation of the TransformPipelineIterator.
    ///
    /// Overall design: _n_ threads race to call `.next()` from the `underlying` iterator, and
    /// receive a token. They then each in parallel execute the transform function, and set the output in the
    /// corresponding element in the output `buffer`.
    ///
    /// In this design, there are 3 thread categories:
    ///  - Initializer thread: this is the thread that initalizes the TransformPipelineIterator. Because this is
    ///    usually the user's main thread, we should do the minimum amount of work before returning, as
    ///    this is usually on the "critical path". (This thread is not present in "steady-state", and can be the
    ///    same kernel/physical thread as the consumer thread. We consider it separately as the
    ///    performance considerations during initialization are distinct.)
    ///  - Consumer thread: this is the thread that calls `TransformPipelineIterator.next`. The
    ///    architecture of PiplineIterator's demands that minimal amounts of work be done here.
    ///  - Worker threads. These threads are internal to the `TransformPipelineIterator` and are
    ///    used to run the user-supplied transform function.
    ///
    /// This implementation does a relatively small amount of work during initialization. This is important as
    /// this is on the critical path to getting the pipeline setup. Here, we copy the configuration, allocate the
    /// output buffer, and start the worker threads. The worker threads then immediately start attempting to
    /// pull elements from the upstream iterator as quickly as possible in order to fill up the pipeline as
    /// quickly as possible.
    ///
    /// When worker threads request new elements from the upstream iterator, they do so while holding the
    /// lock `condition`.
    ///
    /// Tuning tips:
    ///  - Tune threadCount for your machine, target throughput, and your pipeline. Ensure there
    ///    are approximately equal worker threads (threadCount) as physical cores on your machine,
    ///    aggregated across all TransformPipelineIterator's.
    ///  - Increase the ratio bufferSize:threadCount if the transformation function can be highly variable.
    ///  - Combine multiple `TransformFunction`s into fewer, if possible.
    ///
    /// Invariants:
    ///  - Worker threads only ever block trying to get an element from the underlying iterator. Every other operation
    ///    must not block the thread.
    ///  - `tail` chases `head` around the circular buffer `buffer`.
    // TODO: Optimize the case where the filter condition is highly selective.
    // TODO: Dynamically size the output buffer capacity and thread count, espceially if
    //       there is highly variable `TransformFunction` latency.
    // TODO: Add tracing annotations.
    // TODO: Allow users to customize worker thread NUMA scheduling policies / etc.
    final class Impl {
        /// Element represents the output of a transformation. If it is .success(nil) it should
        /// be filtered out of the output.
        // TODO: Mark as a move-only type when available.
        typealias Element = Result<Output?, Error>

        /// ADT to represent tokens into the buffer.
        struct Token {
            let index: Int
        }

        // TODO: optimize away the extra optional overhead of Element.
        struct Entry {
            init() {
                semaphore = DispatchSemaphore(value: 0)
            }
            // Initialized to 0, incremented to 1 when entry is set,
            // and reset to zero when consumed.
            var semaphore: DispatchSemaphore
            // The entry itself. Semaphore should never be notified when entry is nil.
            var entry: Element?
            // Note: do not rely on this for synchronization purposes!
            var isEmpty: Bool { entry == nil }
        }

        /// Associated information related to the TransformPipelineIterator.
        ///
        /// Note: we stuff all these things here, instead of inside Impl in order to ensure the WorkerThreads
        /// do not hold a reference to Impl. This is because in order to ensure a safe shut-down, the
        /// WorkerThreads must not have a reference to Impl right when Impl.deinit is called.
        ///
        /// TODO: refactor all of this once Swift has move-only structs!
        struct BufferHeader {
            // Head points to the next element to be allocated to be executed
            // on a worker thread.
            //
            // Read & written by worker threads; must hold `condition` lock.
            var head: Int = 0

            // Tail points to the next element to be consumed by the consumer.
            // tail is only updated only by the consumer thread. It can be
            // safely read by the consumer thread without the lock, but must
            // be always written to while holding the `condition` lock, and
            // all worker thread reads must also hold the `condition` lock.
            var tail: Int = 0

            // Synchronization primitive.
            var condition = NSCondition()

            // The upstream iterator this transform pulls elements to transform from.
            // It is set to nil when execution should be cancelled or when it reaches the
            // end of the sequence in order to eagerly free up resources.
            //
            // It should only be manipulated while holding the `condition` lock.
            var underlying: Underlying?

            // The name of the operation.
            let name: String?
        }

        class Buffer: ManagedBuffer<BufferHeader, Entry> {
            func initialize() {
                withUnsafeMutablePointerToElements { base in
                    for i in 0..<capacity {
                        let ptr = base.advanced(by: i)
                        ptr.initialize(to: Entry())
                    }
                }
            }

            deinit {
                withUnsafeMutablePointerToElements { base in
                    _ = base.deinitialize(count: capacity)
                }
            }

            // MARK: -Worker methods

            /// Gets the next element to work on. If nil, worker thread should exit.
            ///
            /// Called from worker threads.
            func next(_ threadName: String?) -> (Result<Underlying.Element, Error>, Token)? {
                header.condition.lock()
                defer { header.condition.unlock() }
                while header.underlying != nil && !hasRoomForNext() {
                    header.condition.wait()
                }
                if header.underlying == nil {
                    return nil
                }
                let token = Token(index: header.head)
                header.head = (header.head + 1) % capacity
                let result = Result { () throws -> Underlying.Element? in
                    assert(header.underlying != nil, "header.underlying was nil.")
                    return try header.underlying!.next() // Assumed fast.
                }
                switch result {
                case let .success(output):
                    if let output = output {
                        return (.success(output), token)
                    }
                    // End of upstream iterator.
                    // Notify the token index just in case the consumer is already waiting.
                    complete(token: token, .success(nil)) // Pretend it should be filtered.
                    header.underlying = nil
                    header.condition.broadcast()
                    return nil
                case let .failure(err):
                    return (.failure(err), token)
                }
            }

            private func hasRoomForNext() -> Bool {
                (header.head + 1) % capacity != header.tail
            }

            /// Completes the processing of an element, and sets it ready
            ///
            /// Called from worker threads.
            func complete(token: Token, _ elem: Element) {
                withUnsafeMutablePointerToElements { base in
                    let ptr = base.advanced(by: token.index)
                    assert(ptr.pointee.isEmpty, "Element at \(token.index) was not empty (Operation: \(header.name ?? "")).")
                    ptr.pointee.entry = elem
                    ptr.pointee.semaphore.signal()
                }
            }

            // MARK: -Consumer methods

            /// Retrieves the next element the TransformPipelineIterator should produce.
            ///
            /// If it returns nil, the upstream iteration has completed.
            ///
            /// Called from consumer thread.
            // TODO: Optimize the case where there are sequences of filtered out elements (i.e.
            // where we return `Optional(.success(nil))`.)
            func consume() -> Element? {
                header.condition.lock()
                let endOfIteration = header.underlying == nil && header.head == header.tail
                let tail = header.tail
                header.condition.unlock()

                if endOfIteration {
                    return nil
                }
                let output = waitFor(tail)
                header.condition.lock()
                header.tail = (header.tail + 1) % capacity  // Advance tail.
                header.condition.signal()  // Wake up a waiting worker thread.
                header.condition.unlock()
                return output
            }

            func waitFor(_ index: Int) -> Element {
                withUnsafeMutablePointerToElements { base in
                    let ptr = base.advanced(by: index)
                    ptr.pointee.semaphore.wait()
                    guard let output = ptr.pointee.entry else {
                        fatalError("Output at \(index) was nil.")
                    }
                    ptr.pointee.entry = nil
                    return output
                }
            }
        }

        final class WorkerThread: PipelineWorkerThread {
            init(name: String, transform: @escaping TransformFunction) {
                self.transform = transform
                super.init(name: name)
            }

            override func body() {
                // Infinitely loop.
                while let (res, token) = buffer.next(name) {
                    switch res {
                    case let .success(input):
                        let output = Result { try transform(input) }
                        buffer.complete(token: token, output)
                    case let .failure(err):
                        buffer.complete(token: token, .failure(err))
                    }
                }
                buffer = nil  // Set to nil to avoid any nonsense.
            }

            let transform: TransformFunction
            unowned var buffer: Buffer!
        }


        init(_ underlying: Underlying, name: String?, threadCount: Int, bufferSize: Int, transform: @escaping TransformFunction) {
            self.buffer = Buffer.create(minimumCapacity: bufferSize) { _ in
                BufferHeader(underlying: underlying, name: name)
            } as! Buffer
            self.transform = transform
            self.name = name
            self.buffer.initialize()
            self.threads = [WorkerThread]()
            self.threads.reserveCapacity(threadCount)
            // Must be fully initialized before starting threads.
            for i in 0..<threadCount {
                let thread = WorkerThread(
                    name: "\(name ?? "")_worker_thread_\(i)",
                    transform: transform)
                thread.buffer = buffer
                thread.start()
                self.threads.append(thread)
            }
        }

        deinit {
            buffer.header.condition.lock()
            buffer.header.underlying = nil  // Signal to workers that they should terminate.
            buffer.header.condition.broadcast()
            buffer.header.condition.unlock()

            // Cancel and join with all the worker threads to ensure they have all shut down successfully.
            self.threads.forEach {
                $0.waitUntilStarted()  // Guarantee that the worker thread has at least started.
                $0.cancel()
            }
            self.threads.forEach {
                $0.join()
                $0.buffer = nil  // Set to nil to ensure the Thread's deinit doesn't try and do anything.
            }
        }

        // The buffer containing the transformed outputs.
        let buffer: Buffer
        // The transform function
        let transform: TransformFunction

        // The worker threads.
        var threads: [WorkerThread]

        let name: String?
    }
    var impl: Impl
}


public struct TransformPipelineSequence<Underlying: PipelineSequence, Output>: PipelineSequence {
    public typealias Element = Output
    public typealias TransformFunction = (Underlying.Element) throws -> Output?

    public init(_ underlying: Underlying, name: String?, threadCount: Int, bufferSize: Int, transform: @escaping TransformFunction) {
        self.underlying = underlying
        self.name = name
        self.threadCount = threadCount
        self.bufferSize = bufferSize
        self.transform = transform
    }

    public func makeIterator() -> TransformPipelineIterator<Underlying.Iterator, Output> {
        TransformPipelineIterator(underlying.makeIterator(), name: name, threadCount: threadCount, bufferSize: bufferSize, transform: transform)
    }

    let underlying: Underlying
    let name: String?
    let threadCount: Int
    let bufferSize: Int
    let transform: TransformFunction
}

public extension PipelineSequence {
    /// Transforms the iterator from returning elements of type `Element` into returning elements of type `T`.
    ///
    /// The map function `f` is run on potentially many threads in a data-parallel manner.
    func map<T>(name: String? = nil, f: @escaping (Element) throws -> T) -> TransformPipelineSequence<Self, T> {
        TransformPipelineSequence(self, name: name, threadCount: 5, bufferSize: 15, transform: f)
    }

    /// Filter removes elements where `f(elem)` returns `false`, but passes through elements that
    /// return `true`.
    func filter(name: String? = nil, f: @escaping (Element) throws -> Bool) -> TransformPipelineSequence<Self, Element> {
        TransformPipelineSequence(self, name: name, threadCount: 5, bufferSize: 15) {
            if try f($0) { return $0 } else { return nil }
        }
    }

    /// Compact map removes `nil`s, but passes through transformed elements of type `T`.
    func compactMap<T>(name: String? = nil, f: @escaping (Element) throws -> T?) -> TransformPipelineSequence<Self, T> {
        TransformPipelineSequence(self, name: name, threadCount: 5, bufferSize: 15, transform: f)
    }
}

public extension PipelineIteratorProtocol {
    func map<T>(name: String? = nil, f: @escaping (Element) throws -> T) -> TransformPipelineIterator<Self, T> {
        TransformPipelineIterator(self, name: name, threadCount: 5, bufferSize: 15, transform: f)
    }

    func filter(name: String? = nil, f: @escaping (Element) throws -> Bool) -> TransformPipelineIterator<Self, Element> {
        TransformPipelineIterator(self, name: name, threadCount: 5, bufferSize: 15) {
            if try f($0) { return $0 } else { return nil }
        }
    }

    func compactMap<T>(name: String? = nil, f: @escaping (Element) throws -> T?) -> TransformPipelineIterator<Self, T> {
        TransformPipelineIterator(self, name: name, threadCount: 5, bufferSize: 15, transform: f)
    }
}
