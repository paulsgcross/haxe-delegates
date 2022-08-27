# haxe-delegates
Small utility for Haxe that wraps function types as delegate objects. Enforces type-strictness and can be faster on some platforms (approx 40% faster for non-inlined functions and 200% faster for inlined on the hxcpp target).

## How it works:
Simply use the delegate type with a function type as your parameter, like so:
```
var delegate : Delegate<(Int, Int)->Int> = DelegateBuilder.from(myFunction);

public function myFunction(a : Int, b : Int) : Int {
    return a + b;
}
```

## Why?
Some Haxe targets are required to unbox value types from function types when called. By encapsulating function calls, we can avoid this unboxing and even enforce type-strictness on function type parameters. The following example will fail:

```
var delegate : Delegate<(Dynamic)->Void> = DelegateBuilder.from(myFunction);

// Must have Dynamic as first argument...
public function myFunction(a : Int) : Void {
    trace(a);
}
```

## Limitations:
At initial release, the delegate implementation is limited to working on class functions via their identifier and simple inlined functions without closures. Furthermore, the `DelegateBuilder` class will create an object each time.

There will be some additional weirdness not yet accounted for, so take this initial release as a proof of concept. Future work hopes to remove these limitations.
