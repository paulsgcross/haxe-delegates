package hx.delegates.macros;

import haxe.macro.Expr;
import haxe.macro.Context;

final class ExpressionSearch {
    
    public static function search(expr : Expr, target : String, out : Out) : Void {
        var def = expr.expr;
        if(def == null)
            return;

        out.expr = expr;

        switch(def) {
            case EParenthesis(e):
                if(!doCheck(def, target))
                    search(e, target, out);
            case EReturn(e):
                if(!doCheck(def, target) && e != null)
                    search(e, target, out);
            case EMeta(s, e):
                if(!doCheck(def, target))
                    search(e, target, out);
            case ECheckType(e, t):
                if(!doCheck(def, target))
                    search(e, target, out);
            case EBlock(e):
                if(!doCheck(def, target)) {
                    for(es in e) {
                        search(es, target, out);
                    }
                }
            case ETernary(econd, eif, eelse):
                if(!doCheck(def, target)) {
                    search(econd, target, out);
                    search(eif, target, out);
                    search(eelse, target, out);
                }
            case EConst(c):
                doCheck(def, target);
            case EBinop(op, e1, e2):
                if(!doCheck(def, target)) {
                    search(e1, target, out);
                    search(e2, target, out);
                }
            case EThrow(e):
                if(!doCheck(def, target)) {
                    search(e, target, out);
                }
            case EField(e, field):
                if(!doCheck(def, target)) {
                    search(e, target, out);
                }
            case EArray(e1, e2):
                if(!doCheck(def, target)) {
                    search(e1, target, out);
                    search(e2, target, out);
                }
            case EArrayDecl(values):
                if(!doCheck(def, target)) {
                    for(value in values)
                        search(value, target, out);
                }
            case EIf(econd, eif, eelse):
                if(!doCheck(def, target)) {
                    search(econd, target, out);
                    search(eif, target, out);
                    if(eelse != null) search(eelse, target, out);
                }
            case EFor(it, e):
                if(!doCheck(def, target)) {
                    search(it, target, out);
                    search(e, target, out);
                }
            case EWhile(econd, e, norm):
                if(!doCheck(def, target)) {
                    search(econd, target, out);
                    search(e, target, out);
                }
            case ECall(e, params):
                if(!doCheck(def, target)) {
                    search(e, target, out);
                    for(param in params) {
                        search(param, target, out);
                    }
                }
            case EObjectDecl(fields):
                if(!doCheck(def, target)) {
                    for(field in fields)
                        search(field.expr, target, out);
                }
            case ESwitch(e, cases, edef):
                if(!doCheck(def, target)) {
                    search(e, target, out);
                    for(c in cases)
                        if(c.expr != null)
                            search(c.expr, target, out);

                    if(edef != null) search(edef, target, out);
                }
            case ETry(e, catches):
                if(!doCheck(def, target)) {
                    search(e, target, out);
                    for(c in catches) {
                        search(c.expr, target, out);
                    }
                }
            case ENew(t, params):
                if(!doCheck(def, target)) {
                    for(param in params) {
                        search(param, target, out);
                    }
                }
            default:
                Context.error('Delegates return expression must be unified with the desired return type', Context.currentPos());
        }
    }

    public static function doCheck(def : ExprDef, target : String) : Bool {
        return (def.getName() == target);
    }

}

final class Out {
    public var expr : Expr;
    public function new() {}
}