package hx.delegates;

import sys.net.UdpSocket;
#if macro
import haxe.macro.Expr.ComplexType;
import haxe.macro.Expr.TypePath;
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
                fields.push(createInlineCall(type, func, scope));
            case Ident:
                fields.push(createIdentCall(ident, type, func));
        }

        var typePath = createType(type, ident, fields);

        return createInstantiation(typePath, newVars);
    }

    private static function createType(superPath : SuperType, name : String, fields : Array<Field>) : TypePath {
        var module = Context.getLocalModule();
        var packageName = 'delegates';
        var className = 'Delegate_${name}';
        var typePath = module.toLowerCase().split('.');
        typePath.insert(0, packageName);
        try {
            Context.getType('${packageName}.${module.toLowerCase()}.${className}');
        } catch (e : Dynamic) {
            Context.defineType({
                pos: Context.currentPos(),
                pack: typePath,
                name: className,
                kind: TDClass(superPath.typePath, null, false, true, false),
                fields: fields,
                meta: [{name:':access', params: [convertToEField(module)], pos: Context.currentPos()}]
            });
        }
        return {pack: typePath, name: className};
    }

    private static function convertToEField(path : String) : Expr {
        var patharray = path.split('.');
        var current = {pos: Context.currentPos(), expr: EConst(CIdent(patharray[0]))};
        for(i in 1...patharray.length) {
            current = {pos: Context.currentPos(), expr: EField(current, patharray[i])};
        }
        return current;
    }

    private static function resolveSuperType(func : Function) : SuperType {
        var superType = new SuperType();

        var name = '';
        for(arg in func.args) {
            name += '${getTypeNames(arg.type)}_';
            superType.args.push(arg.type);
        }

        if(func.ret == null) {
            var type = findReturnType(func.expr);
            name += getTypeNames(type);
            superType.ret = type;
        } else {
            name += getTypeNames(func.ret);
            superType.ret = func.ret;
        }

        superType.typePath = {pack: ['delegates'], name: 'Delegate_${name}'};


        return superType;
    }

    // TODO: Fix this up, we are not finding the correct super type...
    private static function getTypeNames(type : ComplexType) : String {
        var result = '';
        switch(type) {
            case TPath(p):
                var ps = p.params==null?[]:p.params;
                if(ps.length > 0) {
                    result += '${resolveName(type)}_';
                    for(param in p.params) {
                        switch(param) {
                           case TPType(t):
                                result += '${resolveName(t)}';
                            default:
                        }
                    }
                } else result = resolveName(type);
            default:
        }
        return result;
    }

    private static function resolveName(type : ComplexType) : String {
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
        if(out.exprs.length <= 0) {
            return ComplexType.TPath({pack: [], name: 'Void'});
        }

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
        exprs.push(macro $i{'_parent'} = $i{'parent'});

        for(entry in scope.local.keyValueIterator()) {
            var name = entry.key;
            var type = entry.value;
            args.push({name: name, type: type});

            exprs.push(macro $i{'_$name'} = $i{name});

            outVars.push(name);
        }

        fields.push({
            name: 'new',
                access: [APublic],
                kind: FFun({
                    args: args,
                    expr: macro $b{exprs}
                }),
            pos: Context.currentPos()
        });

        return outVars;
    }

    private static function createIdentCall(ident : String, superType : SuperType, func : Function) : Field {
        var args = [for(arg in func.args) macro $i{arg.name}];
        if(func.ret != null) {
            return createCall(superType, func.args, macro return _parent.$ident($a{args}));
        } else return createCall(superType, func.args, macro _parent.$ident($a{args}));
    }

    private static function createInlineCall(superType : SuperType, func : Function, scoped : ScopedVariables) : Field {
        function mapper(expr : Expr) {
            switch expr.expr {
                case EConst(CIdent(s)):
                    if(s == 'trace')
                        return expr.map(mapper);

                    if(scoped.local.exists(s)) {
                        return macro $i{'_$s'};
                    }

                    if(scoped.outer.exists(s)) {
                        return macro _parent.$s;
                    }
                default:
                    return expr.map(mapper);
            }
            return expr;
        };
        
        return createCall(superType, func.args, func.expr.map(mapper));
    }

    private static function createCall(superType : SuperType, args : Array<FunctionArg>, innerExpr : Expr) : Field {
        return {
            name: 'call',
            access: [APublic],
            kind: FFun({
                args: args,
                expr: innerExpr,
                ret: superType.ret
            }),
            pos: Context.currentPos()
        };
    }

    private static function createInstantiation(typePath : TypePath, inVars : Array<String>) : Expr {
        var exprs = [for(name in inVars) macro $i{name}];
        exprs.insert(0, macro this);
        return macro new $typePath($a{exprs});
    }

    private static function handleVaribleScope(func : Function) : ScopedVariables {
        var scoped = new ScopedVariables();

        var localVars = Context.getLocalTVars();
        var outerVars = Context.getLocalClass().get().fields.get();
        [for(outer in outerVars) scoped.outer.set(outer.name, outer.name)];
        [for(v in localVars) scoped.local.set(v.name, v.t.toComplexType())];

        return scoped;
    }

    #end
}

#if macro
private class ScopedVariables {

    public var local : Map<String, ComplexType>;
    public var outer : Map<String, String>;

    public function new() {
        this.local = new Map();
        this.outer = new Map();
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
#end
