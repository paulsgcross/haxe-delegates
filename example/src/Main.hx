
import hx.delegates.Delegate;
import hx.delegates.DelegateBuilder;

class Main {
    //private static var test2 : Array<Delegate<(Int, Int) -> Int>>;
    static public function main() : Void {
        var test = new Test();
        test.runNoninlined();
        test.runInlined();
        test.runAnon();
        //test2 = DelegateBuilder.from((a, b) -> (return 3));
    }
}