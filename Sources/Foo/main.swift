import PenguinParallel
import Dispatch


func time<T>(_ name: String, f: () -> T) -> T {
    let start = DispatchTime.now()
    let tmp = f()
    let end = DispatchTime.now()
    let nanoseconds = Double(end.uptimeNanoseconds - start.uptimeNanoseconds)
    let milliseconds = nanoseconds / 1e6
    print("\(name) \(milliseconds) ms")
    return tmp
}

func foo() {
    Array(0..<100).pMap { elem -> Int in
//            print("Thread.current.name: \(Thread.current.name).")
            return elem * 2
    }
}

func sum() -> Int {
    let arr = Array(0..<10000000)
    return arr.pSum()
}

print("Hello world!")
print(time("psum") { sum() })
//foo()
print("Done!")
time("sequential") {
    Array(0..<10000000).reduce(0, +)
}
print("Done 2!")
