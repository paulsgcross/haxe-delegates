package hx.delegates;

import haxe.macro.Compiler;
#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Expr.Position;

using haxe.macro.ExprTools;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;

using StringTools;
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
                var type = resolveType(f.args, f.expr);
                return createType(type, name, fields, inputs, pos);
            case EConst(CIdent(s)):
                var inputs = handleIdentExpression(s, fields, pos);
                return createType('', s, fields, inputs, pos);
            default:
                Context.error('Incorrect function type', pos);
        }
        return null;
    }

    #if macro
    private static function createType(delName : String, ident : String, fields : Array<Field>, inputs : Array<String>, pos : Position) : Expr {
        var module = Context.getLocalModule();
        var type = Context.getExpectedType();
        var delegatePack = ['delegates'];
        var delegateName = delName;

        var pack = module.toLowerCase().split('.');
        pack.insert(0, 'delegates');
        var name = '${delegateName}_${ident}';
        try {
            Context.getType(pack.join('.') + '.' + name);
        } catch (e : Dynamic) {
            Context.defineType({
                pos: pos,
                pack: pack,
                name: name,
                kind: TDClass({pack: delegatePack, name: delegateName}, null, false, true, false),
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

    private static function resolveType(args : Array<FunctionArg>, expr : Expr) : String {
        var name  = 'Delegate';

        for(arg in args) {
            if(arg.type == null)
                Context.error('Delegates must have their argument types explicitly defined', Context.currentPos());
            name += '_' + arg.type.toString();
        }

        var type = getReturnType(expr);
        name += '_' + type.toString();

        return name;
    }

    private static function getReturnType(expr : Expr) : ComplexType {
        switch(expr.expr) {
            case EParenthesis(e):
                return getReturnType(e);
            case EReturn(e):
                return getReturnType(e);
            case EMeta(s, e):
                return getReturnType(e);
            case ECheckType(e, t):
                return t;
            default:
                Context.error('Delegates return expression must be unified with the desired return type', Context.currentPos());
        }
        return null;
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
        searchUnknowns(def, args, unknowns);

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

            if(inputs.length <= 1)
                return expr;

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
    
    private static function searchUnknowns(def : ExprDef, args : Array<FunctionArg>, unknowns : Array<String>) : Void {
        var search = searchUnknowns.bind(_, args, unknowns);
        switch(def) {
            case EParenthesis(e):
                search(e.expr);
            case EMeta(s, e):
                search(e.expr);
            case EBlock(e):
                for(es in e) {
                    search(es.expr);
                }
            case EReturn(e):
                search(e.expr);
            case EBinop(op, e1, e2):
                search(e1.expr);
                search(e2.expr);
            case EField(e, field):
                search(e.expr);
            case EConst(CIdent(s)):
                if(s == 'trace')
                    return;

                for(arg in args)
                    if(arg.name == s) return;

                unknowns.push(s);
            case EArray(e1, e2):
                search(e1.expr);
                search(e2.expr);
            case EArrayDecl(values):
                for(value in values)
                    search(value.expr);
            case EIf(econd, eif, eelse):
                search(econd.expr);
                search(eif.expr);
                if(eelse != null) search(eelse.expr);
            case EFor(it, e):
                search(it.expr);
                search(e.expr);
            case EWhile(econd, e, norm):
                search(econd.expr);
                search(e.expr);
            case ECall(e, params):
                search(e.expr);
                for(param in params) {
                    search(param.expr);
                }
            case ETry(e, catches):
                search(e.expr);
                for(c in catches) {
                    search(c.expr.expr);
                }
            case EThrow(e):
                search(e.expr);
            case ETernary(econd, eif, eelse):
                search(econd.expr);
                search(eif.expr);
                search(eelse.expr);
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