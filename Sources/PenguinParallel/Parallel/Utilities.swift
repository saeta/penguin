import Foundation

/// Computes the number of "divide-in-half" times before we've reached approximately one
/// slice per processor core.
func computeRecursiveDepth(procCount: Int = ProcessInfo.processInfo.activeProcessorCount) -> Int {
    return Int(log2(Float(procCount)).rounded(.up))
}
