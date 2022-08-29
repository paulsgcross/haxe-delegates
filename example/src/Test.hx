import haxe.Timer;
import hx.delegates.*;

class Test {

    private var outer : Int;
    private var testFunc : (Int, Int) -> Int;
    private var testDelegate : Delegate<(Int, Int) -> Int>;

    private var testDelegate1 : Delegate<Delegate<Int -> Int> -> Void>;
    private var testDelegate2 : Delegate<Int -> Int>;

    public function new() {
        outer = 5;

        testDelegate1 = DelegateBuilder.from((d)->(d.call(3)));
        //testDelegate2 = DelegateBuilder.from((i)->(return(i+outer)));

        //testDelegate1.call(testDelegate2);
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

    public function myFunction(a : Int, b : Int) : Int {
        return a + b + outer;
    }

    public inline function myInlinedFunction(a : Int, b : Int) : Int {
        return a + b + outer;
    }

    public function doTest() {
        var N = 10000000;
        var t = Timer.stamp();
        for(i in 0...N) {
            testFunc(i, i);
        }
        trace('Function type: ' + (Timer.stamp() - t));

        var t = Timer.stamp();
        for(i in 0...N) {
            testDelegate.call(i, i);
        }
        trace('Delegate: ' + (Timer.stamp() - t));

    }
}
