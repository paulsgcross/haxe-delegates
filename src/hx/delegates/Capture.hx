package hx.delegates;

#if macro
import haxe.ds.StringMap;
import haxe.macro.Context;
import haxe.macro.Expr;

using haxe.macro.ExprTools;
#end

final class Capture {

    #if macro
    public static var captures : StringMap<StringMap<Var>> = new StringMap();
    #end

    public static macro function of(expr : Expr) : Expr {
        var method = Context.getLocalMethod();
        var localclass = Context.getLocalClass().get().name;
        var localpack = Context.getLocalClass().get().pack;

        var callLoc = localpack.length > 0
            ? '${localpack.join('.')}.${localclass}.${method}'
            : '${localclass}.${method}';

        var capture = captures.get(callLoc);
        if(capture == null) {
            capture = new StringMap();
            captures.set(callLoc, capture);
        }

        switch(expr.expr) {
            case EVars(vars):
                for(v in vars) {
                    capture.set(v.name, v);
                }
            default:
        }

        return expr;
    }
}
