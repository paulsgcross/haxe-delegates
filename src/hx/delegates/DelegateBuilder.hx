package hx.delegates;

import haxe.macro.Expr.ComplexType;
import haxe.macro.Expr.TypePath;
#if macro
import hx.delegates.macros.ExpressionSearch;
import haxe.macro.Compiler;
import haxe.macro.Expr;
import haxe.macro.Type.TVar;
import haxe.macro.Type;
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
                return handleFunctionExpression('Inline' + count++, f, FunctionType.Inline);
            case EConst(CIdent(s)):
                var func = getFunctionFromIdent(s);
                return handleFunctionExpression(s, func, FunctionType.Ident);
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

    private static function handleFunctionExpression(ident : String, func : Function, funcType : FunctionType) : Expr {
        var fields = [];

        var type = resolveSuperType(func);

        var scope = handleVaribleScope(func);
        createClassVars(scope, fields);
        var newVars = createNew(scope, fields);
        
        switch(funcType) {
            case Inline:
                fields.push(createIdentCall(type, func.expr));
            case Ident:
                fields.push(createInlineCall(type, func.expr));
        }

        var typePath = createType(type, ident, fields);

        return createInstantiation(typePath, newVars);
    }

    private static function createType(superPath : SuperType, name : String, fields : Array<Field>) : TypePath {
        var module = Context.getLocalModule();
        var packageName = 'delegates';
        var className = 'Delegate_${name}';
        try {
            Context.getType('${packageName}.${module.toLowerCase()}.${className}');
        } catch (e : Dynamic) {
            Context.defineType({
                pos: Context.currentPos(),
                pack: [packageName, module.toLowerCase()],
                name: className,
                kind: TDClass(superPath.typePath, null, false, true, false),
                fields: fields
            });
        }
        return {pack: [packageName, module.toLowerCase()], name: className};
    }

    private static function resolveSuperType(func : Function) : SuperType {
        var superType = new SuperType();
        
        var name = '';
        for(arg in func.args) {
            name += '${getTypeName(arg.type)}_';
            superType.args.push(arg.type);
        }

        if(func.ret == null) {
            var type = findReturnType(func.expr);
            name += getTypeName(type);
            superType.ret = type;
        } else {
            name += getTypeName(func.ret);
            superType.ret = func.ret;
        }

        superType.typePath = {pack: ['delegates'], name: 'Delegate_${name}'};

        return superType;
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

    private static function findReturnType(expr : Expr) : ComplexType {
        var out = new Out();
        ExpressionSearch.search(expr, 'ECheckType', out);

        if(out.exprs.length <= 0)
            return null;

        switch(out.exprs[0].expr) {
            case ECheckType(e, t):
                return t;
            default:
        }
        return null;
    }

    private static function createClassVars(scope : ScopedVariables, fields : Array<Field>) : Void {
        var callerType = Context.getLocalType().toComplexType();
        fields.push({
            name: '_parent',
                access: [APrivate],
                kind: FVar(callerType, null),
            pos: Context.currentPos()
        });

        for(entry in scope.local.keyValueIterator()) {
            var name = entry.key;
            var type = entry.value;
            fields.push({
                name: '_${name}',
                    access: [APrivate],
                    kind: FVar(type, null),
                pos: Context.currentPos()
            });
        }
    }

    private static function createNew(scope : ScopedVariables, fields : Array<Field>) : Array<String> {
        var callerType = Context.getLocalType().toComplexType();
        var args = [];
        var exprs = [];
        var outVars = [];
        args.push({name: 'parent', type: callerType});
        exprs.push(macro{ $i{'_parent'} = $i{'parent'}; });

        for(entry in scope.local.keyValueIterator()) {
            var name = entry.key;
            var type = entry.value;
            args.push({name: name, type: type});

            exprs.push(macro{ $i{'_$name'} = $i{name}; });

            outVars.push(name);
        }

        fields.push({
            name: 'new',
                access: [APublic],
                kind: FFun({
                    args: args,
                    expr: macro {$b{exprs}}
                }),
            pos: Context.currentPos()
        });

        return outVars;
    }

    private static function createIdentCall(superType : SuperType, funcExpr : Expr) : Field {
        return createCall(superType, funcExpr, macro {return 0;});
    }

    private static function createInlineCall(superType : SuperType, funcExpr : Expr) : Field {
        return createCall(superType, funcExpr, macro {return 0;});
    }

    private static function createCall(superType : SuperType, funcExpr : Expr, innerExpr : Expr) : Field {
        var index = 0;
        var argName = 'arg';

        var funcArg = [];
        for(arg in superType.args) {
            funcArg.push({name: '$argName${index++}', type: arg});
        }

        return {
            name: 'call',
                access: [APublic],
                kind: FFun({
                    args: funcArg,
                    expr: innerExpr,
                    ret: superType.ret
                }),
            pos: Context.currentPos()
        };
    }

    private static function createInstantiation(typePath : TypePath, inVars : Array<String>) : Expr {
        var exprs = [for(name in inVars) macro {$i{name}}];
        exprs.insert(0, macro {this;});

        return macro {new $typePath($a{exprs});};
    }

    private static function handleVaribleScope(func : Function) : ScopedVariables {
        var scoped = new ScopedVariables();

        var out = new Out();
        ExpressionSearch.search(func.expr, 'EField', out);
        ExpressionSearch.search(func.expr, 'EConst', out);
        
        var localVars = Context.getLocalTVars();
        var inArgs = [for(arg in func.args) arg.name => arg];
        var funcArgs = [for(arg in out.exprs) switch(arg.expr) {
            case EConst(CIdent(s)): s=='this'?'':s;
            case EField(e, field): field;
            default: '';
        }];

        var unknowns = [];
        for(funcArg in funcArgs) {
            if(!inArgs.exists(funcArg) && funcArg != '')
                unknowns.push(funcArg);
        }

        for(unknown in unknowns) {
            if(localVars.exists(unknown))
                scoped.local.set(unknown, localVars.get(unknown).t.toComplexType());
            else scoped.outer.push(unknown);
        }

        return scoped;
    }

    #end
}

private class ScopedVariables {

    public var local : Map<String, ComplexType>;
    public var outer : Array<String>;

    public function new() {
        this.local = new Map();
        this.outer = new Array();
    }
}

private class SuperType {

    public var typePath : TypePath;
    public var args : Array<ComplexType>;
    public var ret : Null<ComplexType>;

    public function new() {
        this.args = new Array();
    }
}

enum FunctionType {
    Ident;
    Inline;
}