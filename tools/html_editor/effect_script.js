/* Shared catalog-driven editor validation. No eval or executable Lua. */
(function (global) {
  'use strict';
  const owns = (object,key) => Object.prototype.hasOwnProperty.call(object,key);
  function compile(text, catalog) {
    let at = 0, count = 0;
    const passive = [];
    const fail = message => { throw new Error(`${message} (Zeichen ${at + 1}).`); };
    const skip = () => {
      while (at < text.length) {
        if (/\s/.test(text[at])) at++;
        else if (text[at] === '#' || ['//', '--'].includes(text.slice(at, at + 2))) {
          while (at < text.length && text[at] !== '\n') at++;
        } else break;
      }
    };
    function value(depth) {
      skip();
      if (depth > 24 || ++count > 256) fail('Zu viele oder zu tief verschachtelte Ausdrücke');
      if (at >= text.length) fail('Ausdruck fehlt');
      if (['"', "'"].includes(text[at])) {
        const quote = text[at++]; let result = '';
        while (at < text.length) {
          let ch = text[at++];
          if (ch === quote) return result;
          if (ch === '\\' && at < text.length) {
            ch = text[at++]; ch = ({n:'\n',t:'\t',r:'\r'})[ch] || ch;
          }
          result += ch;
        }
        fail('Zeichenkette nicht geschlossen');
      }
      const n = /^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?/.exec(text.slice(at));
      if (n) {
        at += n[0].length; let result = Number(n[0]);
        if (text[at] === '%') { result /= 100; at++; }
        else if (['m','s'].includes(text[at])) at++;
        return result;
      }
      const id = /^[A-Za-z_][A-Za-z_0-9]*/.exec(text.slice(at));
      if (!id) fail('Funktionsaufruf oder Zahl erwartet; Texte in Anführungszeichen setzen');
      const name = id[0]; at += name.length; skip();
      if (text[at++] !== '(') fail('Funktionsaufruf erwartet');
      skip(); const args = [];
      while (at < text.length && text[at] !== ')') {
        args.push(value(depth + 1)); skip();
        if (text[at] === ',') {
          at++; skip(); if (text[at] === ')') fail('Ausdruck nach Komma fehlt');
        } else if (text[at] !== ')') fail('Komma oder schließende Klammer erwartet');
      }
      if (at >= text.length) fail('Schließende Klammer fehlt');
      at++; return {name,args};
    }
    function validate(node, root) {
      if (!owns(catalog.functions,node.name)) fail('Unbekannte Funktion: ' + node.name);
      const spec = catalog.functions[node.name], args = node.args;
      if (spec.root && !root) fail(node.name + ' ist nur auf oberster Ebene erlaubt');
      const params = spec.params || [], optional = spec.optional || [];
      const offset = spec.chance && typeof args[0] === 'number' ? 1 : 0;
      if (offset && (args[0] < 0 || args[0] > 1 || !Number.isFinite(args[0]))) fail('Chance muss zwischen 0% und 100% liegen');
      if (args.length < params.length + offset + (spec.children ? 1 : 0) || (!spec.children && args.length > params.length + optional.length)) fail('Falsche Argumentzahl für ' + node.name);
      params.concat(optional).forEach((type,i) => {
        if (i + offset >= args.length) return;
        const v = args[i + offset];
        if (typeof v !== type) fail(`${node.name}: Argument ${i + 1} muss ${type} sein`);
        const range = (spec.ranges || [])[i];
		if ((spec.integers || []).includes(i) && !Number.isInteger(v)) fail(`${node.name}: Argument ${i + 1} muss eine ganze Zahl sein`);
        if (range && (!Number.isFinite(v) || v < range[0] || v > range[1])) fail(`${node.name}: Argument ${i + 1} außerhalb des erlaubten Bereichs`);
      });
      if (node.name === 'Ring' && args[0] > args[1]) fail('Ring: Innenradius größer als Außenradius');
      if (node.name === 'Native' || node.name === 'Invoke') {
        let parsed;
        try { parsed = JSON.parse(args[node.name === 'Native' ? 0 : 1]); } catch (_) { fail(node.name + ' erwartet ein JSON-Objekt'); }
        if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) fail(node.name + ' erwartet ein JSON-Objekt');
        if (node.name === 'Native') {
          if (!catalog.native || !owns(catalog.native,parsed.type)) fail('Unbekannte native Fähigkeit: ' + parsed.type);
          Object.entries(catalog.native[parsed.type]).forEach(([key, fallback]) => {
            if (!owns(parsed,key)) parsed[key] = fallback;
          });
          Object.keys(parsed).forEach(key => {
            if (key === 'type') return;
            if (!owns(catalog.native[parsed.type],key) && !((catalog.native_optional || {})[parsed.type] || []).includes(key)) fail('Native: unbekannter Parameter ' + key);
            const fallback = catalog.native[parsed.type][key];
            const expected = typeof fallback === 'string' ? 'string' : (((catalog.native_optional_types || {})[parsed.type] || {})[key] || 'number');
            const number = typeof parsed[key] === 'number';
            if (typeof parsed[key] !== expected || (number && !Number.isFinite(parsed[key]))) fail('Native: ungültiger Parametertyp: ' + key);
            const choices = ((catalog.native_enums || {})[parsed.type] || {})[key] || [];
            if (choices.length && !choices.includes(parsed[key])) fail('Native: unbekannter Parameterwert: ' + key);
            if (key === 'color' && !/^#?(?:[\da-f]{3}|[\da-f]{4}|[\da-f]{6}|[\da-f]{8})$/i.test(parsed[key])) fail('Native: ungültige HTML-Farbe');
            const bounds = (((catalog.native_param_ranges || {})[parsed.type] || {})[key]) || (catalog.native_ranges || {})[key];
            if (number && bounds && (parsed[key] < bounds[0] || parsed[key] > bounds[1])) fail('Native: Parameter außerhalb des erlaubten Bereichs: ' + key);
            if (number && (catalog.native_integers || []).includes(key) && !Number.isInteger(parsed[key])) fail('Native: Parameter muss eine ganze Zahl sein: ' + key);
          });
          passive.push(parsed);
        }
      }
      if (spec.children) args.slice(params.length + offset).forEach(child => {
        if (!child || typeof child !== 'object' || !child.name) fail(node.name + ': Effekt als Argument erwartet');
        validate(child, false);
      });
    }
    try {
      if (typeof text !== 'string') fail('Skript muss Text sein');
      if (text.length > 16384) fail('Skript ist zu lang (max. 16384 Zeichen)');
      const ast = []; skip();
      while (at < text.length) {
        const node = value(0);
        if (!node || typeof node !== 'object') fail('Effektaufruf erwartet');
        ast.push(node); validate(node, true); skip();
        if ([',',';'].includes(text[at])) at++;
        skip();
      }
      return {ok:true,error:'',ast,passive};
    } catch (e) { return {ok:false,error:e.message,ast:[],passive:[]}; }
  }
  global.EffectScript = {compile};
})(typeof window !== 'undefined' ? window : globalThis);
