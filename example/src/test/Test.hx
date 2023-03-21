package test;

import hx.delegates.Delegate;
import hx.delegates.DelegateBuilder;
import haxe.Timer;

class Test {

    private var outer : Int = 5;
    private var testDelegate : Delegate<(Int, Int) -> Int>;
    private var testFunc : (Int, Int) -> Int;

    public function new() { }

    public function runEvent() {
        var test = new EventTest();
        test.delegate = DelegateBuilder.from((a : Int, b : Int) -> (trace(a+b) : Void));
        test.delegate.call(4, 5);
    }

    public function runNoninlined() {
        trace('*** Running without inlines ***');
        testFunc = myFunction;
        testDelegate = DelegateBuilder.from(myFunction);
        doTest();
    }

    public function runInlined() {
        trace('*** Running with inlines ***');
        testFunc = myInlinedFunction;
        testDelegate = DelegateBuilder.from(myInlinedFunction);
        doTest();
    }

    public function runAnon() {
        trace('*** Running with inlines ***');
        var v = 5;
        testFunc = (a, b) -> (return a+b+outer+v);
        testDelegate = DelegateBuilder.from((a : Int, b : Int) -> (return a+b+outer+v : Int));
        doTest();
    }

    public function myFunction(a : Int, b : Int) : Int {
        return a + b + outer;
    }

    public inline function myInlinedFunction(a : Int, b : Int) : Int {
        return a + b + outer;
    }

    public function doTest() {
        var N = 50000000;
        var t = Timer.stamp();
        for(i in 0...N) {
            testFunc(i, i);
        }
        trace('Haxe function type: ' + (Timer.stamp() - t));

        var t = Timer.stamp();
        for(i in 0...N) {
            testDelegate.call(i, i);
        }
        trace('Delegate: ' + (Timer.stamp() - t));
    }
}
