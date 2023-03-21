
class Main {
    static public function main() : Void {
        var test = new test.Test();
        test.runNoninlined();
        test.runInlined();
        test.runAnon();
        test.runEvent();
    }
}