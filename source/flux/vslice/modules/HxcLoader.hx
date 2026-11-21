package flux.vslice.modules;

#if FLUX_VSLICE_SCRIPTS
import hscript.Expr;
import hscript.Parser.Token;
import rulescript.parsers.HxParser;

using StringTools;

typedef HxcClass =
{
	var name:String;

	/** Nombre corto de la clase padre (ej. "Module", "Song") o null. */
	var superName:String;

	/** Cuerpo de la clase listo para RuleScript (imports + funciones + variables). */
	var expr:Expr;
}

/**
 * Lee un archivo .hxc de V-Slice (formato Polymod) y separa sus clases.
 *
 * Arreglos para que RuleScript entienda el código de V-Slice:
 *  - `final` -> `var` (hscript 2.6 no lo conoce) y `final function` / `dynamic function` -> `function`.
 *  - `a?.b = x`, `a?.b += x`, `a?.b++` y `a?.f()` se reescriben para que no fallen si `a` es null.
 *  - Todas las variables de la clase quedan accesibles con `this.x` y desde otros scripts.
 *  - Si el constructor no llama a `super(...)`, se agrega `super("NombreDeLaClase")`.
 *  - `import funkin.modding.events.*;` importa las clases conocidas de ese paquete.
 */
class HxcLoader
{
	public static function parse(code:String, origin:String):Array<HxcClass>
	{
		var parser:HxcScriptParser = new HxcScriptParser();
		for (key => value in new HxParser().preprocesorValues)
			parser.preprocesorValues.set(key, value);
		#if desktop parser.preprocesorValues.set('desktop', 1); #end
		#if windows parser.preprocesorValues.set('windows', 1); #end
		#if linux parser.preprocesorValues.set('linux', 1); #end
		#if mac parser.preprocesorValues.set('mac', 1); #end
		parser.preprocesorValues.set('FLUX_ENGINE', 1);
		parser.line = 1;
		var decls:Array<ModuleDecl> = parser.parseModule(preprocess(code), origin, 0);
		return buildClasses(decls);
	}

	static function buildClasses(decls:Array<ModuleDecl>):Array<HxcClass>
	{
		var header:Array<Expr> = [];
		var classes:Array<ClassDecl> = [];

		for (decl in decls)
		{
			switch (decl)
			{
				case DPackage(path):
					header.push(make(EPackage(path.join('.'))));
				case DImport(path, star, alias, func):
					if (star)
					{
						// el parser toma "events" de "funkin.modding.events.*" como si fuera una función
						var pack:Array<String> = path.copy();
						if (func != null)
							pack.push(func);
						for (full in VSliceTypes.expandStar(pack.join('.')))
							header.push(make(EImport(full, false, null, null)));
					}
					else
						header.push(make(EImport(path.join('.'), false, alias, func)));
				case DUsing(path):
					header.push(make(EUsing(path)));
				case DClass(c):
					classes.push(c);
				default:
			}
		}

		var result:Array<HxcClass> = [];
		for (c in classes)
			result.push({name: c.name, superName: typeName(c.extend), expr: classExpr(header, c)});
		return result;
	}

	static function typeName(type:CType):String
	{
		if (type == null)
			return null;
		return switch (type)
		{
			case CTPath(path, _): path[path.length - 1];
			default: null;
		}
	}

	static function classExpr(header:Array<Expr>, c:ClassDecl):Expr
	{
		var functions:Array<Expr> = [];
		var variables:Array<Expr> = [];

		for (field in c.fields)
		{
			switch (field.kind)
			{
				case KFunction(f):
					var body:Expr = fix(f.expr);
					if (field.name == 'new')
						body = ensureSuperCall(body, c.name);
					functions.push(make(EFunction(f.args, body, field.name, f.ret)));
				case KVar(v):
					var init:Expr = v.expr != null ? fix(v.expr) : null;
					if (v.get == null && v.set == null)
						variables.push(make(EVar(field.name, v.type, init, true)));
					else
						variables.push(make(EProp(field.name, v.get, v.set, v.type, init, true)));
			}
		}

		// funciones primero: así un valor inicial puede llamar a una función de la clase
		return make(EBlock(header.concat(functions).concat(variables)));
	}

	/** El constructor generado por RuleScript necesita un `super(...)` en el primer nivel. */
	static function ensureSuperCall(body:Expr, className:String):Expr
	{
		var list:Array<Expr> = switch (def(body))
		{
			case EBlock(exprs): exprs.copy();
			default: [body];
		}
		var hasSuper:Bool = false;
		for (e in list)
		{
			switch (def(e))
			{
				case ECall(callee, _):
					switch (def(callee))
					{
						case EIdent('super'):
							hasSuper = true;
						default:
					}
				default:
			}
			if (hasSuper)
				break;
		}
		if (!hasSuper)
			list.insert(0, makeAt(ECall(makeAt(EIdent('super'), body), [makeAt(EConst(CString(className)), body)]), body));
		return makeAt(EBlock(list), body);
	}

	// ----- Reescritura de "?." -----

	static var ASSIGN_OPS:Array<String> = ['=', '+=', '-=', '*=', '/=', '%=', '<<=', '>>=', '>>>=', '|=', '&=', '^=', '??='];

	/** Recorre todo el código y arregla los usos de `?.` en asignaciones y llamadas. */
	public static function fix(e:Expr):Expr
	{
		if (e == null)
			return null;

		var result:ExprDef = switch (def(e))
		{
			case EVar(n, t, v, global): EVar(n, t, fix(v), global);
			case EProp(n, g, s, t, v, global): EProp(n, g, s, t, fix(v), global);
			case EParent(x): EParent(fix(x));
			case EBlock(list): EBlock([for (x in list) fix(x)]);
			case EField(x, f): EField(fix(x), f);
			case EBinop(op, a, b):
				var left:Expr = fix(a);
				var right:Expr = fix(b);
				var safe = safeField(left);
				if (safe != null && ASSIGN_OPS.contains(op))
				{
					// a?.b = x  ->  { var tmp = a; if (tmp != null) tmp.b = x; }
					EBlock([
						makeAt(EVar(safe.tmp, null, safe.target, false), e),
						makeAt(EIf(notNull(safe.tmp, e), makeAt(EBinop(op, makeAt(EField(makeAt(EIdent(safe.tmp), e), safe.field), e), right), e), null), e)
					]);
				}
				else
					EBinop(op, left, right);
			case EUnop(op, prefix, x):
				var inner:Expr = fix(x);
				var safe = safeField(inner);
				if (safe != null && (op == '++' || op == '--'))
					EBlock([
						makeAt(EVar(safe.tmp, null, safe.target, false), e),
						makeAt(EIf(notNull(safe.tmp, e), makeAt(EUnop(op, prefix, makeAt(EField(makeAt(EIdent(safe.tmp), e), safe.field), e)), e), null), e)
					]);
				else
					EUnop(op, prefix, inner);
			case ECall(x, args):
				var callee:Expr = fix(x);
				var params:Array<Expr> = [for (a in args) fix(a)];
				var safe = safeField(callee);
				if (safe != null)
				{
					// a?.f(x)  ->  { var tmp = a; tmp == null ? null : tmp.f(x); }
					EBlock([
						makeAt(EVar(safe.tmp, null, safe.target, false), e),
						makeAt(ETernary(makeAt(EBinop('==', makeAt(EIdent(safe.tmp), e), makeAt(EIdent('null'), e)), e), makeAt(EIdent('null'), e),
							makeAt(ECall(makeAt(EField(makeAt(EIdent(safe.tmp), e), safe.field), e), params), e)),
							e)
					]);
				}
				else
					ECall(callee, params);
			case EIf(c, a, b): EIf(fix(c), fix(a), fix(b));
			case EWhile(c, x): EWhile(fix(c), fix(x));
			case EDoWhile(c, x): EDoWhile(fix(c), fix(x));
			case EFor(k, it, x, v): EFor(k, fix(it), fix(x), v);
			case EFunction(args, x, name, ret): EFunction(args, fix(x), name, ret);
			case EReturn(x): EReturn(fix(x));
			case EArray(a, i): EArray(fix(a), fix(i));
			case EArrayDecl(list): EArrayDecl([for (x in list) fix(x)]);
			case ENew(cl, args): ENew(cl, [for (a in args) fix(a)]);
			case EThrow(x): EThrow(fix(x));
			case ETry(x, v, t, c): ETry(fix(x), v, t, fix(c));
			case EObject(fields): EObject([for (f in fields) {name: f.name, e: fix(f.e)}]);
			case ETernary(c, a, b): ETernary(fix(c), fix(a), fix(b));
			case ESwitch(x, cases, d): ESwitch(fix(x), [for (c in cases) {values: [for (v in c.values) fix(v)], expr: fix(c.expr)}], fix(d));
			case EMeta(name, args, x): EMeta(name, args == null ? null : [for (a in args) fix(a)], fix(x));
			case ECheckType(x, t): ECheckType(fix(x), t);
			default: def(e);
		}
		return makeAt(result, e);
	}

	/**
	 * El parser convierte `a?.b` en `{ var __a_N = a; __a_N == null ? null : __a_N.b; }`.
	 * Si `e` tiene esa forma devuelve sus partes.
	 */
	static function safeField(e:Expr):{tmp:String, target:Expr, field:String}
	{
		switch (def(e))
		{
			case EBlock(list) if (list.length == 2):
				switch (def(list[0]))
				{
					case EVar(tmp, _, target, _) if (tmp != null && tmp.startsWith('__a_')):
						switch (def(list[1]))
						{
							case ETernary(_, _, access):
								switch (def(access))
								{
									case EField(obj, field):
										switch (def(obj))
										{
											case EIdent(id) if (id == tmp):
												return {tmp: tmp, target: target, field: field};
											default:
										}
									default:
								}
							default:
						}
					default:
				}
			default:
		}
		return null;
	}

	static function notNull(tmp:String, at:Expr):Expr
		return makeAt(EBinop('!=', makeAt(EIdent(tmp), at), makeAt(EIdent('null'), at)), at);

	// ----- `final` y `dynamic` -----

	/** Cambia `final` por `var` (fuera de strings y comentarios). */
	public static function preprocess(code:String):String
	{
		var out:StringBuf = new StringBuf();
		var i:Int = 0;
		var n:Int = code.length;
		while (i < n)
		{
			var c:Int = StringTools.fastCodeAt(code, i);

			// comentarios
			if (c == '/'.code && i + 1 < n)
			{
				var next:Int = StringTools.fastCodeAt(code, i + 1);
				if (next == '/'.code)
				{
					var end:Int = code.indexOf('\n', i);
					if (end < 0)
						end = n;
					out.add(code.substring(i, end));
					i = end;
					continue;
				}
				if (next == '*'.code)
				{
					var end:Int = code.indexOf('*/', i + 2);
					end = end < 0 ? n : end + 2;
					out.add(code.substring(i, end));
					i = end;
					continue;
				}
			}

			// strings
			if (c == '"'.code || c == "'".code)
			{
				var j:Int = i + 1;
				while (j < n)
				{
					var d:Int = StringTools.fastCodeAt(code, j);
					if (d == '\\'.code)
					{
						j += 2;
						continue;
					}
					j++;
					if (d == c)
						break;
				}
				if (j > n)
					j = n;
				out.add(code.substring(i, j));
				i = j;
				continue;
			}

			// palabras
			if (isIdentStart(c))
			{
				var j:Int = i + 1;
				while (j < n && isIdentChar(StringTools.fastCodeAt(code, j)))
					j++;
				var word:String = code.substring(i, j);
				if (word == 'typedef' && !afterDot(code, i))
				{
					// los typedef son solo tipos: se sacan (el parser no entiende `?campo:Tipo`)
					var end:Int = typedefEnd(code, j);
					var removed:String = code.substring(i, end);
					for (k in 0...removed.length)
						out.add(removed.charAt(k) == '\n' ? '\n' : ' ');
					i = end;
					continue;
				}
				if ((word == 'final' || word == 'dynamic') && !afterDot(code, i))
				{
					var k:Int = j;
					while (k < n && isSpace(StringTools.fastCodeAt(code, k)))
						k++;
					var e:Int = k;
					while (e < n && isIdentChar(StringTools.fastCodeAt(code, e)))
						e++;
					var nextWord:String = code.substring(k, e);
					if (nextWord == 'function' || nextWord == 'class' || nextWord == 'var')
						word = ''; // "final function" -> "function"
					else if (word == 'final')
						word = 'var'; // "final x = 1" -> "var x = 1"
				}
				out.add(word);
				i = j;
				continue;
			}

			out.addChar(c);
			i++;
		}
		return out.toString();
	}

	/** Dónde termina `typedef X = { ... }` o `typedef X = Tipo;` (después del `;` si hay). */
	static function typedefEnd(code:String, from:Int):Int
	{
		var n:Int = code.length;
		var i:Int = from;
		while (i < n && code.charAt(i) != '=' && code.charAt(i) != '{' && code.charAt(i) != ';')
			i++;
		if (i < n && code.charAt(i) == '=')
			i++;
		while (i < n && isSpace(StringTools.fastCodeAt(code, i)))
			i++;
		if (i < n && code.charAt(i) == '{')
		{
			var depth:Int = 0;
			while (i < n)
			{
				var c:String = code.charAt(i);
				if (c == '{')
					depth++;
				else if (c == '}')
				{
					depth--;
					if (depth == 0)
					{
						i++;
						break;
					}
				}
				i++;
			}
		}
		else
			while (i < n && code.charAt(i) != ';' && code.charAt(i) != '\n')
				i++;
		var k:Int = i;
		while (k < n && (code.charAt(k) == ' ' || code.charAt(k) == '\t'))
			k++;
		if (k < n && code.charAt(k) == ';')
			i = k + 1;
		return i;
	}

	static inline function isIdentStart(c:Int):Bool
		return (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code) || c == '_'.code;

	static inline function isIdentChar(c:Int):Bool
		return isIdentStart(c) || (c >= '0'.code && c <= '9'.code);

	static inline function isSpace(c:Int):Bool
		return c == ' '.code || c == '\t'.code || c == '\n'.code || c == '\r'.code;

	static function afterDot(code:String, pos:Int):Bool
	{
		var k:Int = pos - 1;
		while (k >= 0 && isSpace(StringTools.fastCodeAt(code, k)))
			k--;
		return k >= 0 && StringTools.fastCodeAt(code, k) == '.'.code;
	}

	// ----- utilidades de Expr (con o sin hscriptPos) -----

	static inline function def(e:Expr):ExprDef
		return #if hscriptPos e.e #else e #end;

	static function make(d:ExprDef):Expr
	{
		#if hscriptPos
		return rulescript.Tools.toExpr(d);
		#else
		return d;
		#end
	}

	static function makeAt(d:ExprDef, at:Expr):Expr
	{
		#if hscriptPos
		if (at == null)
			return rulescript.Tools.toExpr(d);
		return {
			e: d,
			pmin: at.pmin,
			pmax: at.pmax,
			origin: at.origin,
			line: at.line
		};
		#else
		return d;
		#end
	}
}
/** El parser de RuleScript con dos detalles más para el código de V-Slice. */
class HxcScriptParser extends HScriptParserPlus
{
	public function new()
	{
		super();
		allowJSON = true;
		allowMetadata = true;
		allowTypes = true;
		allowStringInterpolation = true;
		// `x is T == false` -> `(x is T) == false` (igual en todas las plataformas)
		opPriority.set('is', 0);
	}

	/** `function f() return x;` deja un ";" suelto después de la función. */
	override function parseField():FieldDecl
	{
		var field:FieldDecl = super.parseField();
		maybe(TSemicolon);
		return field;
	}
}
#end
