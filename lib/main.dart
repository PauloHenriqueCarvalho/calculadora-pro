import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      systemNavigationBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const CalculadoraShakeApp());
}

class CalculadoraShakeApp extends StatelessWidget {
  const CalculadoraShakeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Calculadora',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const CalculatorPage(),
    );
  }
}

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  static const String _phraseKey = 'hidden_phrase';
  static const double _shakeLimit = 18.0;
  static const int _shakeCooldownMs = 1200;

  StreamSubscription<UserAccelerometerEvent>? _shakeSubscription;

  String _input = '';
  String _display = '0';
  String _hiddenPhrase = 'Magica';
  bool _showingPhrase = false;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _loadPhrase();
    _startShakeListener();
  }

  Future<void> _loadPhrase() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hiddenPhrase = prefs.getString(_phraseKey) ?? 'Magica';
    });
  }

  Future<void> _savePhrase(String phrase) async {
    final prefs = await SharedPreferences.getInstance();

    final value = phrase.trim().isEmpty ? 'Magica' : phrase.trim();

    await prefs.setString(_phraseKey, value);

    setState(() {
      _hiddenPhrase = value;
    });
  }

  void _startShakeListener() {
    _shakeSubscription = userAccelerometerEvents.listen(
      (event) {
        final force = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        final now = DateTime.now();

        if (force >= _shakeLimit &&
            now.difference(_lastShake).inMilliseconds > _shakeCooldownMs) {
          _lastShake = now;
          _activatePhraseMode();
        }
      },
      onError: (_) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sensor de movimento indisponível neste aparelho.'),
          ),
        );
      },
      cancelOnError: false,
    );
  }

  void _activatePhraseMode() {
    if (_input.isEmpty && _display == '0') return;

    HapticFeedback.mediumImpact();

    setState(() {
      _showingPhrase = true;
      _display = _hiddenPhrase;
    });
  }

  void _onButtonPressed(String value) {
    HapticFeedback.selectionClick();

    if (_showingPhrase && value != 'AC' && value != 'C') {
      _showingPhrase = false;
      _input = '';
      _display = '0';
    }

    setState(() {
      switch (value) {
        case 'AC':
        case 'C':
          _clear();
          break;

        case '±':
          _toggleSign();
          break;

        case '%':
          _applyPercent();
          break;

        case '=':
          _calculate();
          break;

        case '+':
        case '-':
        case '×':
        case '÷':
          _addOperator(value);
          break;

        case '.':
          _addDecimalPoint();
          break;

        default:
          _addNumber(value);
      }
    });
  }

  void _clear() {
    _input = '';
    _display = '0';
    _showingPhrase = false;
  }

  void _addNumber(String number) {
    if (_input == '0') {
      _input = number;
    } else {
      _input += number;
    }

    _display = _input;
  }

  void _addDecimalPoint() {
    final lastNumber = _getLastNumberPart();

    if (!lastNumber.contains('.')) {
      if (_input.isEmpty || _endsWithOperator(_input)) {
        _input += '0.';
      } else {
        _input += '.';
      }
    }

    _display = _input;
  }

  void _addOperator(String op) {
    if (_input.isEmpty) {
      if (op == '-') {
        _input = '-';
        _display = _input;
      }
      return;
    }

    if (_endsWithOperator(_input)) {
      _input = _input.substring(0, _input.length - 1) + op;
    } else {
      _input += op;
    }

    _display = _input;
  }

  void _toggleSign() {
    if (_input.isEmpty || _input == '0' || _endsWithOperator(_input)) return;

    final start = _lastNumberStartIndex();

    if (_input.substring(start).startsWith('-')) {
      _input = _input.substring(0, start) + _input.substring(start + 1);
    } else {
      _input = _input.substring(0, start) + '-' + _input.substring(start);
    }

    _display = _input;
  }

  void _applyPercent() {
    if (_input.isEmpty || _endsWithOperator(_input)) return;

    try {
      final result = _evaluateExpression(_normalizeExpression(_input)) / 100;
      final formatted = _formatResult(result);

      if (formatted == 'Erro') throw Exception();

      _input = formatted;
      _display = _input;
    } catch (_) {
      _display = 'Erro';
      _input = '';
    }
  }

  void _calculate() {
    if (_input.isEmpty || _endsWithOperator(_input)) return;

    try {
      final result = _evaluateExpression(_normalizeExpression(_input));
      final formatted = _formatResult(result);

      if (formatted == 'Erro') throw Exception();

      _input = formatted;
      _display = _input;
    } catch (_) {
      _display = 'Erro';
      _input = '';
    }
  }

  String _normalizeExpression(String expression) {
    return expression.replaceAll('×', '*').replaceAll('÷', '/');
  }

  bool _endsWithOperator(String text) {
    if (text.isEmpty) return false;

    return ['+', '-', '×', '÷', '*', '/'].contains(text[text.length - 1]);
  }

  int _lastNumberStartIndex() {
    for (int i = _input.length - 1; i >= 0; i--) {
      final char = _input[i];

      if (['+', '×', '÷', '*', '/'].contains(char)) {
        return i + 1;
      }

      if (char == '-' && i > 0) {
        final previous = _input[i - 1];

        if (!['+', '-', '×', '÷', '*', '/'].contains(previous)) {
          return i + 1;
        }
      }
    }

    return 0;
  }

  String _getLastNumberPart() {
    final start = _lastNumberStartIndex();
    return _input.substring(start);
  }

  String _formatResult(double value) {
    if (value.isInfinite || value.isNaN) return 'Erro';

    if (value % 1 == 0) {
      return value.toInt().toString();
    }

    return value
        .toStringAsFixed(8)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  double _evaluateExpression(String expression) {
    final tokens = _tokenize(expression);

    if (tokens.isEmpty) throw Exception('Expressão vazia');

    final firstPass = <String>[];
    int index = 0;

    while (index < tokens.length) {
      final token = tokens[index];

      if ((token == '*' || token == '/') && firstPass.isNotEmpty && index + 1 < tokens.length) {
        final left = double.parse(firstPass.removeLast());
        final right = double.parse(tokens[index + 1]);

        final result = token == '*' ? left * right : left / right;

        firstPass.add(result.toString());
        index += 2;
      } else {
        firstPass.add(token);
        index++;
      }
    }

    double result = double.parse(firstPass[0]);
    index = 1;

    while (index < firstPass.length) {
      final op = firstPass[index];
      final number = double.parse(firstPass[index + 1]);

      if (op == '+') result += number;
      if (op == '-') result -= number;

      index += 2;
    }

    return result;
  }

  List<String> _tokenize(String expression) {
    final tokens = <String>[];
    String number = '';

    for (int i = 0; i < expression.length; i++) {
      final char = expression[i];
      final isOperator = ['+', '-', '*', '/'].contains(char);
      final isNegativeNumber =
          char == '-' && (i == 0 || ['+', '-', '*', '/'].contains(expression[i - 1]));

      if (!isOperator || isNegativeNumber) {
        number += char;
      } else {
        if (number.isEmpty) throw Exception('Expressão inválida');

        tokens.add(number);
        tokens.add(char);
        number = '';
      }
    }

    if (number.isNotEmpty) {
      tokens.add(number);
    }

    return tokens;
  }

  void _openConfig() {
    final controller = TextEditingController(text: _hiddenPhrase);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 22,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Frase secreta',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Essa frase aparece quando você chacoalhar o celular.',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFFBDBDBD),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF2C2C2E),
                  labelText: 'Ex: Magica',
                  labelStyle: const TextStyle(color: Color(0xFFBDBDBD)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9F0A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () async {
                    await _savePhrase(controller.text);

                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text(
                    'Salvar frase',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _shakeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clearLabel = _input.isEmpty && !_showingPhrase ? 'AC' : 'C';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        onPressed: _openConfig,
                        icon: const Icon(Icons.settings),
                        color: Colors.white.withOpacity(0.45),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10, bottom: 12),
                        child: SingleChildScrollView(
                          reverse: true,
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            _display,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: _showingPhrase ? 42 : 76,
                              fontWeight: FontWeight.w300,
                              letterSpacing: _showingPhrase ? -1 : -3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _ButtonRow(
                children: [
                  _CalcButton(text: clearLabel, type: ButtonType.top, onTap: () => _onButtonPressed(clearLabel)),
                  _CalcButton(text: '±', type: ButtonType.top, onTap: () => _onButtonPressed('±')),
                  _CalcButton(text: '%', type: ButtonType.top, onTap: () => _onButtonPressed('%')),
                  _CalcButton(text: '÷', type: ButtonType.operator, onTap: () => _onButtonPressed('÷')),
                ],
              ),
              _ButtonRow(
                children: [
                  _CalcButton(text: '7', onTap: () => _onButtonPressed('7')),
                  _CalcButton(text: '8', onTap: () => _onButtonPressed('8')),
                  _CalcButton(text: '9', onTap: () => _onButtonPressed('9')),
                  _CalcButton(text: '×', type: ButtonType.operator, onTap: () => _onButtonPressed('×')),
                ],
              ),
              _ButtonRow(
                children: [
                  _CalcButton(text: '4', onTap: () => _onButtonPressed('4')),
                  _CalcButton(text: '5', onTap: () => _onButtonPressed('5')),
                  _CalcButton(text: '6', onTap: () => _onButtonPressed('6')),
                  _CalcButton(text: '-', type: ButtonType.operator, onTap: () => _onButtonPressed('-')),
                ],
              ),
              _ButtonRow(
                children: [
                  _CalcButton(text: '1', onTap: () => _onButtonPressed('1')),
                  _CalcButton(text: '2', onTap: () => _onButtonPressed('2')),
                  _CalcButton(text: '3', onTap: () => _onButtonPressed('3')),
                  _CalcButton(text: '+', type: ButtonType.operator, onTap: () => _onButtonPressed('+')),
                ],
              ),
              _ButtonRow(
                children: [
                  _CalcButton(text: '0', isWide: true, onTap: () => _onButtonPressed('0')),
                  _CalcButton(text: '.', onTap: () => _onButtonPressed('.')),
                  _CalcButton(text: '=', type: ButtonType.operator, onTap: () => _onButtonPressed('=')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum ButtonType {
  number,
  top,
  operator,
}

class _ButtonRow extends StatelessWidget {
  const _ButtonRow({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _CalcButton extends StatelessWidget {
  const _CalcButton({
    required this.text,
    required this.onTap,
    this.type = ButtonType.number,
    this.isWide = false,
  });

  final String text;
  final VoidCallback onTap;
  final ButtonType type;
  final bool isWide;

  Color get _background {
    switch (type) {
      case ButtonType.top:
        return const Color(0xFFA5A5A5);
      case ButtonType.operator:
        return const Color(0xFFFF9F0A);
      case ButtonType.number:
        return const Color(0xFF333333);
    }
  }

  Color get _foreground {
    switch (type) {
      case ButtonType.top:
        return Colors.black;
      case ButtonType.operator:
      case ButtonType.number:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: isWide ? 2 : 1,
      child: AspectRatio(
        aspectRatio: isWide ? 2.15 : 1,
        child: Material(
          color: _background,
          borderRadius: BorderRadius.circular(100),
          child: InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: onTap,
            child: Align(
              alignment: isWide ? Alignment.centerLeft : Alignment.center,
              child: Padding(
                padding: EdgeInsets.only(left: isWide ? 32 : 0),
                child: Text(
                  text,
                  style: TextStyle(
                    color: _foreground,
                    fontSize: 34,
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}