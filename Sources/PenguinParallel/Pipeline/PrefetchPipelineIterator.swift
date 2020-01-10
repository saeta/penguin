import Foundation

/// Performs upstream work on a background thread, storing prefetched values
/// in an intermediate buffer for fast retrieval.
///
/// PrefetchPipelineIterator inserts heterogeneous / pipeline parallelism into
/// a pipeline iterator, as "upstream" computation happens on future elements
/// while downstream elements are currently processed on the caller's thread.
public struct PrefetchPipelineIterator<Upstream: PipelineIteratorProtocol>: PipelineIteratorProtocol {
    public typealias Element = Upstream.Element

    public init(underlying: Upstream, prefetchCount: Int) {
        self.impl = Impl(underlying: underlying, config: PrefetchBufferConfiguration(initialCapacity: prefetchCount))
    }

    public mutating func next() throws -> Element? {
        guard let prefetchedValue = impl.shared.buffer.pop() else {
            return nil
        }
        return try prefetchedValue.get()  // Throw exception & unbox.
    }

    var impl: Impl

    class Impl {
        init(underlying: Upstream, config: PrefetchBufferConfiguration) {
            self.shared = Shared(buffer: PrefetchBuffer(config), underlying: underlying)
            self.thread = PrefetchThread(shared: shared)
            self.thread.start()  // Start the thread.
        }

        deinit {
            thread.waitUntilStarted()  // Ensure the worker thread has started.
            shared.buffer.close()  // Close the buffer to cause the worker thread to exit.
            thread.cancel()  // Set the cancel bit for good measure.
            thread.join()  // Wait until the background thread has terminated.
        }

        let shared: Shared
        let thread: PrefetchThread
    }

    class Shared {
        init(buffer: PrefetchBuffer<Upstream.Element>, underlying: Upstream) {
            self.buffer = buffer
            self.underlying = underlying
        }

        var buffer: PrefetchBuffer<Upstream.Element>
        var underlying: Upstream!  // Implicitly unwrapped to dealloc as early as possible.
    }

    class PrefetchThread: PipelineWorkerThread {
        init(shared: Shared) {
            self.shared = shared
            super.init(name: "prefetch_thread")
        }

        override func body() {
            while true {
                let res = Result { try shared.underlying.next() }
                switch res {
                case let .success(elem):
                    if let elem = elem {
                        if !shared.buffer.push(.success(elem)) {
                            return  // Buffer has been closed.
                        }
                    } else {
                        // Reached end of iterator;
                        shared.buffer.close()
                        shared.underlying = nil  // Eagerly deallocate it.
                        return  // Aaaand, we're done!
                    }
                case let .failure(err):
                    if !shared.buffer.push(.failure(err)) {
                        return  // Buffer has been closed.
                    }
                }
            }
        }

        let shared: Shared
    }
}

/// Performs upstream work on a background thread, storing prefetched values
/// in an intermediate buffer for fast retrieval.
///
/// PrefetchPipelineSequence inserts heterogeneous / pipeline parallelism into
/// a pipeline iterator, as "upstream" computation happens on future elements
/// while downstream elements are currently processed on the caller's thread.
public struct PrefetchPipelineSequence<Upstream: PipelineSequence>: PipelineSequence {
    public typealias Element = Upstream.Element

    public init(_ upstream: Upstream, prefetchCount: Int) {
        self.upstream = upstream
        self.prefetchCount = prefetchCount
    }

    public func makeIterator() -> PrefetchPipelineIterator<Upstream.Iterator> {
        PrefetchPipelineIterator(
            underlying: upstream.makeIterator(),
            prefetchCount: prefetchCount
        )
    }

    let upstream: Upstream
    let prefetchCount: Int
}

public extension PipelineSequence {
    /// Prefetch inserts pipeline parallelism into a pipeline iterator.
    ///
    /// In the following example, `myExpensiveFn` and `myOtherExpensiveFn` will
    /// execute on two separate threads in parallel:
    ///
    ///      var itr = PipelineIterator.reduceWindow { myExpensiveFn($0) }.prefetch()
    ///      while let elem = try itr.next() {
    ///          print(myOtherExpensiveFn(elem))
    ///      }
    ///
    /// - Parameter count: The buffer size to overlap between the upstream and
    ///   the downstream computation. Pick a smaller buffer size to consume less
    ///   memory. Pick a larger buffer size if there is more variability in the
    ///   rates of consumption between upstream and downstream work to smooth
    ///   out bubbles that can decrease throughput.
    ///
    func prefetch(_ count: Int? = nil) -> PrefetchPipelineSequence<Self> {
        PrefetchPipelineSequence(self, prefetchCount: count ?? 10)
    }
}

public extension PipelineIteratorProtocol {
    /// Prefetch inserts pipeline parallelism into a pipeline iterator.
    ///
    /// In the following example, `myExpensiveFn` and `myOtherExpensiveFn` will
    /// execute on two separate threads in parallel:
    ///
    ///      var itr = PipelineIterator.reduceWindow { myExpensiveFn($0) }.prefetch()
    ///      while let elem = try itr.next() {
    ///          print(myOtherExpensiveFn(elem))
    ///      }
    ///
    /// - Parameter count: The buffer size to overlap between the upstream and
    ///   the downstream computation. Pick a smaller buffer size to consume less
    ///   memory. Pick a larger buffer size if there is more variability in the
    ///   rates of consumption between upstream and downstream work to smooth
    ///   out bubbles that can decrease throughput.
    ///
    func prefetch(_ count: Int? = nil) -> PrefetchPipelineIterator<Self> {
        // TODO: Add autotuning.
        PrefetchPipelineIterator(underlying: self, prefetchCount: count ?? 10)
    }
}

struct PrefetchBufferConfiguration {
    var initialCapacity: Int = 10
    var autoTune: Bool = false
}

struct PrefetchBuffer<T> {
    typealias Element = Result<T, Error>
    private typealias Buffer = [Element?] // TODO: optimize away optional overhead.

    init(_ config: PrefetchBufferConfiguration) {
        precondition(config.initialCapacity > 1)
        precondition(config.autoTune == false,
                     "Autotuning buffer sizes is not yet supported.")  // TODO
        self.config = config
        self.buffer = Buffer(repeating: nil, count: config.initialCapacity)
    }

    /// Pushes an element into the prefetch buffer.
    ///
    /// Returns false if the buffer was closed before the push could complete, true otherwise.
    mutating func push(_ elem: Element) -> Bool {
        // Advance the head by one, ensuring we don't overtake the tail.
        condition.lock()
        defer { condition.unlock() }
        // TODO: support early termination by the consumer that doesn't drain the queue!
        while (head + 1) % buffer.count == tail && !closed {
           condition.wait()  // Wait for space in buffer
        }
        if closed { return false }  // Buffer has been closed; return without doing anything further.
        assert(buffer[head] == nil, "Unexpected non-nil value at \(tail); \(self).")
        buffer[head] = elem
        head = (head + 1) % buffer.count
        condition.broadcast()
        return true
    }

    mutating func pop() -> Element? {
        // Advance the tail towards the head by one.
        condition.lock()
        defer { condition.unlock() }
        while !closed && tail == head {  // Nothing in the queue.
            condition.wait()
        }
        if isEmpty { return nil } // T1 tried to pop, and while T1 waited, T2 called close().
        guard let tmp = buffer[tail] else {
            fatalError("Unexpected nil encountered at \(tail); \(self).")
        }
        buffer[tail] = nil
        tail = (tail + 1) % buffer.count
        condition.broadcast()
        return tmp
    }

    mutating func close() {
        condition.lock()
        defer { condition.unlock() }
        closed = true
        condition.broadcast()  // Wake up any waiters if there are any.
    }

    var isEmpty: Bool {
        if !closed {
            // New values could be generated in the future.
            return false
        }
        // If we're closed, and the tail has caught up to the head, we're empty!
        return head == tail
    }

    private var condition = NSCondition()
    private var buffer: Buffer  // Treat buffer as a ring buffer.
    // TODO: use a convention for head and tail that doesn't waste a buffer slot.
    private var head = 0  // Points to the last pushed element.
    private var tail = 0  // Points to the next element to pop.
    private(set) var closed: Bool = false
    let config: PrefetchBufferConfiguration
}
