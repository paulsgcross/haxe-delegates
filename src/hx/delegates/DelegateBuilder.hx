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
    
    private static var count : Int = 0;
    
    public static macro function from(expr : Expr) : Expr {
        var pos = Context.currentPos();
        var exprdef = expr.expr;
        var field = null;
        switch(exprdef) {
            case EFunction(kind, f):
                return handleFunctionExpression('Inline' + count++, f);
            case EConst(CIdent(s)):
                var func = getFunctionFromIdent(s);
                return handleFunctionExpression(s, func);
            default:
                Context.error('Incorrect function type', pos);
        }
        
        return macro {};
    }

    #if macro

    private static function getFunctionFromIdent(ident : String) : Function {
        var localClass = Context.getLocalClass().get();
        var classFields = localClass.fields.get();
        var field = localClass.findField(ident);
        if(field != null) {
            var expr = Context.getTypedExpr(field.expr());
            switch(expr.expr) {
                case EFunction(kind, f):
                    return f;
                default:
            }
        }
        return null;
    }

    private static function handleFunctionExpression(ident : String, func : Function) : Expr {
        var fields = [];

        var type = resolveSuperType(func);
        createType(type, ident, fields);

        return macro {};
    }

    private static function createType(superPath : TypePath, name : String, fields : Array<Field>) : Void {
        var module = Context.getLocalModule();
        var type = Context.getExpectedType();
        var packageName = 'delegates';
        var className = 'Delegate_${name}';
        try {
            Context.getType('${packageName}.${module.toLowerCase()}.${className}');
        } catch (e : Dynamic) {
            Context.defineType({
                pos: Context.currentPos(),
                pack: [packageName, module.toLowerCase()],
                name: className,
                kind: TDClass(null, null, false, true, false),
                fields: fields
            });
        }
    }

    private static function resolveSuperType(func : Function) : TypePath {
        var name = '';
        for(arg in func.args) {
            name += '${getTypeName(arg.type)}_';
        }

        if(func.ret == null) {
            name += findReturnType(func.expr);
        } else name += getTypeName(func.ret);
        
        return {pack: ['delegates'], name: 'Delegates_${name}'};
    }

    private static function getTypeName(type : ComplexType) : String {
        switch(type) {
            case TPath(p):
                if (p.name == 'StdTypes') {
                    return p.sub;
                } else return p.name;
            default:
        }
        return '';
    }

    private static function findReturnType(expr : Expr) : String {
        var out = new Out();
        ExpressionSearch.search(expr, 'ECheckType', out);
        switch(out.expr.expr) {
            case ECheckType(e, t):
                return getTypeName(t);
            default:
        }
        return '';
    }

    #end
}