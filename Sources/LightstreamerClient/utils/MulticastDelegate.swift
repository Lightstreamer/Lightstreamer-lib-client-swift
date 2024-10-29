import Foundation

/**
 * `MulticastDelegate` lets you easily create a "multicast delegate" for a given protocol or class.
 *
 * Adapted from https://github.com/jonasman/MulticastDelegate
 */
class MulticastDelegate<T> {
    
    /// The delegates hash table.
    let delegates: NSHashTable<AnyObject> = NSHashTable<AnyObject>()
    
    /**
     *  Use the property to check if no delegates are contained there.
     *
     *  - returns: `true` if there are no delegates at all, `false` if there is at least one.
     */
    public var isEmpty: Bool {
        
        return delegates.allObjects.count == 0
    }
    
    /**
     *  Use this method to add a delelgate.
     *
     *  - parameter delegate:  The delegate to be added.
     */
    public func addDelegate(_ delegate: T) {
        
        delegates.add(delegate as AnyObject)
    }
    
    /**
     *  Use this method to remove a previously-added delegate.
     *
     *  - parameter delegate:  The delegate to be removed.
     */
    public func removeDelegate(_ delegate: T) {
        
        delegates.remove(delegate as AnyObject)
    }
    
    /**
     *  Use this method to invoke a closure on each delegate.
     *
     *  - parameter invocation: The closure to be invoked on each delegate.
     */
    public func invokeDelegates(_ invocation: (T) -> ()) {
        
        for delegate in delegates.allObjects {
            invocation(delegate as! T)
        }
    }
    
    /**
     *  Use this method to determine if the multicast delegate contains a given delegate.
     *
     *  - parameter delegate:   The given delegate to check if it's contained
     *
     *  - returns: `true` if the delegate is found or `false` otherwise
     */
    public func containsDelegate(_ delegate: T) -> Bool {
        
        return delegates.contains(delegate as AnyObject)
    }
    
    public func getDelegates() -> [T] {
        return delegates.allObjects as! [T]
    }
}
