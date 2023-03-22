package test;

import hx.delegates.Ref;
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
        test.delegate = DelegateBuilder.from((a : Int, b : Int) -> {
            var x = 3;
            trace(a+b+x);
        });
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
        trace('*** Running with anonymous functions ***');
        var v = 5;
        testFunc = (a, b) -> (return a+b+outer+v);

        testDelegate = DelegateBuilder.from((a : Int, b : Int) -> (return a+b+outer+v : Int));
        
        doTest();
    }

    public function runCapture() {
        trace('*** Running scope capture ***');
        var t = Timer.stamp();
        var v = 5;
        var func = () -> (v = 7);
        func();
        trace(v);
        trace('Scope capture: ' + (Timer.stamp() - t));

        var t = Timer.stamp();
        var v = new Ref<Int>(5);
        var delegate : Delegate<Void->Void> = DelegateBuilder.from(() -> (v.value = 7));
        delegate.call();
        trace(v.value);
        trace('Delegate capture: ' + (Timer.stamp() - t));
    }

    public function testArrayFunc(arr : Array<Int>) : Int {
        return 0;
    }

    public function myFunction(a : Int, b : Int) : Int {
        return a + b + outer;
    }

    public inline function myInlinedFunction(a : Int, b : Int) : Int {
        return a + b + outer;
    }

    public function doTest() {
        var N = 1000000;
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

class MyObject {
    public function new() {}
}