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

import CPenguinParallel

internal struct AtomicUInt64 {
  var valueStorage: CAtomicUInt64
  init() {
    valueStorage = CAtomicUInt64()
  }

  mutating func setRelaxed(_ value: UInt64) {
    nbc_set_relaxed_atomic(&valueStorage, value)
  }

  var valueRelaxed: UInt64 { mutating get { nbc_load_relaxed(&valueStorage) }}
  var valueAcquire: UInt64 { mutating get { nbc_load_acquire(&valueStorage) }}
  var valueSeqCst: UInt64 { mutating get { nbc_load_seqcst(&valueStorage) }}

  mutating func cmpxchgAcqRel(original: inout UInt64, newValue: UInt64) -> Bool {
    nbc_cmpxchg_acqrel(&valueStorage, &original, newValue)
  }

  mutating func cmpxchgSeqCst(original: inout UInt64, newValue: UInt64) -> Bool {
    nbc_cmpxchg_seqcst(&valueStorage, &original, newValue)
  }

  mutating func cmpxchgRelaxed(original: inout UInt64, newValue: UInt64) -> Bool {
    nbc_cmpxchg_relaxed(&valueStorage, &original, newValue)
  }

  /// Increments the stored value by 1, returns the old value.
  mutating func increment(by amount: UInt64 = 1) -> UInt64 {
    nbc_fetch_add(&valueStorage, amount)
  }

  mutating func decrement(by amount: UInt64 = 1) -> UInt64 {
    nbc_fetch_sub(&valueStorage, amount)
  }
}

internal func threadFenceSeqCst() {
  nbc_thread_fence_seqcst()
}

internal func threadFenceAcquire() {
  nbc_thread_fence_acquire()
}

internal struct AtomicUInt8 {
  var valueStorage: CAtomicUInt8
  init() {
    valueStorage = CAtomicUInt8()
  }

  mutating func setRelaxed(_ value: UInt8) {
    ac_store_relaxed(&valueStorage, value)
  }

  mutating func setRelease(_ value: UInt8) {
    ac_store_release(&valueStorage, value)
  }

  var valueRelaxed: UInt8 { mutating get { ac_load_relaxed(&valueStorage) }}
  var valueAcquire: UInt8 { mutating get { ac_load_acquire(&valueStorage) }}

  mutating func cmpxchgStrongAcquire(original: inout UInt8, newValue: UInt8) -> Bool {
    ac_cmpxchg_strong_acquire(&valueStorage, &original, newValue)
  }
}