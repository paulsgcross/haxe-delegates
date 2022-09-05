package hx.delegates.macros;

#if macro

import haxe.macro.Context;
import haxe.macro.Expr.Field;
import haxe.macro.Expr.ComplexType;

using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;

using StringTools;

final class DelegateMacro {

    private static var _delegateCount : Int = 0;

    public static function build() {
        var type : haxe.macro.Type = null;

        var types = getFunctionTypes();
        var names = toNames(types);
        
        try {
            type = Context.getType('delegates.Delegate_' + names.join('_'));
        } catch(e : Dynamic) {
            type = createType(types, names);
        }

        return type;
    }

    private static function toNames(types : Array<haxe.macro.Type>) : Array<String> {
        var names = [];
        for(type in types) {
            switch(type) {
                case TAbstract(t, params):
                    names.push(t.toString().replace('.', ''));
                    //for(param in params)
                     //   names.push(param.toString().replace('.', ''));
                case TInst(t, params):
                    names.push(t.get().name.replace('.', ''));
                    //for(param in params)
                    //    names.push(param.toString().replace('.', ''));
                case TEnum(t, params):
                    names.push(t.get().name.replace('.', ''));
                    //for(param in params)
                    //    names.push(param.toString().replace('.', ''));
                default:
            }
        }
        return names;
    }

    private static function getFunctionTypes() : Array<haxe.macro.Type> {
        var types = [];
        var type = Context.getLocalType();
        switch(type) {
            case TInst(t, params):
                for(param in params) {
                    switch(param) {
                        case TFun(args, ret):
                            for(arg in args) {
                                types.push(arg.t);
                            }
                            types.push(ret);
                        default:
                    }
                }
            default:
        }
        return types;
    }

    private static function createType(types : Array<haxe.macro.Type>, names : Array<String>) : haxe.macro.Type {
        var module = Context.getLocalModule();
        var pos = Context.currentPos();
        var type = Context.getLocalType();
        
        var fields : Array<Field> = [];

        var ptype = Context.getType(module);
        fields.push({
              name: '_parent',
              access: [APrivate],
              kind: FVar(ptype.toComplexType(), null),
              pos: pos
        });

        fields.push({
            name: 'new',
            access: [APublic],
            kind: FFun({
                args: [{name: 'parent', type: ptype.toComplexType()}],
                expr: macro {
                    _parent = parent;
                },
                ret: null
            }),
            pos: pos
        });
        
        fields.push({
            name: 'call',
            access: [APublic, AAbstract],
            kind: FFun({
                args: [for (i in 0...types.length-1) {name: 'arg${i}', type: types[i].toComplexType()}],
                expr: null,
                ret: types[types.length-1].toComplexType()
            }),
            pos: pos
        });

        var pack = ['delegates'];
        var name = 'Delegate_' + names.join('_');
        
        Context.defineType({
            pos: pos,
            pack: pack,
            name: name,
            kind: TDClass(null, null, false, false, true),
            fields: fields
        });

        return TPath({pack: pack, name: name}).toType();
    }
}

#end