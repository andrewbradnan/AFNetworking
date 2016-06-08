/**
 # Event.swift
 ## SwiftCommon
 
 - Author: Andrew Bradnan
 - Date: 6/7/16
 - Copyright:
 */

import Foundation

struct EventLifeCycle : OptionSetType {
    let rawValue: Int
    init(rawValue: Int) { self.rawValue = rawValue }
    
    static let Permanent = EventLifeCycle(rawValue: 1)
    static let FireOnce = EventLifeCycle(rawValue: 2)
    static let Skipable = EventLifeCycle(rawValue: 4)
}

protocol EventType {
    var lifeCycle: EventLifeCycle { get }
}

extension EventType {
    var isFireOnce: Bool { get { return self.lifeCycle.contains(.FireOnce) }}
    var isSkipable: Bool { get { return self.lifeCycle.contains(.Skipable) }}
}

func notify<C: CollectionType where C.Generator.Element : EventType /*, C.Generator.Element : Equatable */>(events: C, ffwd: Bool, inout fired: Bool, fire: C.Generator.Element->Void) -> C {
    let rt = events
    fired = false
    
    for e in events {
        
        if !ffwd || !e.isSkipable {
            fired = true
            //e.fire()
            fire(e)
        }
        //if e.isFireOnce {
        //    rt.removeFirst( {e == $0})
        // }
    }
    return rt
}

protocol EventParamType : EventType {
    associatedtype Element
    func fire(param: Element)
}

/*
extension EventType {
 
    static func notify<C: CollectionType where C.Generator.Element : EventType, C.Generator.Element : Equatable>(events: C, ffwd: Bool, inout fired: Bool, fire: EventType->Void) -> C {
        var rt = events
        fired = false
        
        for e in events {
            
            if !ffwd || !e.isSkipable {
                fired = true
                //e.fire()
                fire(e)
            }
            
            //if e.isFireOnce {
            //    rt.removeFirst( {e == $0})
           // }
        }
        return rt
    }
}
*/

/*
 class Event : NSObject, EventType
 {
 let lifeCycle : EventLifeCycle
 
 internal let dbg: String
 
 init(dbg: String, lifeCycle: EventLifeCycle) {
 self.dbg = dbg
 self.lifeCycle = lifeCycle
 }
 
 func fire() {
 /* should be abstract */
 }
 
 };
 */

//class EventParam<T> : EventParamType {
//
//    override init(dbg: String, lifeCycle: EventLifeCycle) {
//        super.init(dbg: dbg, lifeCycle: lifeCycle)
//    }
//
//
//    func fire(param: T) {
//        /* should be abstract */
//    }

//extension EventParamType {
//    static func notify<C: CollectionType where C.Generator.Element == EventParamType>(events: C, ffwd: Bool, param: Self, inout fired: Bool) -> C {
//        var rt = events
//        fired = false
//        
//        for e in events {
//            
//            if !ffwd || !e.isSkipable {
//                fired = true
//                e.fire(param)
//            }
//            
//            if e.isFireOnce {
//                rt.remove(e)
//            }
//        }
//        return rt
//    }
//}

class LambdaCallbackParam<T> : EventParamType {
    let block : (T) -> Void
    let lifeCycle : EventLifeCycle
    
    internal let dbg: String
    
    init(dbg: String, block: T->Void, life: EventLifeCycle)
    {
        self.dbg = dbg
        self.block = block
        self.lifeCycle = life
    }
    
    func fire(param: T) { block(param) }
}

enum EventTriggerType {
    case Auto
    case Manual(Bool)   // set or not
}

class Event<T> {
    typealias EventBlock = T->Void
    var events : [LambdaCallbackParam<T>] = []
    var triggerType: EventTriggerType
    var param: T!
    
    init (manual: Bool = false) {
        self.triggerType = .Manual(false)
    }
    
    func removeAll(keepCapacity: Bool) {
        events.removeAll(keepCapacity: false)
    }
    
    func addBlock(dbg: String, life: EventLifeCycle, block: EventBlock) {
        if case .Manual(let eventSet) = self.triggerType where eventSet == true {
            block(self.param)
            
            // if we aren't FireOnce, then add to the list of events
            if !life.contains(.FireOnce) {
                events.append(LambdaCallbackParam<T>(dbg: dbg, block: block, life: life))
            }
        }
        else {
            events.append(LambdaCallbackParam<T>(dbg: dbg, block: block, life: life))
        }
    }
    
    func fire(param: T) {
        if case .Manual(_) = self.triggerType {
            self.triggerType = .Manual(true)
            self.param = param
        }

        var fired: Bool = false
        notify(self.events, ffwd: false, fired: &fired, fire: { $0.fire(param) })
    }
}

class Test<T> {
    typealias EventBlock = T->Void
    var events: [LambdaCallbackParam<T>] = []
    
    func addBlock(dbg: String, life: EventLifeCycle, block: EventBlock) {
    }
}

func foo() {
    let t = Event<Void>()
    t.fire()
    t.addBlock("foo", life: .FireOnce, block: { NSLog("foo") })
}

/*
class EventParam<T> /*:Array<Event<T> >*/ {
    var events : [EventParam<T>] = []
    var triggerType: EventTriggerType
    var param : T!
    
    init (manual: Bool = false) {
        self.triggerType = manual ? .Manual(false) : .Auto
    }
    
    func removeAll(keepCapacity: Bool) {
        events.removeAll(keepCapacity: false)
    }
    
    func addBlock(dbg: String, life: EventLifeCycle, block: (T) -> Void) {
        if case .Manual(let eventSet) = self.triggerType where eventSet == true {
            
            block(param!)
            // if we aren't FireOnce, then add to the list of events
            if ((life.rawValue & EventLifeCycle.FireOnce.rawValue) == 0) {
                events.append(LambdaCallbackParam<T>(dbg: dbg, block: block, life: life))
            }
        }
        else {
            events.append(LambdaCallbackParam<T>(dbg: dbg, block: block, life: life))
        }
    }
    
    func fire(param: T) {
        if (manual) {
            eventSet = true
            self.param = param
        }
        EventParam<T>.notify(&events, ffwd: false, param: param)
    }
}
*/