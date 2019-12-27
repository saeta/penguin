import PenguinParallel

func runMap() {
    let arr = [0, 1, 2, 3, 4]
    var itr = arr.makePipelineIterator().map { $0 + 1 }
    try! itr.next()
    try! itr.next()
    try! itr.next()
    try! itr.next()
    try! itr.next()
    try! itr.next()
}

func runCompactMap() {
	do {
        let arr = [0, 1, 2, 3, 4]
        var itr = arr.makePipelineIterator().compactMap { i -> Int? in
            if i % 2 == 0 {
                return i * 2
            } else { return nil }
        }
        try! itr.next()
        try! itr.next()
        try! itr.next()
        try! itr.next()
    }
    assert(PipelineIterator._allThreadsStopped(), "Not all threads stopped.")

}

print("Running silliness!")
for i in 0..<10000 {
	if i % 100 == 0 {
		print("Starting \(i)...")
	}
	runCompactMap()
}
print("done!")