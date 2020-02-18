import PenguinParallel
import PenguinCSV
import Penguin
import Dispatch

@discardableResult
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
    _ = Array(0..<100).pMap { elem -> Int in
//            print("Thread.current.name: \(Thread.current.name).")
            return elem * 2
    }
}

let arraySize = 100_000_000

func sum() -> Int {
    let arr = Array(0..<arraySize)
    return arr.pSum()
}

print("Hello world!")
print(time("psum") { sum() })
//foo()
print("Done!")
time("sequential") {
    Array(0..<arraySize).reduce(0, +)
}
print("Done 2!")

let reader = try! CSVReader(file: "/Users/saeta/tmp/criteo/day_0_short")
print("Metadata:\n\(reader.metadata!)")
let table = try! PTable(csv: "/Users/saeta/tmp/criteo/day_0_short")
print(table)
let c3: PTypedColumn<Int> = try! table["c3"]!.asDType()
print(c3)
let c5: PTypedColumn<String> = try! table["c5"]!.asDType()
print(c5)

print(String(describing: c5[0]!.map { $0 }))
//print(table["c5"]!)
// let lines = reader.readAll()
// print("Lines:\n\(lines)")
