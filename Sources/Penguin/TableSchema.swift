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

// Some functionality in this file is available only when using a S4TF toolchain, as it depends on
// S4TF features that haven't yet been merged upstream (e.g. KeyPathIterable). As a result, we gate
// compilation on whether TensorFlow can be imported.
#if canImport(TensorFlow)

public protocol PTableSchema: KeyPathIterable, PDefaultInit {
    var keyPathsToMemberNames: [PartialKeyPath<Self>: String] { get }
}

extension PTableSchema {
    var keyPathsToMemberNames: [PartialKeyPath<Self>: String] {
        let keyPaths = self.allKeyPaths as! [PartialKeyPath<Self>]
        let mirror = Mirror(reflecting: self)

        var membersToKeyPaths: [PartialKeyPath<Self>: String] = [:]
        var i = 0
        for case (let member?, _) in mirror.children{
            membersToKeyPaths[keyPaths[i]] = member
            i += 1
        }
        return membersToKeyPaths
    }
}

#else // !canImport(TensorFlow)

public protocol PTableSchema: PDefaultInit {
    var allKeyPaths: [PartialKeyPath<Self>] { get }
    // TODO: convert to static (when KeyPathIterable-based implementation can be converted). Also
    // at this time, remove the requirement to also conform to PDefaultInit.
    var keyPathsToMemberNames: [PartialKeyPath<Self>: String] { get }
}

#endif  // canImport(TensorFlow)
