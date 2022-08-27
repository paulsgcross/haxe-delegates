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
    private static function createFunction(ident : String, inner : (String, Array<Field>, Position) -> Void, pos : Position) : Expr {
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
        inner(ident, fields, pos);

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
        return {expr: ENew({pack: pack, name : name}, [macro{this;}]),
                pos: pos
            };
    }

    private static function handleIdentExpression(ident : String, fields : Array<Field>, pos : Position) {
        var localClass = Context.getLocalClass().get();
        var classFields = localClass.fields.get();
        var field = localClass.findField(ident);
        if(field != null) {
            var typedExpr = Context.getTypedExpr(field.expr());
            createField(ident, typedExpr, fields, pos, createInnerExpression);
        }
    }
    
    private static function handleInlineExpression(ident : String, expr : Expr, fields : Array<Field>, pos : Position) {
        createField(ident, expr, fields, pos, createFunctionExpression);
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

    private static function createFunctionExpression(name : String, expr : Expr, args : Array<FunctionArg>, ret : Null<ComplexType>, fields : Array<Field>, pos : Position) : Expr {
        return expr;
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