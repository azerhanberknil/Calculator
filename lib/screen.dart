// lib/screen.dart  –  CalcPro main UI
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'engine.dart';

// ── Color palette ─────────────────────────────────────────────────────────
const _bg         = Color(0xFF08081A);
const _surface    = Color(0xFF111128);
const _numBtn     = Color(0xFF1C1C3E);
const _opBtn      = Color(0xFF2D1B69);
const _fnBtn      = Color(0xFF0D2828);
const _memBtn     = Color(0xFF1A1A2E);
const _clearBtn   = Color(0xFF3D0909);
const _eqStart    = Color(0xFF7C3AED);
const _eqEnd      = Color(0xFF06B6D4);
const _numText    = Colors.white;
const _opText     = Color(0xFFD8B4FE);
const _fnText     = Color(0xFF5EEAD4);
const _memText    = Color(0xFF94A3B8);
const _clearText  = Color(0xFFFCA5A5);

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen>
    with SingleTickerProviderStateMixin {
  // ── State ─────────────────────────────────────────────────────────────────
  final CalcEngine _engine = CalcEngine();
  String _expr    = '';
  String _preview = '';
  bool   _justEval  = false;
  bool   _use2nd    = false;
  bool   _showHist  = false;

  final List<String> _history = [];
  final ScrollController _exprScroll = ScrollController();

  // ── History animation ─────────────────────────────────────────────────────
  late AnimationController _histAnim;
  late Animation<Offset>   _histSlide;

  @override
  void initState() {
    super.initState();
    _histAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _histSlide = Tween<Offset>(
        begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _histAnim, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _histAnim.dispose();
    _exprScroll.dispose();
    super.dispose();
  }

  // ── Input handling ────────────────────────────────────────────────────────

  void _tap(String label) {
    HapticFeedback.lightImpact();
    setState(() {
      switch (label) {

        // ── Clear / Delete ─────────────────────────────────────────────────
        case 'AC':
          _expr = '';
          _preview = '';
          _justEval = false;
          break;
        case 'DEL':
          if (_expr.isNotEmpty) {
            _expr = _expr.substring(0, _expr.length - 1);
            _preview = _engine.preview(_expr);
          }
          _justEval = false;
          break;

        // ── Equals ────────────────────────────────────────────────────────
        case '=':
          if (_expr.isEmpty) break;
          final result = _engine.evaluate(_expr);
          _history.insert(0, '$_expr = $result');
          if (_history.length > 50) _history.removeLast();
          _expr = result == 'Hata' ? _expr : result;
          _preview = '';
          _justEval = true;
          break;

        // ── Toggle angle unit ─────────────────────────────────────────────
        case 'RAD':
        case 'DEG':
          _engine.useRadians = !_engine.useRadians;
          _preview = _engine.preview(_expr);
          break;

        // ── Sign toggle ───────────────────────────────────────────────────
        case '+/-':
          _toggleSign();
          break;

        // ── Memory ────────────────────────────────────────────────────────
        case 'MC':
          _engine.mClear();
          break;
        case 'MR':
          if (_justEval) { _expr = ''; _justEval = false; }
          _expr += _engine.mRecall();
          _preview = _engine.preview(_expr);
          break;
        case 'M+':
          _engine.mAdd(_expr);
          break;
        case 'M-':
          _engine.mSub(_expr);
          break;

        // ── Scientific constants & functions ──────────────────────────────
        case 'π':
          if (_justEval) { _expr = ''; _justEval = false; }
          _expr += 'π';
          _preview = _engine.preview(_expr);
          break;
        case 'e':
          if (_justEval) { _expr = ''; _justEval = false; }
          _expr += 'e';
          _preview = _engine.preview(_expr);
          break;

        // ── Default: append token ─────────────────────────────────────────
        default:
          if (_justEval) {
            // After = pressed: operators continue, digits start fresh
            final isOp = '+-×÷^'.contains(label) || label.length > 1 && label.endsWith('(') == false;
            final justOp = label.length == 1 && '+-×÷^'.contains(label);
            if (!justOp) {
              _expr = '';
            }
            _justEval = false;
          }
          _expr += label;
          _preview = _engine.preview(_expr);
      }
    });
    // Scroll display to end
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_exprScroll.hasClients) {
        _exprScroll.animateTo(_exprScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
      }
    });
  }

  void _toggleSign() {
    if (_expr.isEmpty) return;
    final m = RegExp(r'-?[\d.]+$').firstMatch(_expr);
    if (m != null) {
      final num = m.group(0)!;
      final start = m.start;
      if (num.startsWith('-')) {
        _expr = _expr.substring(0, start) + num.substring(1);
      } else {
        _expr = _expr.substring(0, start) + '-' + num;
      }
    }
    _preview = _engine.preview(_expr);
  }

  void _toggleHist() {
    setState(() => _showHist = !_showHist);
    if (_showHist) {
      _histAnim.forward();
    } else {
      _histAnim.reverse();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final btnH = (size.height * 0.082).clamp(52.0, 72.0);
    final sciBtnH = (size.height * 0.065).clamp(42.0, 58.0);

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── Main layout ────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildDisplay()),
                _buildInfoBar(),
                _buildSciPanel(sciBtnH),
                _buildMemRow(sciBtnH * 0.82),
                _buildStdGrid(btnH),
                SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 4 : 8),
              ],
            ),
          ),
          // ── History overlay ────────────────────────────────────────────
          if (_showHist)
            GestureDetector(
              onTap: _toggleHist,
              child: Container(color: Colors.black54),
            ),
          SlideTransition(
            position: _histSlide,
            child: Align(
              alignment: Alignment.centerRight,
              child: _buildHistPanel(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 0),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
            ).createShader(b),
            child: Text(
              'CalcPro',
              style: GoogleFonts.spaceMono(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          if (_engine.hasMemory)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF4C1D95).withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'M',
                style: GoogleFonts.spaceMono(
                  color: _opText,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Color(0xFF94A3B8)),
            onPressed: _toggleHist,
            tooltip: 'Geçmiş',
          ),
        ],
      ),
    );
  }

  // ── Display panel ─────────────────────────────────────────────────────────

  Widget _buildDisplay() {
    final hasPreview = _preview.isNotEmpty && _preview != _expr;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Expression
          SingleChildScrollView(
            controller: _exprScroll,
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Text(
              _expr.isEmpty ? '0' : _displayExpr(_expr),
              style: GoogleFonts.spaceMono(
                fontSize: _expr.length > 16 ? 28 : 36,
                color: hasPreview
                    ? const Color(0xFF64748B)
                    : Colors.white,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          // Preview / result
          if (hasPreview) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '= ',
                  style: GoogleFonts.spaceMono(
                    fontSize: 18,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
                Text(
                  _preview,
                  style: GoogleFonts.spaceMono(
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
                      ).createShader(const Rect.fromLTWH(0, 0, 200, 40)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _displayExpr(String s) => s
      .replaceAll('*', '×')
      .replaceAll('/', '÷');

  // ── Info bar ──────────────────────────────────────────────────────────────

  Widget _buildInfoBar() {
    final rad = _engine.useRadians;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _modeChip(rad ? 'RAD' : 'DEG', _tap),
          const SizedBox(width: 8),
          _modeChip(_use2nd ? '2nd ●' : '2nd', (l) {
            HapticFeedback.selectionClick();
            setState(() => _use2nd = !_use2nd);
          }, active: _use2nd),
          const Spacer(),
          Text(
            _engine.useRadians ? 'Radyan modu' : 'Derece modu',
            style: const TextStyle(color: Color(0xFF475569), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(String label, Function(String) onTap, {bool active = false}) {
    return GestureDetector(
      onTap: () => onTap(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? const Color(0xFF7C3AED)
                : const Color(0xFF2D2D5E),
            width: 1.5,
          ),
          color: active
              ? const Color(0xFF4C1D95).withOpacity(0.4)
              : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? _opText : const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: GoogleFonts.spaceMono().fontFamily,
          ),
        ),
      ),
    );
  }

  // ── Scientific panel ──────────────────────────────────────────────────────

  Widget _buildSciPanel(double btnH) {
    final s1 = _use2nd
        ? ['sin⁻¹', 'cos⁻¹', 'tan⁻¹', 'sinh', 'cosh']
        : ['sin(', 'cos(', 'tan(', 'sinh(', 'cosh('];
    final s1Labels = _use2nd
        ? ['asin', 'acos', 'atan', 'sinh', 'cosh']
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // Row S1 – trig
          _sciRow(btnH, [
            _SBtn(s1[0], _use2nd ? 'asin(' : 'sin(', _fnBtn, _fnText),
            _SBtn(s1[1], _use2nd ? 'acos(' : 'cos(', _fnBtn, _fnText),
            _SBtn(s1[2], _use2nd ? 'atan(' : 'tan(', _fnBtn, _fnText),
            _SBtn('log(', 'log(', _fnBtn, _fnText),
            _SBtn('ln(', 'ln(', _fnBtn, _fnText),
          ]),
          const SizedBox(height: 6),
          // Row S2 – powers/roots/constants
          _sciRow(btnH, [
            _SBtn('x²', '^2', _fnBtn, _fnText),
            _SBtn('x³', '^3', _fnBtn, _fnText),
            _SBtn('xʸ', '^', _fnBtn, _fnText),
            _SBtn('√(', 'sqrt(', _fnBtn, _fnText),
            _SBtn('∛(', 'cbrt(', _fnBtn, _fnText),
          ]),
          const SizedBox(height: 6),
          // Row S3 – misc
          _sciRow(btnH, [
            _SBtn('π', 'π', _fnBtn, const Color(0xFFFBBF24)),
            _SBtn('e', 'e', _fnBtn, const Color(0xFFFBBF24)),
            _SBtn('n!', '!', _fnBtn, _fnText),
            _SBtn('(', '(', _fnBtn, const Color(0xFF7DD3FC)),
            _SBtn(')', ')', _fnBtn, const Color(0xFF7DD3FC)),
          ]),
        ],
      ),
    );
  }

  Widget _sciRow(double h, List<_SBtn> btns) {
    return SizedBox(
      height: h,
      child: Row(
        children: btns.map((b) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _buildBtn(
              label: b.label,
              payload: b.payload,
              color: b.color,
              textColor: b.textColor,
              fontSize: 13.5,
              fontMono: true,
            ),
          ),
        )).toList(),
      ),
    );
  }

  // ── Memory row ────────────────────────────────────────────────────────────

  Widget _buildMemRow(double h) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: SizedBox(
        height: h,
        child: Row(
          children: ['MC', 'MR', 'M+', 'M-'].map((l) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _buildBtn(
                label: l,
                payload: l,
                color: _memBtn,
                textColor: _memText,
                fontSize: 13,
                fontMono: true,
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }

  // ── Standard button grid ──────────────────────────────────────────────────

  static const _stdLayout = [
    // label, payload, color key ('n'=number, 'o'=op, 'c'=clear, 'e'=equals)
    [['AC','AC','c'], ['DEL','DEL','c'], ['+/-','+/-','n'], ['÷','/','o']],
    [['7','7','n'],   ['8','8','n'],     ['9','9','n'],      ['×','*','o']],
    [['4','4','n'],   ['5','5','n'],     ['6','6','n'],      ['-','-','o']],
    [['1','1','n'],   ['2','2','n'],     ['3','3','n'],      ['+','+','o']],
    [['0','0','nw'],  ['.', '.','n'],    ['=','=','e']],
  ];

  Widget _buildStdGrid(double btnH) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        children: _stdLayout.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              height: btnH,
              child: Row(
                children: row.map((cell) {
                  final label   = cell[0] as String;
                  final payload = cell[1] as String;
                  final type    = cell[2] as String;
                  final isWide  = type == 'nw';

                  Color bgColor;
                  Color fgColor;
                  bool gradient = false;

                  switch (type) {
                    case 'o':
                      bgColor = _opBtn;
                      fgColor = _opText;
                      break;
                    case 'c':
                      bgColor = _clearBtn;
                      fgColor = _clearText;
                      break;
                    case 'e':
                      bgColor = _eqStart;
                      fgColor = Colors.white;
                      gradient = true;
                      break;
                    default:
                      bgColor = _numBtn;
                      fgColor = _numText;
                  }

                  return Expanded(
                    flex: isWide ? 2 : 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: gradient
                          ? _buildGradientBtn(label: label, payload: payload)
                          : _buildBtn(
                              label: label,
                              payload: payload,
                              color: bgColor,
                              textColor: fgColor,
                              fontSize: 22,
                            ),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Button widgets ────────────────────────────────────────────────────────

  Widget _buildBtn({
    required String label,
    required String payload,
    required Color color,
    required Color textColor,
    double fontSize = 20,
    bool fontMono = false,
  }) {
    return _PressBtn(
      onTap: () => _tap(payload),
      color: color,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            fontFamily: fontMono
                ? GoogleFonts.spaceMono().fontFamily
                : GoogleFonts.inter().fontFamily,
          ),
        ),
      ),
    );
  }

  Widget _buildGradientBtn({required String label, required String payload}) {
    return _PressBtn(
      onTap: () => _tap(payload),
      color: _eqStart,
      gradient: const LinearGradient(
        colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ── History panel ─────────────────────────────────────────────────────────

  Widget _buildHistPanel() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.78,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F26),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
                    ).createShader(b),
                    child: Text(
                      'Geçmiş',
                      style: GoogleFonts.spaceMono(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_history.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_rounded,
                          color: Color(0xFF64748B), size: 22),
                      onPressed: () => setState(() {
                        _history.clear();
                        _toggleHist();
                      }),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF64748B), size: 22),
                    onPressed: _toggleHist,
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF1E1E40), height: 1),
            Expanded(
              child: _history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calculate_outlined,
                              color: Color(0xFF2D2D5E), size: 52),
                          const SizedBox(height: 12),
                          Text(
                            'Henüz hesaplama yok',
                            style: TextStyle(
                              color: const Color(0xFF3D3D6E),
                              fontSize: 14,
                              fontFamily: GoogleFonts.inter().fontFamily,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _history.length,
                      itemBuilder: (ctx, i) {
                        final parts = _history[i].split(' = ');
                        final expr  = parts[0];
                        final res   = parts.length > 1 ? parts[1] : '';
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _expr = res;
                              _preview = '';
                              _justEval = false;
                            });
                            _toggleHist();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _displayExpr(expr),
                                  style: TextStyle(
                                    color: const Color(0xFF475569),
                                    fontSize: 13,
                                    fontFamily: GoogleFonts.spaceMono().fontFamily,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  res,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: GoogleFonts.spaceMono().fontFamily,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Press button widget ────────────────────────────────────────────────────

class _PressBtn extends StatefulWidget {
  final VoidCallback onTap;
  final Color color;
  final Gradient? gradient;
  final Widget child;

  const _PressBtn({
    required this.onTap,
    required this.color,
    required this.child,
    this.gradient,
  });

  @override
  State<_PressBtn> createState() => _PressBtnState();
}

class _PressBtnState extends State<_PressBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 70));
    _scale = Tween<double>(begin: 1, end: 0.91)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => _ac.forward(),
      onTapUp:     (_) { _ac.reverse(); widget.onTap(); },
      onTapCancel: ()  => _ac.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: widget.gradient,
            color: widget.gradient == null ? widget.color : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                offset: const Offset(0, 3),
                blurRadius: 8,
              ),
              if (widget.gradient != null)
                BoxShadow(
                  color: const Color(0xFF7C3AED).withOpacity(0.35),
                  offset: const Offset(0, 2),
                  blurRadius: 12,
                ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ── Helper data class ──────────────────────────────────────────────────────

class _SBtn {
  final String label, payload;
  final Color color, textColor;
  const _SBtn(this.label, this.payload, this.color, this.textColor);
}
