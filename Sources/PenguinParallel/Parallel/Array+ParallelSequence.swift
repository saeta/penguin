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

fileprivate func buffer_psum<Pool: ComputeThreadPool, T: Numeric>(
  _ pool: Pool,
  _ buff: UnsafeBufferPointer<T>,
  _ level: Int
) -> T {
  if level == 0 || buff.count < 1000 {  // TODO: tune this constant
    return buff.reduce(0, +)
  }
  let middle = buff.count / 2
  let lhs = buff[0..<middle]
  let rhs = buff[middle..<buff.count]
  var lhsSum = T.zero
  var rhsSum = T.zero
  pool.join(
    { lhsSum = buffer_psum(pool, UnsafeBufferPointer(rebasing: lhs), level - 1) },
    { rhsSum = buffer_psum(pool, UnsafeBufferPointer(rebasing: rhs), level - 1) })
  return lhsSum + rhsSum
}

extension Array where Element: Numeric {
  /// Computes the sum of all the elements in parallel.
  public func pSum() -> Element {
    withUnsafeBufferPointer { buff in
      buffer_psum(
        NaiveThreadPool.global,  // TODO: Take defaulted-arg & thread local to allow for composition!
        buff,
        computeRecursiveDepth() + 2)  // Sub-divide into quarters-per-processor in case of uneven scheduling.
    }
  }
}

fileprivate func buffer_pmap<Pool: ComputeThreadPool, T, U>(
  pool: Pool,
  source: UnsafeBufferPointer<T>,
  dest: UnsafeMutableBufferPointer<U>,
  mapFunc: (T) -> U
) {
  assert(source.count == dest.count)

  var threshold = 1000  // TODO: tune this constant
  assert(
    {
      threshold = 10
      return true
    }(), "Hacky workaround for no #if OPT.")

  if source.count < threshold {
    for i in 0..<source.count {
      dest[i] = mapFunc(source[i])
    }
    return
  }
  let middle = source.count / 2
  let srcLower = source[0..<middle]
  let dstLower = dest[0..<middle]
  let srcUpper = source[middle..<source.count]
  let dstUpper = dest[middle..<source.count]
  pool.join(
    {
      buffer_pmap(
        pool: pool,
        source: UnsafeBufferPointer(rebasing: srcLower),
        dest: UnsafeMutableBufferPointer(rebasing: dstLower),
        mapFunc: mapFunc)
    },
    {
      buffer_pmap(
        pool: pool,
        source: UnsafeBufferPointer(rebasing: srcUpper),
        dest: UnsafeMutableBufferPointer(rebasing: dstUpper),
        mapFunc: mapFunc)
    })
}

extension Array {

  /// Makes a new array, where every element in the new array is `f(self[i])` for all `i` in `0..<count`.
  ///
  /// Note: this function applies `f` in parallel across all available threads on the local machine.
  public func pMap<T>(_ f: (Element) -> T) -> [T] {
    // TODO: support throwing.
    withUnsafeBufferPointer { selfBuffer in
      [T](unsafeUninitializedCapacity: count) { destBuffer, cnt in
        cnt = count
        buffer_pmap(
          pool: NaiveThreadPool.global,  // TODO: Take a defaulted-arg / pull from threadlocal for better composition!
          source: selfBuffer,
          dest: destBuffer,
          mapFunc: f
        )
      }
    }
  }
}
