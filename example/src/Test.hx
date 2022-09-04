import haxe.ds.Vector;
import haxe.Timer;
import hx.delegates.Delegate;
import hx.delegates.DelegateBuilder;

class Test {

    private var outer : Int;
    //private var testFunc : (Int, Int) -> Int;
    //private var testDelegate : Delegate<(Int, Int) -> Int>;
    private var test : Vector<Delegate<(Int, Int) -> Int>>;

    public function new() {
        test = new Vector(5);
        outer = 5;
        test[0] = DelegateBuilder.from((a : Int, b : Int) -> (return a+b : Int));
        trace('a');
    }

    public function runNoninlined() {
        trace('*** Running without inlines ***');
        //testFunc = myFunction;
        //testDelegate = DelegateBuilder.from(myFunction);
        doTest();
    }

    public function runInlined() {
        trace('*** Running with inlines ***');
        //testFunc = myInlinedFunction;
        //testDelegate = DelegateBuilder.from(myInlinedFunction);
        doTest();
    }

    public function runAnon() {
        trace('*** Running with anonymous functions ***');

        var v = 3;
        //testFunc = (a, b) -> (return a+b+outer+v);
        //testDelegate = DelegateBuilder.from((a, b) -> (return a+b+outer+v));
        doTest();
    }

    public function myFunction(a : Int, b : Int) : Int {
        return a + b + outer;
    }

    public inline function myInlinedFunction(a : Int, b : Int) : Int {
        return a + b + outer;
    }

    public function doTest() {
    //     var N = 10000000;
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

    }
}
