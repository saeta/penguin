/// Conform Bool to comparible.
///
/// This is required in order to use Bool's inside of Penguin.
extension Bool: Comparable {

    /// Comparis lhs to rhs.
    ///
    /// Returns true if lhs is false, and rhs is true, false otherwise.
    /// This definition was chosen in order to match the behavior of a UInt-equivalent
    /// representation, where false is represented as 0, and true as any other number.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (false, true): return true
        case (true, false): return false
        case (true, true): return false
        case (false, false): return false
        }
    }
}
