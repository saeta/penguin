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

#if os(macOS)
  import Darwin
#elseif os(Windows)
  import ucrt
  import WinSDK
#else
  import Glibc
#endif

public struct PosixThreadLocalStorage: RawThreadLocalStorage {
  #if os(macOS)
    /// A function to delete the raw memory.
    typealias KeyDestructor = @convention(c) (UnsafeMutableRawPointer) -> Void
    private static let keyDestructor: KeyDestructor = {
      Unmanaged<AnyObject>.fromOpaque($0).release()
    }
  #else
    /// A function to delete the raw memory.
    typealias KeyDestructor = @convention(c) (UnsafeMutableRawPointer?) -> Void
    private static let keyDestructor: KeyDestructor = {
      if let obj = $0 {
        Unmanaged<AnyObject>.fromOpaque(obj).release()
      }
    }
  #endif

  public struct Key {
    #if os(Windows)
      var value: DWORD
    #else
      var value: pthread_key_t
    #endif

    init() {
      #if os(Windows)
        fatalError("Unimplemented!")
      #else
        value = pthread_key_t()
        pthread_key_create(&value, keyDestructor)
      #endif
    }
  }

  public static func makeKey() -> Key {
    Key()
  }

  public static func destroyKey(_ key: inout Key) {
    #if os(Windows)
      fatalError("Unimplemented!")
    #else
      pthread_key_delete(key.value)
      key.value = 0
    #endif
  }

  public static func get(for key: Key) -> UnsafeMutableRawPointer? {
    pthread_getspecific(key.value)
  }

  public static func set(value: UnsafeMutableRawPointer?, for key: Key) {
    pthread_setspecific(key.value, value)
  }
}
