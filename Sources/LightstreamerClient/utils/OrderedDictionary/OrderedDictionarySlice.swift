/*
 The MIT License (MIT)

 Copyright © 2015-2021 Lukas Kubanek

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */
/// :nodoc:
public struct OrderedDictionarySlice<Key: Hashable, Value>: RandomAccessCollection, MutableCollection {
    
    // ============================================================================ //
    // MARK: - Type Aliases
    // ============================================================================ //
    
    /// The type of the underlying ordered dictionary.
    public typealias Base = OrderedDictionary<Key, Value>
    
    /// The type of the contiguous subrange of the ordered dictionary's elements.
    public typealias SubSequence = Self
    
    // ============================================================================ //
    // MARK: - Initialization
    // ============================================================================ //
    
    public init(base: Base, bounds: Base.Indices) {
        self.base = base
        self.startIndex = bounds.lowerBound
        self.endIndex = bounds.upperBound
    }
    
    // ============================================================================ //
    // MARK: - Base
    // ============================================================================ //
    
    /// The underlying ordered dictionary.
    public private(set) var base: Base
    
    // ============================================================================ //
    // MARK: - Indices
    // ============================================================================ //
    
    /// The start index.
    public let startIndex: Base.Index
    
    /// The end index.
    public let endIndex: Base.Index
    
    // ============================================================================ //
    // MARK: - Subscripts
    // ============================================================================ //
    
    public subscript(
        position: Base.Index
    ) -> Base.Element {
        get {
            base[position]
        }
        set(newElement) {
            base[position] = newElement
        }
    }
    
    public subscript(
        bounds: Range<Int>
    ) -> OrderedDictionarySlice<Key, Value> {
        get {
            base[bounds]
        }
        set(newElements) {
            base[bounds] = newElements
        }
    }
    
    // ============================================================================ //
    // MARK: - Reordering Methods Overloads
    // ============================================================================ //
    
    public mutating func sort(
        by areInIncreasingOrder: (Base.Element, Base.Element) throws -> Bool
    ) rethrows {
        try base._sort(
            in: indices,
            by: areInIncreasingOrder
        )
    }
    
    public mutating func reverse() {
        base._reverse(in: indices)
    }
    
    public mutating func shuffle<T>(
        using generator: inout T
    ) where T: RandomNumberGenerator {
        base._shuffle(
            in: indices,
            using: &generator
        )
    }
    
    public mutating func partition(
        by belongsInSecondPartition: (Base.Element) throws -> Bool
    ) rethrows -> Index {
        return try base._partition(
            in: indices,
            by: belongsInSecondPartition
        )
    }
    
    public mutating func swapAt(_ i: Base.Index, _ j: Base.Index) {
        base.swapAt(i, j)
    }
    
}
