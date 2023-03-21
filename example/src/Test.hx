import sys.thread.EventLoop;
import hx.delegates.Ref;
import haxe.ds.Vector;
import haxe.Timer;
import hx.delegates.Delegate;
import hx.delegates.DelegateBuilder;

// TODO: Allow for returning wrapped types
// TODO: Composition?
class Test {

    private var _delegate : Delegate<(Int, Int) -> Void>;
    public var _outer : Int = 5;
    public function new() {
        var event = new EventTest();
        event.delegate = DelegateBuilder.from(myFunction);
        trace(event.delegate.call(3, 1));
        
        _delegate = DelegateBuilder.from(myFunctionTest);
        _delegate.call(4, 3);
        
        var g = 6;
        event.delegate = DelegateBuilder.from((a : Int, b : Int) -> (return (a+b+g+_outer) : Int));
        trace(event.delegate.call(3, 1));
        
        // testDelegate = DelegateBuilder.from(function(a : Int, b : Int) {
        //     return ((a+b) : Int);
        // });
        // trace(testDelegate.call(0, 1));
    }

    // public function runEvent() {
    //     var test = new EventTest();
    //    // test.delegate = DelegateBuilder.from((a : Int, b : Int) -> (trace(a+b) : Void));
    //     test.execute();
    // }

    // public function runNoninlined() {
    //     trace('*** Running without inlines ***');
    //     testFunc = myFunction;
    //     testDelegate = DelegateBuilder.from(myFunction);
    //     doTest();
    // }

    // public function runInlined() {
    //     trace('*** Running with inlines ***');
    //     testFunc = myInlinedFunction;
    //     testDelegate = DelegateBuilder.from(myInlinedFunction);
    //     doTest();
    // }

    // public function runAnon() {
    //     trace('*** Running with inlines ***');
    //     var v = 5;
    //     testFunc = (a, b) -> (return a+b+outer+v);
    //     testDelegate = DelegateBuilder.from((a : Int, b : Int) -> (return a+b+outer+v : Int));
    //     doTest();
    // }

    // public function runReferenced() {
    //     trace('*** Running with references ***');

    //     var refout = new Ref(0);
    //     testFuncRef = (a, b) -> {
    //         refout.value = a.value+b.value;
    //         return refout;
    //     };
    //     testFunc = (a, b) -> (return a+b);

    //     var N = 50000000;
    //     var t = Timer.stamp();
    //     for(i in 0...N) {
    //         testFunc(i, i);
    //     }
    //     trace('Haxe function type: ' + (Timer.stamp() - t));

    //     var t = Timer.stamp();
    //     var ref = new Ref(0);
    //     for(i in 0...N) {
    //         ref.value = i;
    //         testFuncRef(ref, ref);
    //     }
    //     trace('Function type with ref: ' + (Timer.stamp() - t));
    // }

    inline public function myFunction(a : Int, b : Int) : Int {
        return a + b;
    }

    inline public function myFunctionTest(a : Int, b : Int) : Void {
        trace(a + b);
    }

    // public inline function myInlinedFunction(a : Int, b : Int) : Int {
    //     return a + b + outer;
    // }

    // public function doTest() {
    //     var N = 50000000;
    //     var t = Timer.stamp();
    //     for(i in 0...N) {
    //         testFunc(i, i);
    //     }
    //     trace('Haxe function type: ' + (Timer.stamp() - t));

    //     var t = Timer.stamp();
    //     for(i in 0...N) {
    //         testDelegate.call(i, i);
    //     }
    //     trace('Delegate: ' + (Timer.stamp() - t));
    // }
}
