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

extension Graphs {

	/// Computes a topological sort of `graph`.
	///
	/// A topological sort means that for every 0 <= i < j < graph.vertexCount,
	/// there does not exist an edge from returnValue[j] to returnValue[i] (i.e.
	/// backwards in the array).
	///
	/// The implementation for `topologicalSort` is primarily a call to
	/// `depthFirstTraversal`.
	public static func topologicalSort<Graph: IncidenceGraph & VertexListGraph>(
		_ graph: inout Graph
	) -> [Graph.VertexId] where Graph.VertexId: IdIndexable {
		let vertexCount = graph.vertexCount
		let output = Array<Graph.VertexId>(unsafeUninitializedCapacity: vertexCount) { buffer, filled in
			var visitor = TopologicalSortVisitor<Graph>(outputBuffer: buffer, nextAvailable: vertexCount - 1)
			Graphs.depthFirstTraversal(&graph, visitor: &visitor)
			filled = vertexCount
		}
		return output
	}
}

private struct TopologicalSortVisitor<Graph: GraphProtocol>: DFSVisitor
where Graph.VertexId: IdIndexable {
	let outputBuffer: UnsafeMutableBufferPointer<Graph.VertexId>
	var nextAvailable: Int

	mutating func finish(vertex: Graph.VertexId, _ graph: inout Graph) {
		assert(nextAvailable >= 0)
		assert(nextAvailable < outputBuffer.count)
		outputBuffer[nextAvailable] = vertex
		nextAvailable -= 1
	}
}
