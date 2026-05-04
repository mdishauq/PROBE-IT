import 'package:cpu_analyser_example/splash_screen.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:cpu_analyser/cpu_analyser.dart';

void main() {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CPU Analyser',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF4F6FB),
      ),
      home: const SplashScreen(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  DATA MODEL + ALL CALCULATIONS
// ══════════════════════════════════════════════════════════════════════════════

class SensorSnapshot {
  final double cpuLoad;
  final double ramUsage;
  final double pageFileStress;
  final double virtualMemoryPressure;
  final double memoryToSwapRatio;
  final double ramValue;
  final int ramUnit;
  final DateTime timestamp;

  SensorSnapshot({
    required this.cpuLoad,
    required this.ramUsage,
    required this.pageFileStress,
    required this.virtualMemoryPressure,
    required this.memoryToSwapRatio,
    required this.ramValue,
    required this.ramUnit,
    required this.timestamp,
  });

  factory SensorSnapshot.fromMap(Map<String, dynamic> data) {
    final ramDetails = (data['ram_details'] as Map?)?.cast<String, dynamic>() ?? {};
    return SensorSnapshot(
      cpuLoad: (data['cpu_load_percent'] as num? ?? 0).toDouble(),
      ramUsage: (data['ram_usage_percent'] as num? ?? 0).toDouble(),
      pageFileStress: (data['page_file_stress_percent'] as num? ?? 0).toDouble(),
      virtualMemoryPressure:
          (data['virtual_memory_pressure_percent'] as num? ?? 0).toDouble(),
      memoryToSwapRatio:
          (data['memory_to_swap_ratio'] as num? ?? 0).toDouble(),
      ramValue: (ramDetails['value'] as num? ?? 0).toDouble(),
      ramUnit: (ramDetails['unit'] as int? ?? 2),
      timestamp: DateTime.now(),
    );
  }

  // ── Derived metrics (all calculated here, never in the UI) ─────────────────

  /// Weighted health score: 0 (dead) → 100 (perfect)
  double get healthScore =>
      (100 - (cpuLoad * 0.4 + ramUsage * 0.4 + pageFileStress * 0.2))
          .clamp(0, 100);

  /// Average of RAM + page-file stress
  double get memoryStressIndex =>
      ((ramUsage + pageFileStress) / 2).clamp(0, 100);

  /// Swap is danger when more swapping than real RAM usage
  bool get isSwapDanger => memoryToSwapRatio > 0.8;

  /// Pressure flag for virtual memory
  bool get isVirtualCritical => virtualMemoryPressure > 80;

  /// Page file warning threshold
  bool get isPageFileHigh => pageFileStress > 60;

  /// CPU status band
  String get cpuStatus {
    if (cpuLoad < 30) return 'LOW';
    if (cpuLoad < 60) return 'MODERATE';
    if (cpuLoad < 85) return 'HIGH';
    return 'CRITICAL';
  }

  Color get cpuStatusColor {
    if (cpuLoad < 30) return const Color(0xFF00A86B);
    if (cpuLoad < 60) return const Color(0xFFE6AC00);
    if (cpuLoad < 85) return const Color(0xFFE85D20);
    return const Color(0xFFD91A3C);
  }

  String get ramUnitLabel =>
      ['B', 'KB', 'MB', 'GB', 'TB'][ramUnit.clamp(0, 4)];

  String get healthLabel {
    if (healthScore >= 80) return 'EXCELLENT';
    if (healthScore >= 60) return 'GOOD';
    if (healthScore >= 40) return 'FAIR';
    return 'CRITICAL';
  }

  Color get healthColor {
    if (healthScore >= 80) return const Color(0xFF00A86B);
    if (healthScore >= 60) return const Color(0xFFE6AC00);
    if (healthScore >= 40) return const Color(0xFFE85D20);
    return const Color(0xFFD91A3C);
  }

  /// Penalty points breakdown (for transparency card)
  double get cpuPenalty => cpuLoad * 0.4;
  double get ramPenalty => ramUsage * 0.4;
  double get swapPenalty => pageFileStress * 0.2;
}

// ══════════════════════════════════════════════════════════════════════════════
//  ROLLING HISTORY BUFFER
// ══════════════════════════════════════════════════════════════════════════════

class MetricHistory {
  final int maxLength;
  final List<double> _values = [];

  MetricHistory({this.maxLength = 60});

  void add(double value) {
    _values.add(value);
    if (_values.length > maxLength) _values.removeAt(0);
  }

  List<double> get values => List.unmodifiable(_values);
  double get latest => _values.isEmpty ? 0 : _values.last;
  double get average => _values.isEmpty
      ? 0
      : _values.fold(0.0, (a, b) => a + b) / _values.length;
  double get peak => _values.isEmpty ? 0 : _values.reduce(math.max);
  bool get hasData => _values.length >= 2;
}

// ══════════════════════════════════════════════════════════════════════════════
//  MONITOR SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen>
    with TickerProviderStateMixin {
  final _plugin = CpuAnalyser();
  bool _isPolling = false;
  SensorSnapshot? _latest;

  // ── History buffers ─────────────────────────────────────────────────────────
  final _cpuHistory = MetricHistory();
  final _ramHistory = MetricHistory();
  final _pageHistory = MetricHistory();

  // ── Animation controllers ───────────────────────────────────────────────────
  late AnimationController _cpuGaugeCtrl;
  late AnimationController _ramGaugeCtrl;
  late AnimationController _healthCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _entryCtrl;

  late Animation<double> _cpuAnim;
  late Animation<double> _ramAnim;
  late Animation<double> _healthAnim;

  double _prevCpu = 0, _prevRam = 0, _prevHealth = 100;
  bool _firstData = true;

  @override
  void initState() {
    super.initState();

    _cpuGaugeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _ramGaugeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _healthCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));

    _cpuAnim = Tween<double>(begin: 0, end: 0)
        .animate(CurvedAnimation(parent: _cpuGaugeCtrl, curve: Curves.easeOut));
    _ramAnim = Tween<double>(begin: 0, end: 0)
        .animate(CurvedAnimation(parent: _ramGaugeCtrl, curve: Curves.easeOut));
    _healthAnim = Tween<double>(begin: 100, end: 100)
        .animate(CurvedAnimation(parent: _healthCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    if (_isPolling) _plugin.stopSensorPolling();
    _cpuGaugeCtrl.dispose();
    _ramGaugeCtrl.dispose();
    _healthCtrl.dispose();
    _pulseCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  void _onNewData(SensorSnapshot snap) {
    // Smooth-animate gauges to new values
    _cpuAnim = Tween<double>(begin: _prevCpu, end: snap.cpuLoad / 100).animate(
        CurvedAnimation(parent: _cpuGaugeCtrl, curve: Curves.easeOut));
    _ramAnim = Tween<double>(begin: _prevRam, end: snap.ramUsage / 100).animate(
        CurvedAnimation(parent: _ramGaugeCtrl, curve: Curves.easeOut));
    _healthAnim = Tween<double>(begin: _prevHealth, end: snap.healthScore)
        .animate(CurvedAnimation(parent: _healthCtrl, curve: Curves.easeOut));

    _cpuGaugeCtrl.forward(from: 0);
    _ramGaugeCtrl.forward(from: 0);
    _healthCtrl.forward(from: 0);

    _prevCpu = snap.cpuLoad / 100;
    _prevRam = snap.ramUsage / 100;
    _prevHealth = snap.healthScore;

    _cpuHistory.add(snap.cpuLoad);
    _ramHistory.add(snap.ramUsage);
    _pageHistory.add(snap.pageFileStress);

    if (_firstData) {
      _firstData = false;
      _entryCtrl.forward(from: 0);
    }

    setState(() => _latest = snap);
  }

  void _togglePolling() async {
    setState(() {
      _isPolling = !_isPolling;
      if (!_isPolling) {
        _firstData = true;
        _entryCtrl.reset();
      }
    });
    if (_isPolling) {
      await _plugin.startSensorPolling();
    } else {
      await _plugin.stopSensorPolling();
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Stack(
        children: [
          const _GridBackground(),
          SafeArea(
            child: StreamBuilder<Map<String, dynamic>>(
              stream: _isPolling ? _plugin.sensorDataStream : const Stream.empty(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _onNewData(SensorSnapshot.fromMap(snapshot.data!)));
                }
                return Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: _isPolling
                          ? _buildDashboard()
                          : _buildIdle(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF0099CC).withOpacity(0.5), width: 1),
                  color: const Color(0xFF0099CC).withOpacity(0.1),
                ),
                child: const Icon(Icons.memory_rounded,
                    color: Color(0xFF0099CC), size: 16),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CPU ANALYSER',
                      style: TextStyle(
                        color: const Color(0xFF0099CC),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                      )),
                  Text('Real-time System Monitor',
                      style: TextStyle(
                          color: const Color(0xFF111827).withOpacity(0.4),
                          fontSize: 10)),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: _togglePolling,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: _isPolling
                    ? const Color(0xFFD91A3C).withOpacity(0.10)
                    : const Color(0xFF0099CC).withOpacity(0.10),
                border: Border.all(
                  color: _isPolling
                      ? const Color(0xFFD91A3C)
                      : const Color(0xFF0099CC),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _isPolling
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      key: ValueKey(_isPolling),
                      color: _isPolling
                          ? const Color(0xFFD91A3C)
                          : const Color(0xFF0099CC),
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _isPolling ? 'STOP' : 'START',
                      key: ValueKey(_isPolling),
                      style: TextStyle(
                        color: _isPolling
                            ? const Color(0xFFD91A3C)
                            : const Color(0xFF0099CC),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Idle state ──────────────────────────────────────────────────────────────
  Widget _buildIdle() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) {
              final pulse =
                  math.sin(_pulseCtrl.value * math.pi * 2).abs();
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 130 + 24 * pulse,
                    height: 130 + 24 * pulse,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0099CC).withOpacity(0.06 * pulse),
                    ),
                  ),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0099CC).withOpacity(0.08),
                      border: Border.all(
                          color: const Color(0xFF0099CC).withOpacity(0.3 + 0.2 * pulse),
                          width: 1),
                    ),
                    child: const Icon(Icons.monitor_heart_rounded,
                        color: Color(0xFF0099CC), size: 40),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          Text('SYSTEM READY',
              style: TextStyle(
                color: const Color(0xFF111827).withOpacity(0.7),
                fontSize: 13,
                letterSpacing: 4,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 8),
          Text('Tap START to begin real-time analysis',
              style: TextStyle(
                  color: const Color(0xFF111827).withOpacity(0.35), fontSize: 12)),
        ],
      ),
    );
  }

  // ── Dashboard ───────────────────────────────────────────────────────────────
  Widget _buildDashboard() {
    return FadeTransition(
      opacity: _entryCtrl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        child: Column(
          children: [
            // Health hero
            _HealthCard(
                healthAnim: _healthAnim,
                pulseAnim: _pulseCtrl,
                latest: _latest),
            const SizedBox(height: 14),
            // Dual gauges
            Row(
              children: [
                Expanded(
                  child: _GaugeCard(
                    label: 'CPU LOAD',
                    icon: Icons.developer_board_rounded,
                    color: const Color(0xFF0099CC),
                    anim: _cpuAnim,
                    history: _cpuHistory,
                    status: _latest?.cpuStatus,
                    statusColor: _latest?.cpuStatusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GaugeCard(
                    label: 'RAM USAGE',
                    icon: Icons.storage_rounded,
                    color: const Color(0xFF00A86B),
                    anim: _ramAnim,
                    history: _ramHistory,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Sparklines
            _SparklineCard(
              label: 'CPU LOAD',
              sublabel: '60-SECOND HISTORY',
              history: _cpuHistory,
              color: const Color(0xFF0099CC),
            ),
            const SizedBox(height: 10),
            _SparklineCard(
              label: 'RAM USAGE',
              sublabel: '60-SECOND HISTORY',
              history: _ramHistory,
              color: const Color(0xFF00A86B),
            ),
            const SizedBox(height: 14),
            // Stat grid
            if (_latest != null) _buildStatGrid(_latest!),
          ],
        ),
      ),
    );
  }

  Widget _buildStatGrid(SensorSnapshot s) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'PAGE FILE',
                value: '${s.pageFileStress.toStringAsFixed(1)}%',
                sub: s.isPageFileHigh ? '⚠  High Stress' : 'Normal',
                color: s.isPageFileHigh
                    ? const Color(0xFFE85D20)
                    : const Color(0xFF00A86B),
                icon: Icons.swap_horiz_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: 'VIRT. MEMORY',
                value: '${s.virtualMemoryPressure.toStringAsFixed(1)}%',
                sub: s.isVirtualCritical ? '⚠  Critical' : 'Stable',
                color: s.isVirtualCritical
                    ? const Color(0xFFD91A3C)
                    : const Color(0xFF00A86B),
                icon: Icons.layers_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'SWAP RATIO',
                value: s.memoryToSwapRatio.toStringAsFixed(3),
                sub: s.isSwapDanger ? '⚠  Danger Zone' : 'Safe',
                color: s.isSwapDanger
                    ? const Color(0xFFD91A3C)
                    : const Color(0xFF00A86B),
                icon: Icons.sync_alt_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: 'MEM STRESS',
                value: '${s.memoryStressIndex.toStringAsFixed(1)}%',
                sub: s.memoryStressIndex > 70 ? '⚠  Elevated' : 'Low',
                color: s.memoryStressIndex > 70
                    ? const Color(0xFFE6AC00)
                    : const Color(0xFF00A86B),
                icon: Icons.compress_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _RamDetailCard(snap: s),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  HEALTH SCORE CARD
// ══════════════════════════════════════════════════════════════════════════════

class _HealthCard extends StatelessWidget {
  final Animation<double> healthAnim;
  final Animation<double> pulseAnim;
  final SensorSnapshot? latest;

  const _HealthCard(
      {required this.healthAnim,
      required this.pulseAnim,
      required this.latest});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, const Color(0xFFF0F4FF)],
        ),
        border: Border.all(color: Colors.black.withOpacity(0.07), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Arc gauge
          AnimatedBuilder(
            animation: healthAnim,
            builder: (_, __) {
              final score = healthAnim.value.clamp(0.0, 100.0);
              final color = latest?.healthColor ?? const Color(0xFF00F5A0);
              return SizedBox(
                width: 110,
                height: 110,
                child: CustomPaint(
                  painter: _ArcGaugePainter(
                    value: score / 100,
                    color: color,
                    trackColor: Colors.white.withOpacity(0.06),
                    strokeWidth: 9,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          score.toStringAsFixed(0),
                          style: TextStyle(
                            color: color,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        Text('/ 100',
                            style: TextStyle(
                              color: color.withOpacity(0.5),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SYSTEM HEALTH',
                    style: TextStyle(
                      color: const Color(0xFF111827).withOpacity(0.35),
                      fontSize: 9,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 4),
                AnimatedBuilder(
                  animation: healthAnim,
                  builder: (_, __) {
                    final color =
                        latest?.healthColor ?? const Color(0xFF00F5A0);
                    return Text(
                      latest?.healthLabel ?? '—',
                      style: TextStyle(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                if (latest != null) ...[
                  _PenaltyRow('CPU  ×0.4',
                      latest!.cpuPenalty, const Color(0xFF0099CC)),
                  const SizedBox(height: 5),
                  _PenaltyRow('RAM  ×0.4',
                      latest!.ramPenalty, const Color(0xFF00A86B)),
                  const SizedBox(height: 5),
                  _PenaltyRow('Swap ×0.2',
                      latest!.swapPenalty, const Color(0xFFE6AC00)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PenaltyRow extends StatelessWidget {
  final String label;
  final double penalty;
  final Color color;

  const _PenaltyRow(this.label, this.penalty, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                color: const Color(0xFF111827).withOpacity(0.35),
                fontSize: 10,
                fontFamily: 'monospace')),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (penalty / 40).clamp(0, 1),
              backgroundColor: Colors.black.withOpacity(0.07),
              valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.7)),
              minHeight: 3,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${penalty.toStringAsFixed(1)}',
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace')),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ARC GAUGE CARD
// ══════════════════════════════════════════════════════════════════════════════

class _GaugeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Animation<double> anim;
  final MetricHistory history;
  final String? status;
  final Color? statusColor;

  const _GaugeCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.anim,
    required this.history,
    this.status,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        border: Border.all(color: color.withOpacity(0.18), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color.withOpacity(0.7), size: 13),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                    color: const Color(0xFF111827).withOpacity(0.4),
                    fontSize: 9,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: anim,
            builder: (_, __) {
              final pct = (anim.value * 100);
              return SizedBox(
                width: 96,
                height: 96,
                child: CustomPaint(
                  painter: _ArcGaugePainter(
                    value: anim.value,
                    color: color,
                    trackColor: Colors.white.withOpacity(0.06),
                    strokeWidth: 9,
                  ),
                  child: Center(
                    child: Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          if (status != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: (statusColor ?? color).withOpacity(0.12),
              ),
              child: Text(status!,
                  style: TextStyle(
                    color: statusColor ?? color,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  )),
            ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _GaugeStat('AVG', history.average, color),
              Container(
                  width: 1,
                  height: 20,
                  color: Colors.black.withOpacity(0.08)),
              _GaugeStat('PEAK', history.peak, color),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugeStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _GaugeStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                color: const Color(0xFF111827).withOpacity(0.28),
                fontSize: 8,
                letterSpacing: 1.5)),
        const SizedBox(height: 3),
        Text('${value.toStringAsFixed(1)}%',
            style: TextStyle(
                color: color.withOpacity(0.85),
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ARC GAUGE PAINTER
// ══════════════════════════════════════════════════════════════════════════════

class _ArcGaugePainter extends CustomPainter {
  final double value;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  const _ArcGaugePainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = Colors.black.withOpacity(0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (value <= 0) return;

    final sweep = sweepAngle * value.clamp(0.0, 1.0);

    // Glow
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      Paint()
        ..color = color.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 7
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // Fill
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcGaugePainter old) =>
      old.value != value || old.color != color;
}

// ══════════════════════════════════════════════════════════════════════════════
//  SPARKLINE CARD
// ══════════════════════════════════════════════════════════════════════════════

class _SparklineCard extends StatelessWidget {
  final String label;
  final String sublabel;
  final MetricHistory history;
  final Color color;

  const _SparklineCard({
    required this.label,
    required this.sublabel,
    required this.history,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        border: Border.all(color: Colors.black.withOpacity(0.07), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      )),
                  Text(sublabel,
                      style: TextStyle(
                          color: const Color(0xFF111827).withOpacity(0.25),
                          fontSize: 8,
                          letterSpacing: 1)),
                ],
              ),
              Row(
                children: [
                  _SparkStat('NOW', history.latest, color),
                  const SizedBox(width: 14),
                  _SparkStat('AVG', history.average, color.withOpacity(0.6)),
                  const SizedBox(width: 14),
                  _SparkStat('PEAK', history.peak, const Color(0xFFFF6B35)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 55,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparklinePainter(
                  values: history.values, color: color),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('60s ago',
                  style: TextStyle(
                      color: const Color(0xFF111827).withOpacity(0.2),
                      fontSize: 8)),
              Text('now',
                  style: TextStyle(
                      color: const Color(0xFF111827).withOpacity(0.2),
                      fontSize: 8)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SparkStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _SparkStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: const Color(0xFF111827).withOpacity(0.28),
                  fontSize: 8,
                  letterSpacing: 1)),
          const SizedBox(height: 2),
          Text('${value.toStringAsFixed(1)}%',
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      );
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final pts = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height - (values[i] / 100).clamp(0.0, 1.0) * size.height;
      pts.add(Offset(x, y));
    }

    // Fill area
    final fillPath = Path()..moveTo(pts.first.dx, size.height);
    for (final p in pts) fillPath.lineTo(p.dx, p.dy);
    fillPath.lineTo(pts.last.dx, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.22), color.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );

    // Line path
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final curr = pts[i];
      final cpx = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(cpx, prev.dy, cpx, curr.dy, curr.dx, curr.dy);
    }

    // Glow
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color.withOpacity(0.4)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Line
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dot at latest value
    canvas.drawCircle(
      pts.last,
      3.5,
      Paint()..color = color,
    );
    canvas.drawCircle(
      pts.last,
      3.5,
      Paint()
        ..color = color.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values;
}

// ══════════════════════════════════════════════════════════════════════════════
//  STAT TILE
// ══════════════════════════════════════════════════════════════════════════════

class _StatTile extends StatelessWidget {
  final String label, value, sub;
  final Color color;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(color: color.withOpacity(0.22), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color.withOpacity(0.7), size: 11),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                    color: const Color(0xFF111827).withOpacity(0.4),
                    fontSize: 8,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 4),
          Text(sub,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  RAM DETAIL CARD
// ══════════════════════════════════════════════════════════════════════════════

class _RamDetailCard extends StatelessWidget {
  final SensorSnapshot snap;

  const _RamDetailCard({required this.snap});

  @override
  Widget build(BuildContext context) {
    final used = snap.ramUsage / 100;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(color: Colors.black.withOpacity(0.07), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.memory_rounded,
                      color: const Color(0xFF00A86B).withOpacity(0.6),
                      size: 11),
                  const SizedBox(width: 5),
                  Text('RAM DETAIL',
                      style: TextStyle(
                        color: const Color(0xFF111827).withOpacity(0.35),
                        fontSize: 8,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
              Text(
                '${snap.ramValue.toStringAsFixed(2)} ${snap.ramUnitLabel} in use',
                style: const TextStyle(
                  color: Color(0xFF00A86B),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Segmented bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(
                  height: 12,
                  color: Colors.black.withOpacity(0.06),
                ),
                FractionallySizedBox(
                  widthFactor: used,
                  child: Container(
                    height: 12,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF00A86B), Color(0xFF0099CC)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Used  ${snap.ramUsage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                      color: Color(0xFF00A86B),
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
              Text('Free  ${(100 - snap.ramUsage).toStringAsFixed(1)}%',
                  style: TextStyle(
                      color: const Color(0xFF111827).withOpacity(0.35),
                      fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  GRID BACKGROUND
// ══════════════════════════════════════════════════════════════════════════════

class _GridBackground extends StatelessWidget {
  const _GridBackground();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: _GridPainter(),
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.3,
              colors: [Color(0xFFE8F0FE), Color(0xFFF4F6FB)],
            ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0099CC).withOpacity(0.07)
      ..strokeWidth = 0.5;

    const step = 38.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}