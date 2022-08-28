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
        switch(exprdef) {
            case EFunction(kind, f):
                return createFunction('inline${_delegateCount++}', handleInlineExpression.bind(_, expr, _, _), pos);
            case EConst(CIdent(s)):
                return createFunction(s, handleIdentExpression, pos);
            default:
                Context.error('Incorrect function type', pos);
        }
        return null;
    }

    #if macro
    private static function createFunction(ident : String, inner : (String, Array<Field>, Position) -> Array<String>, pos : Position) : Expr {
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
        
        var fields : Array<Field> = [];
        var inputs = inner(ident, fields, pos);

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
            createField(ident, typedExpr, fields, pos, createInnerExpression);
        }
        return ['this'];
    }
    
    private static function handleInlineExpression(ident : String, expr : Expr, fields : Array<Field>, pos : Position) {
        var inputs = [];
        createField(ident, expr, fields, pos, createFunctionExpression.bind(_, _, _, _, _, _, inputs));
        return inputs;
    }

    private static function convertToEField(path : String) : Expr {
        var patharray = path.split('.');
        var current = createExpression(EConst(CIdent(patharray[0])));
        for(i in 1...patharray.length) {
            current = createExpression(EField(current, patharray[i]));
        }
        return current;
    }

    private static function createField(name : String, expr : Expr, fields : Array<Field>, pos : Position, inner : BuildType) : Void {
        switch(expr.expr) {
            case EFunction(kind, f):
                fields.push({
                    name: 'call',
                    access: [APublic],
                    kind: FFun({
                        args: f.args,
                        expr: inner(name, f.expr, f.args, f.ret, fields, pos),
                        ret: f.ret
                    }),
                    pos: pos,
                    meta: [{name: ':access', params: [convertToEField(Context.getLocalModule())], pos: pos}]
                });
            default:
        }
    }

    private static function createFunctionExpression(name : String, expr : Expr, args : Array<FunctionArg>, ret : Null<ComplexType>, fields : Array<Field>, pos : Position, inputs : Array<String>) : Expr {
        var def = expr.expr;
        if(def == null)
            return expr;

        var unknowns = [];
        searchUnknowns(def, unknowns);

        var vs = Context.getLocalTVars();
        trace(vs);

        inputs.push('this');
        if(unknowns.length > 0) {
            var newargs = [{name: 'parent'}];
            for (unknown in unknowns) {
                var v = vs.get(unknown);
                if(v == null)
                    continue;

                newargs.push({
                    name: unknown
                });

                fields.push({
                    name: unknown,
                        access: [APrivate],
                        kind: FVar(v.t.toComplexType(), null),
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
            case EConst(CIdent(s)):
                unknowns.push(s);
            default:
        }
    }
    
    private static function createInnerExpression(name : String, expr : Expr, args : Array<FunctionArg>, ret : Null<ComplexType>, fields : Array<Field>, pos : Position) : Expr {
        var ident = createExpression(EConst(CIdent('_parent')));
        var field = createExpression(EField(ident, name));
        var inner = createExpression(ECall(field, [for(arg in args) createExpression(EConst(CIdent(arg.name)))]));
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
typedef BuildType = (String, Expr, Array<FunctionArg>, Null<ComplexType>, Array<Field>, pos : Position) -> Expr;
#end