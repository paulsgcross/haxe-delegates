package hx.delegates.macros;

import haxe.macro.Expr;
import haxe.macro.Context;

final class ExpressionSearch {
    
    public static function search<T>(expr : Expr, target : String, result : Result<T>, func : (ExprDef, Result<T>) -> Void) : Void {
        var def = expr.expr;
        if(def == null)
            return;

        switch(def) {
            case EParenthesis(e):
                if(!doCheck(def, target, result, func))
                    search(e, target, result, func);
            case EReturn(e):
                if(!doCheck(def, target, result, func) && e != null)
                    search(e, target, result, func);
            case EMeta(s, e):
                if(!doCheck(def, target, result, func))
                    search(e, target, result, func);
            case ECheckType(e, t):
                if(!doCheck(def, target, result, func))
                    search(e, target, result, func);
            case EBlock(e):
                if(!doCheck(def, target, result, func)) {
                    for(es in e) {
                        search(es, target, result, func);
                    }
                }
            case ETernary(econd, eif, eelse):
                if(!doCheck(def, target, result, func)) {
                    search(econd, target, result, func);
                    search(eif, target, result, func);
                    search(eelse, target, result, func);
                }
            case EConst(c):
                doCheck(def, target, result, func);
            case EBinop(op, e1, e2):
                if(!doCheck(def, target, result, func)) {
                    search(e1, target, result, func);
                    search(e2, target, result, func);
                }
            case EThrow(e):
                if(!doCheck(def, target, result, func)) {
                    search(e, target, result, func);
                }
            case EField(e, field):
                if(!doCheck(def, target, result, func)) {
                    search(e, target, result, func);
                }
            case EArray(e1, e2):
                if(!doCheck(def, target, result, func)) {
                    search(e1, target, result, func);
                    search(e2, target, result, func);
                }
            case EArrayDecl(values):
                if(!doCheck(def, target, result, func)) {
                    for(value in values)
                        search(value, target, result, func);
                }
            case EIf(econd, eif, eelse):
                if(!doCheck(def, target, result, func)) {
                    search(econd, target, result, func);
                    search(eif, target, result, func);
                    if(eelse != null) search(eelse, target, result, func);
                }
            case EFor(it, e):
                if(!doCheck(def, target, result, func)) {
                    search(it, target, result, func);
                    search(e, target, result, func);
                }
            case EWhile(econd, e, norm):
                if(!doCheck(def, target, result, func)) {
                    search(econd, target, result, func);
                    search(e, target, result, func);
                }
            case ECall(e, params):
                if(!doCheck(def, target, result, func)) {
                    search(e, target, result, func);
                    for(param in params) {
                        search(param, target, result, func);
                    }
                }
            case EObjectDecl(fields):
                if(!doCheck(def, target, result, func)) {
                    for(field in fields)
                        search(field.expr, target, result, func);
                }
            case ESwitch(e, cases, edef):
                if(!doCheck(def, target, result, func)) {
                    search(e, target, result, func);
                    for(c in cases)
                        if(c.expr != null)
                            search(c.expr, target, result, func);

                    if(edef != null) search(edef, target, result, func);
                }
            case ETry(e, catches):
                if(!doCheck(def, target, result, func)) {
                    search(e, target, result, func);
                    for(c in catches) {
                        search(c.expr, target, result, func);
                    }
                }
            case ENew(t, params):
                if(!doCheck(def, target, result, func)) {
                    for(param in params) {
                        search(param, target, result, func);
                    }
                }
            default:
                Context.error('Delegates return expression must be unified with the desired return type', Context.currentPos());
        }
    }

    public static function doCheck<T>(def : ExprDef, target : String, result : Result<T>, func : (ExprDef, Result<T>) -> Void) : Bool {
        if(def.getName() == target) {
            func(def, result);
            return true;
        }
        return false;
    }

}

typedef Result<T> = {
    var t : Array<T>;
}