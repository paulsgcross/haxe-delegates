package hx.delegates;

#if macro
import hx.delegates.macros.ExpressionSearch;
import haxe.macro.Compiler;
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
                var type = resolveType(f.args, null, f.expr);
                return createType(type, name, fields, inputs, pos);
            case EConst(CIdent(s)):
                var inputs = handleIdentExpression(s, fields, pos);
                var type = resolveIdentType(s);
                return createType(type, s, fields, inputs, pos);
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

    private static function resolveIdentType(ident : String) : String {
        var localClass = Context.getLocalClass().get();
        var classFields = localClass.fields.get();
        var field = localClass.findField(ident);
        if(field != null) {
            var typedExpr = Context.getTypedExpr(field.expr());
            switch(typedExpr.expr) {
                case EFunction(kind, f):
                    return resolveType(f.args, f.ret, f.expr);
                default:
            }
        }
        Context.error('Delegate must be function type.', Context.currentPos());
        return '';
    }

    private static function resolveType(args : Array<FunctionArg>, ret : Null<ComplexType>, expr : Expr) : String {
        var name  = 'Delegate';

        for(arg in args) {
            if(arg.type == null)
                Context.error('Delegates must have their argument types explicitly defined', Context.currentPos());
            switch(arg.type) {
                case TPath(p):
                    if(p.name == 'StdTypes')
                        name += '_' + p.sub;
                    else name += '_' + p.name;
                default:
            }
        }

        var result : Result<ComplexType> = {t: []};
        var type = null;
        if(ret == null) {
            ExpressionSearch.search(expr, 'ECheckType', result, function(def, result) {
                switch(def) {
                    case ECheckType(e, t):
                        result.t.push(t);
                    default:
                }
            });
            type = result.t[0];
        } else type = ret;

        switch(type) {
            case TPath(p):
                if(p.name == 'StdTypes')
                    name += '_' + p.sub;
                else name += '_' + p.name;
            default:
        }

        return name;
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

        var argNames = [for(arg in args) arg.name];
        var result : Result<String> = {t: []};
        ExpressionSearch.search(expr, 'EConst', result, function(def, result) {
            switch(def) {
                case EConst(CIdent(s)):
                    if(s != 'trace' && !Lambda.has(argNames, s)) result.t.push(s);
                default:
            }
        });

        var unknowns = result.t;
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
    
    
    private static function checkClassVar(name : String) : haxe.macro.Type {
        var field = Context.getLocalClass().get().findField(name);
        if(field != null) {
            return field.type;
        }

        try {
            return Context.getType(name);
        } catch (e : Dynamic) {
            return null;
        }
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