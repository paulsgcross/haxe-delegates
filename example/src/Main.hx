
class Main {
    static public function main() : Void {
        var test = new Test();
        test.runNoninlined();
        test.runInlined();
        test.runAnon();
    }
}