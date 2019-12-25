import Foundation

class PipelineWorkerThread: Thread {
    static var startedThreadCount: Int32 = 0
    static var runningThreadCount: Int32 = 0

    public init(name: String) {
        super.init()
        self.name = name
    }

    /// This function must be overridden!
    func body() {
        preconditionFailure("No body in thread \(name!).")
    }

    override final func main() {
        OSAtomicIncrement32(&PipelineWorkerThread.startedThreadCount)
        OSAtomicIncrement32(&PipelineWorkerThread.runningThreadCount)
        body()
        OSAtomicDecrement32(&PipelineWorkerThread.runningThreadCount)
        assert(isFinished == false)
        condition.lock()
        defer { condition.unlock() }
        hasFinished = true
        condition.broadcast()  // Wake up everyone who has tried to join against thsi thread.

    }

    /// Blocks until the body has finished executing.
    func join() {
        condition.lock()
        defer { condition.unlock() }
        while !hasFinished {
            condition.wait()
        }
    }

    private var hasFinished: Bool = false
    private var condition = NSCondition()
}

public extension PipelineIterator {
    /// Determines if all worker threads started by Pipeline iterators process-wide have been stopped.
    ///
    /// This is used during testing to ensure there are no resource leaks.
    static func _allThreadsStopped() -> Bool {
        return PipelineWorkerThread.runningThreadCount == 0
    }
}
