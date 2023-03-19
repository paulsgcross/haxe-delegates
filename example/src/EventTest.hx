import hx.delegates.Delegate;

// TODO: Allow for returning wrapped types
// TODO: Composition?
class EventTest {

    public var delegate : Delegate<(Int, Int) -> Void>;

    public function new() { }

    public function execute() {
        if(this.delegate != null)
            this.delegate.call(1, 5);
    }

}
