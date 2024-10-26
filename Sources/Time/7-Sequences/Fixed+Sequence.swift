import Foundation

/// A `Sequence` of fixed values.
public struct FixedSequence<U: Unit & LTOEEra>: Sequence {
    
    private let constructor: () -> FixedIterator<U>
    
    internal init() {
        constructor = { FixedIterator() }
    }
    
    /// Construct an infinite sequence of fixed values starting from a specific value.
    /// - Parameters:
    ///   - start: The starting fixed value.
    ///   - stride: The difference between subsequent calendar values.
    public init(start: Fixed<U>, stride: TimeDifference<U, Era>) {
        constructor = { FixedIterator(start: start, stride: stride, keepGoing: { _ in return true })}
    }
    
    /// Construct a sequence of fixed values starting from a specific value.
    /// - Parameters:
    ///   - start: The starting fixed value.
    ///   - stride: The difference between subsequent fixed values.
    ///   - keepGoing: A closure that is invoked to indicate whether the sequence should continue. This closure is invoked *before* the next value is generated.
    public init(start: Fixed<U>, stride: TimeDifference<U, Era>, while keepGoing: @escaping (Fixed<U>) -> Bool) {
        constructor = { FixedIterator(start: start, stride: stride, keepGoing: keepGoing)}
    }
    
    /// Construct a sequence of fixed values that iterates through a definite range of values.
    ///
    /// - Note: This sequence iterates through values *up to but not including* the upper bound of the range.
    /// - Parameters:
    ///   - range: The `Range` of fixed values to iterate through.
    ///   - stride: The difference between subsequent fixed values.
    public init<S>(range: Range<Fixed<S>>, stride: TimeDifference<U, Era>) {
        let lower = range.lowerBound
        let upper = range.upperBound.region.isEquivalent(to: lower.region) ? range.upperBound : Fixed<S>(region: lower.region, instant: range.upperBound.firstInstant)
        constructor = { FixedIterator(region: lower.region, range: lower.firstInstant ..< upper.firstInstant, stride: stride) }
    }
    
    /// Construct a sequence of fixed values that iterates through a closed range of values.
    ///
    /// - Note: This sequence iterates through values *up to and including* the upper bound of the range.
    /// - Parameters:
    ///   - range: The `ClosedRange` of fixed values to iterate through.
    ///   - stride: The difference between subsequent fixed values.
    public init<S>(range: ClosedRange<Fixed<S>>, stride: TimeDifference<U, Era>) {
        let lower = range.lowerBound
        let upper = range.upperBound.region.isEquivalent(to: lower.region) ? range.upperBound : Fixed<S>(region: lower.region, instant: range.upperBound.firstInstant)
        constructor = { FixedIterator(region: lower.region, range: lower.firstInstant ... upper.firstInstant, stride: stride) }
    }
    
    internal init<S>(parent: Fixed<S>, stride: TimeDifference<U, Era> = TimeDifference(value: 1, unit: U.requiredComponent)) {
        constructor = { FixedIterator(region: parent.region, range: parent.range, stride: stride) }
    }
    
    public __consuming func makeIterator() -> FixedIterator<U> {
        return constructor()
    }
    
}

/// An iterator of fixed values.
public struct FixedIterator<U: Unit & LTOEEra>: IteratorProtocol {
    private var algorithm: any IterationAlgorithm<U>
    
    internal init() {
        self.algorithm = EmptyAlgorithm()
    }
    
    /// Construct an iterator of fixed values starting from a specific value.
    /// - Parameters:
    ///   - start: The starting fixed value.
    ///   - stride: The difference between subsequent fixed values.
    ///   - keepGoing: A closure that is invoked to indicate whether the sequence should continue. This closure is invoked *before* the next value is generated.
    public init(start: Fixed<U>, stride: TimeDifference<U, Era>, keepGoing: @escaping (Fixed<U>) -> Bool) {
        self.algorithm = StridingAlgorithm(region: start.region,
                                           keepGoing: keepGoing,
                                           start: start,
                                           stride: stride.dateComponents)
    }
    
    /// Construct an iterator of fixed values that are within a specific range
    /// - Parameters:
    ///   - region: The ``Region`` of the fixed values
    ///   - range: The ``Instant`` range through which to iterate
    ///   - stride: The difference between subsequent fixed values
    public init(region: Region, range: Range<Instant>, stride: TimeDifference<U, Era>) {
        self.algorithm = StridingAlgorithm(
            region: region,
            keepGoing: {
                let thisRange = $0.range
                return range.lowerBound <= thisRange.lowerBound && thisRange.upperBound <= range.upperBound
            },
            start: Fixed<U>(region: region, instant: range.lowerBound),
            stride: stride.dateComponents
        )
    }
    
    /// Construct an iterator of fixed values that are within a specific closed range
    ///
    /// - Note: This sequence iterates through values *up to and including* the upper bound of the range.
    /// - Parameters:
    ///   - region: The ``Region`` of the fixed values
    ///   - range: The `ClosedRange` of ``Instant`` values to iterate through.
    ///   - stride: The difference between subsequent fixed values.
    public init(region: Region, range: ClosedRange<Instant>, stride: TimeDifference<U, Era>) {
        self.algorithm = StridingAlgorithm(region: region,
                                           keepGoing: { range.overlaps($0.range) },
                                           start: Fixed<U>(region: region, instant: range.lowerBound),
                                           stride: stride.dateComponents)
    }
    
    /// Produce the next fixed value
    /// - Returns: The next fixed value, or `nil` if there are no more values to produce.
    public mutating func next() -> Fixed<U>? {
        return algorithm.next()
    }
}

internal protocol IterationAlgorithm<U> {
    associatedtype U: Unit & LTOEEra
    
    mutating func next() -> Fixed<U>?
}

internal struct EmptyAlgorithm<U: Unit & LTOEEra>: IterationAlgorithm {
    func next() -> Fixed<U>? {
        return nil
    }
}

internal struct StridingAlgorithm<U: Unit & LTOEEra>: IterationAlgorithm {
    
    internal let region: Region
    
    internal let keepGoing: (Fixed<U>) -> Bool
    internal let start: Fixed<U>
    
    internal var scale = 0
    internal let stride: DateComponents
    
    internal mutating func next() -> Fixed<U>? {
        let next = stride.scale(by: scale)
        scale += 1
        
        let delta = TimeDifference<U, Era>(next)
        let n = start + delta
        guard keepGoing(n) else { return nil }
        return n
    }
    
}
