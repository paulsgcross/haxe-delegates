package delegates;

import utest.Assert;
import hx.delegates.Ref;
import hx.delegates.DelegateBuilder;
import hx.delegates.Delegate;

final class DelegateTest extends utest.Test {
    
    private var delegateVoid : Delegate<Void->Void>;
    private var delegateInts : Delegate<(Int, Int)->Int>;
    private var delegateArrays : Delegate<Array<Int>->Int>;
    private var arrayOfDelegates : Array<Delegate<Void->Int>>;

    public function testDelegateCapture() {
        var i = new Ref<Int>(0);
        delegateVoid = DelegateBuilder.from(()-> {
            i.value = 6;
        });
        delegateVoid.call();
        
        Assert.equals(6, i.value);
    }

    public function testSum() {
        delegateInts = DelegateBuilder.from((a : Int, b : Int)-> {
            return (a + b : Int);
        });

        var result = delegateInts.call(4, 5);
        
        Assert.equals(9, result);
    }

    public function testDelegateInClass() {
        var obj = new TestClass();
        obj.delegate = DelegateBuilder.from(() -> {
            return (5 : Int);
        });

        var result = obj.delegate.call();
        
        Assert.equals(5, result);
    }

    public function testArrayOfDelegates() {
        arrayOfDelegates = new Array();
        arrayOfDelegates.push(DelegateBuilder.from(() -> {
            return (3 : Int);
        }));
        arrayOfDelegates.push(DelegateBuilder.from(() -> {
            return (5 : Int);
        }));

        var result = 0;
        for(delegate in arrayOfDelegates) {
            result += delegate.call();
        }
        Assert.equals(8, result);
    }

    public function testArraySum() {
        delegateArrays = DelegateBuilder.from((array : Array<Int>) -> {
            var result = 0;
            for(i in array) {
                result += i;
            }
            return (result : Int);
        });

        var result = delegateArrays.call([1, 2, 3]);
        
        Assert.equals(6, result);
    }
}
