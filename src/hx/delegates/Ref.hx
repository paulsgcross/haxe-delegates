package hx.delegates;

@:generic final class Ref<T> {
    
    public var value : T;

    public function new(value : T) {
        this.value = value;
    }
    
}