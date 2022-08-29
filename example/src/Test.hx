import haxe.Timer;
import hx.delegates.Delegate;
import hx.delegates.DelegateBuilder;

// Fails on imported types...
class Test {

    private var outer : Int;
    private var testFunc : (Int, Int) -> Int;
    private var testDelegate : Delegate<(Int, Int) -> Int>;

    private var testDelegate1 : Delegate<Int->Int>;
    private var testDelegate2 : Delegate<Delegate<Int->Int> -> Void>;

    public function new() {
        outer = 5;
        
        testDelegate1 = DelegateBuilder.from(function(i) {
            return 5*i;
        });

        testDelegate2 = DelegateBuilder.from(function(d : Delegate<Int->Int>) {
            trace(d.call(2));
        });

        testDelegate2.call(testDelegate1);
    }

    public function runNoninlined() {
        trace('*** Running without inlines ***');
        testFunc = myFunction;
        //testDelegate = DelegateBuilder.from(myFunction);
        doTest();
    }

    public function runInlined() {
        trace('*** Running with inlines ***');
        testFunc = myInlinedFunction;
        //testDelegate = DelegateBuilder.from(myInlinedFunction);
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
            //testDelegate.call(i, i);
        }
        trace('Delegate: ' + (Timer.stamp() - t));

    }
}
