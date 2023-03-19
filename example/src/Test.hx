import hx.delegates.Ref;
import haxe.ds.Vector;
import haxe.Timer;
import hx.delegates.Delegate;
import hx.delegates.DelegateBuilder;

// TODO: Allow for returning wrapped types
// TODO: Composition?
class Test {

    private var testDelegate : Delegate<(Int, Int) -> Int>;

    public function new() {
        //outer = 5;
        //delegates= new Vector(5);
        
        DelegateBuilder.from(myFunction);
        DelegateBuilder.from((a : Int, b : Int) -> (return (a+b) : Int));
        DelegateBuilder.from(function (a : Int, b : Int) {
            return (a + b : Int);
        });
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

    public function myFunction(a : Int, b : Int) : Int {
        return a + b;
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
