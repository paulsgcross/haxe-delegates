package hx.delegates;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Expr.Position;

using haxe.macro.ExprTools;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;
#end

final class DelegateBuilder {
    
    private static var _delegateCount : Int = 0;
    
    public static macro function from(expr : Expr) : Expr {
        var pos = Context.currentPos();
        var exprdef = expr.expr;
        var fields = [];
        var inputs = [];
        switch(exprdef) {
            case EFunction(kind, f):
                var name = 'inline${_delegateCount++}';
                var inputs = handleInlineExpression(name, expr, fields, pos);
                return createType(name, fields, inputs, pos);
            case EConst(CIdent(s)):
                var inputs = handleIdentExpression(s, fields, pos);
                return createType(s, fields, inputs, pos);
            default:
                Context.error('Incorrect function type', pos);
        }
        return null;
    }

    #if macro
    private static function createType(ident : String, fields : Array<Field>, inputs : Array<String>, pos : Position) : Expr {
        var module = Context.getLocalModule();
        var type = Context.getExpectedType();
        var expectedPack = [];
        var expectedName = '';
        switch(type) {
            case TInst(t, params):
                expectedPack = t.get().pack;
                expectedName = t.get().name;
            default:
        }

        var pack = module.toLowerCase().split('.');
        pack.insert(0, 'delegates');
        var name = '${expectedName}_${ident}';

        try {
            Context.getType(pack.join('.') + '.' + name);
        } catch (e : Dynamic) {
            Context.defineType({
                pos: pos,
                pack: pack,
                name: name,
                kind: TDClass({pack: expectedPack, name: expectedName}, null, false, true, false),
                fields: fields
            });
        }

        var params = [];
        for(s in inputs) {
            params.push({expr: EConst(CIdent(s)), pos: pos});
        }

        return {expr: ENew({pack: pack, name : name}, params),
                pos: pos
            };
    }

    private static function handleIdentExpression(ident : String, fields : Array<Field>, pos : Position) : Array<String> {
        var localClass = Context.getLocalClass().get();
        var classFields = localClass.fields.get();
        var field = localClass.findField(ident);
        if(field != null) {
            var typedExpr = Context.getTypedExpr(field.expr());
            return createField(ident, typedExpr, fields, createInnerExpression, pos);
        }
        return [];
    }
    
    private static function handleInlineExpression(ident : String, expr : Expr, fields : Array<Field>, pos : Position) : Array<String> {
        return createField(ident, expr, fields, createFunctionExpression, pos);
    }

    private static function convertToEField(path : String) : Expr {
        var patharray = path.split('.');
        var current = createExpression(EConst(CIdent(patharray[0])));
        for(i in 1...patharray.length) {
            current = createExpression(EField(current, patharray[i]));
        }
        return current;
    }

    private static function createField(name : String, expr : Expr, fields : Array<Field>, inner : BuildType, pos : Position) : Array<String> {
        var inputs = [];
        switch(expr.expr) {
            case EFunction(kind, f):
                fields.push({
                    name: 'call',
                    access: [APublic],
                    kind: FFun({
                        args: f.args,
                        expr: inner(name, f.expr, f.args, f.ret, fields, inputs, pos),
                        ret: f.ret
                    }),
                    pos: pos,
                    meta: [{name: ':access', params: [convertToEField(Context.getLocalModule())], pos: pos}]
                });
            default:
        }
        return inputs;
    }

    private static function createFunctionExpression(name : String, expr : Expr, args : Array<FunctionArg>, ret : Null<ComplexType>, fields : Array<Field>, inputs : Array<String>, pos : Position) : Expr {
        var def = expr.expr;
        if(def == null)
            return expr;

        var unknowns = [];
        searchUnknowns(def, unknowns);

        var vs = Context.getLocalTVars();
        inputs.push('this');
        if(unknowns.length > 0) {
            var newargs = [{name: 'parent'}];
            for (unknown in unknowns) {
                var type = null;
                var v = vs.get(unknown);
                if(v == null) {
                    type = checkClassVar(unknown);
                } else {
                    type = v.t;
                }

                newargs.push({
                    name: unknown
                });

                fields.push({
                    name: unknown,
                        access: [APrivate],
                        kind: FVar(type.toComplexType(), null),
                    pos: pos
                });

                inputs.push(unknown);
            }

            var exprs : Array<Expr> = [];
            for(input in inputs) {
                if(input == 'this')
                    continue;

                var expr = macro {
                    $p{['this', input]} = $i{input}
                };
                exprs.push(expr);
            }

            fields.push({
                name: 'new',
                    access: [APublic],
                    kind: FFun({
                        args: newargs,
                        expr: macro {
                            super(_parent);
                            $b{exprs};
                        }
                    }),
                pos: pos
            });
        }

        return expr;
    }
    
    private static function searchUnknowns(def : ExprDef, unknowns : Array<String>) : Void {
        switch(def) {
            case EParenthesis(e):
                searchUnknowns(e.expr, unknowns);
            case EMeta(s, e):
                searchUnknowns(e.expr, unknowns);
            case EBlock(e):
                for(es in e) {
                    searchUnknowns(es.expr, unknowns);
                }
            case EReturn(e):
                searchUnknowns(e.expr, unknowns);
            case EBinop(op, e1, e2):
                searchUnknowns(e1.expr, unknowns);
                searchUnknowns(e2.expr, unknowns);
            case EField(e, field):
                searchUnknowns(e.expr, unknowns);
            case EConst(CIdent(s)):
                unknowns.push(s);
            case EArray(e1, e2):
                searchUnknowns(e1.expr, unknowns);
                searchUnknowns(e2.expr, unknowns);
            case EArrayDecl(values):
                for(value in values)
                    searchUnknowns(value.expr, unknowns);
            case EIf(econd, eif, eelse):
                searchUnknowns(econd.expr, unknowns);
                searchUnknowns(eif.expr, unknowns);
                if(eelse != null) searchUnknowns(eelse.expr, unknowns);
            case EFor(it, e):
                searchUnknowns(it.expr, unknowns);
                searchUnknowns(e.expr, unknowns);
            case EWhile(econd, e, norm):
                searchUnknowns(econd.expr, unknowns);
                searchUnknowns(e.expr, unknowns);
            case ECall(e, params):
                searchUnknowns(e.expr, unknowns);
                for(param in params) {
                    searchUnknowns(param.expr, unknowns);
                }
            case ETry(e, catches):
                searchUnknowns(e.expr, unknowns);
                for(c in catches) {
                    searchUnknowns(c.expr.expr, unknowns);
                }
            case EThrow(e):
                searchUnknowns(e.expr, unknowns);
            case ETernary(econd, eif, eelse):
                searchUnknowns(econd.expr, unknowns);
                searchUnknowns(eif.expr, unknowns);
                searchUnknowns(eelse.expr, unknowns);
            default:
        }
    }
    
    private static function checkClassVar(name : String) : haxe.macro.Type {
        var field = Context.getLocalClass().get().findField(name);
        if(field != null) {
            return field.type;
        }
        return null;
    }
    
    private static function createInnerExpression(name : String, expr : Expr, args : Array<FunctionArg>, ret : Null<ComplexType>, fields : Array<Field>, inputs : Array<String>, pos : Position) : Expr {
        var ident = createExpression(EConst(CIdent('_parent')));
        var field = createExpression(EField(ident, name));
        var inner = createExpression(ECall(field, [for(arg in args) createExpression(EConst(CIdent(arg.name)))]));
        inputs.push('this');
        if(ret == null)
            return inner;
        else return createExpression(EReturn(inner));
    }
    
    private static function createExpression(def : ExprDef) : Expr {
        return {expr: def, pos: Context.currentPos()};
    }
    #end
}

#if macro
typedef BuildType = (String, Expr, Array<FunctionArg>, Null<ComplexType>, Array<Field>, Array<String>, pos : Position) -> Expr;
#end