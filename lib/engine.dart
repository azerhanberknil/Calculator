// lib/engine.dart
// CalcPro – Full Expression Evaluator (Shunting Yard + RPN)
// Supports: +−×÷^, trig, log/ln, sqrt/cbrt, factorial, memory, % and more.

import 'dart:math' as math;

// ── Token ──────────────────────────────────────────────────────────────────

enum TType { number, operator, function, lParen, rParen }

class Token {
  final TType t;
  final String s;
  final double? n;
  const Token(this.t, this.s, {this.n});
}

// ── Engine ─────────────────────────────────────────────────────────────────

class CalcEngine {
  bool useRadians;
  double _mem = 0;

  CalcEngine({this.useRadians = true});

  // ── Public API ────────────────────────────────────────────────────────────

  String evaluate(String raw) {
    try {
      final clean = raw.trim();
      if (clean.isEmpty) return '0';
      final tokens  = _tokenize(clean);
      final fixed   = _inject(tokens);
      final rpn     = _shunt(fixed);
      final result  = _run(rpn);
      return _fmt(result);
    } catch (e) {
      return 'Hata';
    }
  }

  // Returns live preview (empty string = no preview needed)
  String preview(String raw) {
    try {
      final clean = raw.trim();
      if (clean.isEmpty || clean == '-') return '';
      // Only evaluate if expression looks complete
      if (_endsIncomplete(clean)) return '';
      final r = evaluate(clean);
      if (r == 'Hata') return '';
      return r;
    } catch (_) {
      return '';
    }
  }

  bool _endsIncomplete(String s) {
    if (s.isEmpty) return true;
    final last = s[s.length - 1];
    return '+-×÷*/^('.contains(last);
  }

  // Memory
  void   mAdd(String expr) { try { _mem += _parseResult(evaluate(expr)); } catch (_) {} }
  void   mSub(String expr) { try { _mem -= _parseResult(evaluate(expr)); } catch (_) {} }
  String mRecall()         => _fmt(_mem);
  void   mClear()          => _mem = 0;
  bool   get hasMemory     => _mem != 0;

  double _parseResult(String r) {
    return double.parse(r.replaceAll('∞', 'Infinity'));
  }

  // ── Tokenizer ─────────────────────────────────────────────────────────────

  static const _fns = {
    'sin', 'cos', 'tan', 'asin', 'acos', 'atan',
    'sinh', 'cosh', 'tanh', 'asinh', 'acosh', 'atanh',
    'sqrt', 'cbrt', 'abs', 'log', 'ln', 'log2',
    'floor', 'ceil', 'round', 'exp', 'deg', 'rad',
  };

  List<Token> _tokenize(String expr) {
    final tokens = <Token>[];
    int i = 0;

    // Normalise operator symbols
    expr = expr
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('\u2212', '-') // unicode minus
        .replaceAll('\u00b2', '^2)') // ² → ^2  – handled specially below
        .replaceAll('\u00b3', '^3)');

    while (i < expr.length) {
      final c = expr[i];

      if (c == ' ') { i++; continue; }

      // ── Number ────────────────────────────────────────────────────────────
      if (_isDigit(c) || (c == '.' && i + 1 < expr.length && _isDigit(expr[i + 1]))) {
        final sb = StringBuffer();
        while (i < expr.length && (_isDigit(expr[i]) || expr[i] == '.')) {
          sb.write(expr[i++]);
        }
        tokens.add(Token(TType.number, sb.toString(), n: double.parse(sb.toString())));
        continue;
      }

      // ── π constant ────────────────────────────────────────────────────────
      if (c == 'π') {
        tokens.add(Token(TType.number, 'π', n: math.pi));
        i++; continue;
      }

      // ── Alphabetic: function or constant ──────────────────────────────────
      if (_isAlpha(c)) {
        final sb = StringBuffer();
        while (i < expr.length && (_isAlpha(expr[i]) || _isDigit(expr[i]))) {
          sb.write(expr[i++]);
        }
        final name = sb.toString();
        if (name == 'e' || name == 'E') {
          tokens.add(Token(TType.number, 'e', n: math.e));
        } else if (name == 'pi' || name == 'PI') {
          tokens.add(Token(TType.number, 'π', n: math.pi));
        } else if (name == 'ans') {
          tokens.add(Token(TType.number, 'ans', n: _lastAns));
        } else if (_fns.contains(name)) {
          tokens.add(Token(TType.function, name));
        } else {
          throw Exception('Bilinmeyen: $name');
        }
        continue;
      }

      // ── Operators & parens ────────────────────────────────────────────────
      switch (c) {
        case '+': tokens.add(Token(TType.operator, '+')); break;
        case '-': tokens.add(Token(TType.operator, '-')); break;
        case '*': tokens.add(Token(TType.operator, '*')); break;
        case '/': tokens.add(Token(TType.operator, '/')); break;
        case '^': tokens.add(Token(TType.operator, '^')); break;
        case '%': tokens.add(Token(TType.operator, '%')); break;
        case '!': tokens.add(Token(TType.operator, '!')); break;
        case '(': tokens.add(Token(TType.lParen,   '(')); break;
        case ')': tokens.add(Token(TType.rParen,   ')')); break;
        default:  throw Exception('Geçersiz karakter: $c');
      }
      i++;
    }

    return tokens;
  }

  // ── Post-process: unary minus + implicit multiplication ───────────────────

  double _lastAns = 0;

  List<Token> _inject(List<Token> raw) {
    final out = <Token>[];

    for (int i = 0; i < raw.length; i++) {
      final t = raw[i];

      // Unary minus detection
      if (t.t == TType.operator && t.s == '-') {
        final isUnary = out.isEmpty ||
            out.last.t == TType.operator ||
            out.last.t == TType.function ||
            out.last.t == TType.lParen;
        if (isUnary) {
          out.add(Token(TType.operator, 'u-'));
          continue;
        }
      }

      // Implicit multiplication: value followed by value/function/lParen
      if (out.isNotEmpty) {
        final prev = out.last;
        final prevVal = prev.t == TType.number ||
            prev.t == TType.rParen;
        final curVal = t.t == TType.number ||
            t.t == TType.function ||
            t.t == TType.lParen;
        if (prevVal && curVal) {
          out.add(Token(TType.operator, '*'));
        }
      }

      out.add(t);
    }
    return out;
  }

  // ── Shunting Yard → RPN ───────────────────────────────────────────────────

  int _prec(String op) {
    switch (op) {
      case '+': case '-': return 1;
      case '*': case '/': case '%': return 2;
      case '^': return 3;
      case 'u-': return 4;
      default: return 0;
    }
  }

  bool _rAssoc(String op) => op == '^' || op == 'u-';

  List<Token> _shunt(List<Token> tokens) {
    final out  = <Token>[];
    final ops  = <Token>[];

    for (final t in tokens) {
      switch (t.t) {
        case TType.number:
          out.add(t);
          break;
        case TType.function:
          ops.add(t);
          break;
        case TType.operator:
          // Postfix unary operators go directly to output
          if (t.s == '!' || t.s == '%') {
            out.add(t);
            break;
          }
          while (ops.isNotEmpty &&
              ops.last.t != TType.lParen &&
              (ops.last.t == TType.function ||
                  _prec(ops.last.s) > _prec(t.s) ||
                  (_prec(ops.last.s) == _prec(t.s) && !_rAssoc(t.s)))) {
            out.add(ops.removeLast());
          }
          ops.add(t);
          break;
        case TType.lParen:
          ops.add(t);
          break;
        case TType.rParen:
          while (ops.isNotEmpty && ops.last.t != TType.lParen) {
            out.add(ops.removeLast());
          }
          if (ops.isEmpty) throw Exception('Parantez hatası');
          ops.removeLast();
          if (ops.isNotEmpty && ops.last.t == TType.function) {
            out.add(ops.removeLast());
          }
          break;
      }
    }
    while (ops.isNotEmpty) {
      if (ops.last.t == TType.lParen) throw Exception('Parantez hatası');
      out.add(ops.removeLast());
    }
    return out;
  }

  // ── RPN Evaluator ─────────────────────────────────────────────────────────

  double _run(List<Token> rpn) {
    final stk = <double>[];

    for (final t in rpn) {
      switch (t.t) {
        case TType.number:
          stk.add(t.n!);
          break;
        case TType.function:
          if (stk.isEmpty) throw Exception('Stack boş');
          stk.add(_applyFn(t.s, stk.removeLast()));
          break;
        case TType.operator:
          _applyOp(t.s, stk);
          break;
        default:
          throw Exception('Beklenmeyen token: ${t.s}');
      }
    }

    if (stk.length != 1) throw Exception('Geçersiz ifade');
    _lastAns = stk.first;
    return stk.first;
  }

  void _applyOp(String op, List<double> stk) {
    switch (op) {
      case 'u-':
        if (stk.isEmpty) throw Exception('');
        stk.add(-stk.removeLast());
        break;
      case '!':
        if (stk.isEmpty) throw Exception('');
        stk.add(_fact(stk.removeLast().round()).toDouble());
        break;
      case '%':
        if (stk.isEmpty) throw Exception('');
        stk.add(stk.removeLast() / 100.0);
        break;
      default:
        if (stk.length < 2) throw Exception('');
        final b = stk.removeLast();
        final a = stk.removeLast();
        switch (op) {
          case '+': stk.add(a + b); break;
          case '-': stk.add(a - b); break;
          case '*': stk.add(a * b); break;
          case '/':
            if (b == 0) stk.add(a == 0 ? double.nan : (a > 0 ? double.infinity : double.negativeInfinity));
            else stk.add(a / b);
            break;
          case '^': stk.add(math.pow(a, b).toDouble()); break;
          default: throw Exception('Bilinmeyen op: $op');
        }
    }
  }

  double _applyFn(String fn, double x) {
    // Degree ↔ radian conversion for trig
    final toRad  = useRadians ? x : x * math.pi / 180;
    final fromRad = (double r) => useRadians ? r : r * 180 / math.pi;

    switch (fn) {
      case 'sin':   return _c(math.sin(toRad));
      case 'cos':   return _c(math.cos(toRad));
      case 'tan':
        final v = math.tan(toRad);
        return v.abs() > 1e12 ? double.nan : _c(v);
      case 'asin':
        if (x < -1 || x > 1) throw Exception('Alan dışı');
        return fromRad(math.asin(x));
      case 'acos':
        if (x < -1 || x > 1) throw Exception('Alan dışı');
        return fromRad(math.acos(x));
      case 'atan':  return fromRad(math.atan(x));
      case 'sinh':  return (math.exp(x) - math.exp(-x)) / 2;
      case 'cosh':  return (math.exp(x) + math.exp(-x)) / 2;
      case 'tanh':
        if (x.abs() > 20) return x.sign;
        final e2 = math.exp(2 * x);
        return (e2 - 1) / (e2 + 1);
      case 'asinh': return math.log(x + math.sqrt(x * x + 1));
      case 'acosh':
        if (x < 1) throw Exception('Alan dışı');
        return math.log(x + math.sqrt(x * x - 1));
      case 'atanh':
        if (x <= -1 || x >= 1) throw Exception('Alan dışı');
        return 0.5 * math.log((1 + x) / (1 - x));
      case 'sqrt':
        if (x < 0) throw Exception('Negatif kök');
        return math.sqrt(x);
      case 'cbrt':
        return x >= 0
            ? math.pow(x, 1 / 3.0).toDouble()
            : -math.pow(-x, 1 / 3.0).toDouble();
      case 'abs':   return x.abs();
      case 'log':
        if (x <= 0) return double.nan;
        return math.log(x) / math.ln10;
      case 'ln':
        if (x <= 0) return double.nan;
        return math.log(x);
      case 'log2':
        if (x <= 0) return double.nan;
        return math.log(x) / math.log(2);
      case 'floor': return x.floorToDouble();
      case 'ceil':  return x.ceilToDouble();
      case 'round': return x.roundToDouble();
      case 'exp':   return math.exp(x);
      case 'deg':   return x * 180 / math.pi;
      case 'rad':   return x * math.pi / 180;
      default:      throw Exception('Bilinmeyen fonksiyon: $fn');
    }
  }

  // Clean floating-point noise near zero
  double _c(double v) => v.abs() < 1e-10 ? 0 : v;

  int _fact(int n) {
    if (n < 0)  throw Exception('Negatif faktöriyel');
    if (n > 20) throw Exception('Çok büyük');
    return n <= 1 ? 1 : n * _fact(n - 1);
  }

  bool _isDigit(String c) {
    final code = c.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  bool _isAlpha(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 97 && code <= 122) || (code >= 65 && code <= 90) || c == '_';
  }

  // ── Number formatter ──────────────────────────────────────────────────────

  String _fmt(double v) {
    if (v.isNaN)      return 'Tanımsız';
    if (v.isInfinite) return v > 0 ? '∞' : '-∞';

    // Integer check
    if (v.abs() < 1e15 && v == v.roundToDouble()) {
      return v.toInt().toString();
    }

    // Scientific notation
    if (v.abs() >= 1e10 || (v.abs() < 1e-5 && v != 0)) {
      final s = v.toStringAsExponential(6);
      return s.replaceAll(RegExp(r'\.?0+(e)'), r'\1');
    }

    // Decimal – 10 significant digits, trim trailing zeros
    String s = v.toStringAsPrecision(10);
    if (s.contains('.') && !s.contains('e')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      s = s.replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }
}
