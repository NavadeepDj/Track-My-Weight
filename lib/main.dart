import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/person.dart';
import 'models/weight_entry.dart';
import 'services/app_database.dart';
import 'services/app_logger.dart';
import 'services/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);
  AppLogger.info(
    'Environment loaded',
    data: {'supabaseConfigured': SupabaseConfig.isConfigured},
  );

  if (SupabaseConfig.isConfigured) {
    AppLogger.info('Initializing Supabase client');
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  } else {
    AppLogger.warning(
      'Supabase credentials missing; using local SQLite storage',
    );
  }

  runApp(const TrackMyWeightApp());
}

class TrackMyWeightApp extends StatefulWidget {
  const TrackMyWeightApp({super.key});

  @override
  State<TrackMyWeightApp> createState() => _TrackMyWeightAppState();
}

class _TrackMyWeightAppState extends State<TrackMyWeightApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleThemeMode() {
    setState(() {
      _themeMode = switch (_themeMode) {
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
        ThemeMode.system => ThemeMode.light,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      primary: const Color(0xFF0F766E),
      secondary: const Color(0xFFE9B949),
      surface: const Color(0xFFFBFCF8),
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2DD4BF),
      primary: const Color(0xFF5EEAD4),
      secondary: const Color(0xFFFACC15),
      surface: const Color(0xFF111816),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Track My Weight',
      themeMode: _themeMode,
      theme: _buildTheme(
        scheme: lightScheme,
        scaffold: const Color(0xFFF3F6F0),
        card: Colors.white,
        border: const Color(0xFFE2E8DF),
        input: Colors.white,
      ),
      darkTheme: _buildTheme(
        scheme: darkScheme,
        scaffold: const Color(0xFF07110F),
        card: const Color(0xFF101A17),
        border: const Color(0xFF263B36),
        input: const Color(0xFF111E1A),
      ),
      home: DashboardScreen(
        themeMode: _themeMode,
        onToggleTheme: _toggleThemeMode,
      ),
    );
  }

  ThemeData _buildTheme({
    required ColorScheme scheme,
    required Color scaffold,
    required Color card,
    required Color border,
    required Color input,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scaffold,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: input,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      dividerTheme: DividerThemeData(color: border),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
    );
  }
}

class PersonSummary {
  const PersonSummary({required this.person, required this.entries});

  final Person person;
  final List<WeightEntry> entries;

  WeightEntry? get latest => entries.isEmpty ? null : entries.last;
  WeightEntry? get previous =>
      entries.length < 2 ? null : entries[entries.length - 2];
  double? get change => latest == null || previous == null
      ? null
      : latest!.weightKg - previous!.weightKg;
  double? get totalChange => entries.length < 2
      ? null
      : entries.last.weightKg - entries.first.weightKg;
  int get recordCount => entries.length;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<PersonSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadSummaries();
  }

  Future<List<PersonSummary>> _loadSummaries() async {
    final people = await AppDatabase.instance.getPeople();
    final summaries = <PersonSummary>[];
    for (final person in people) {
      final entries = await AppDatabase.instance.getEntriesForPerson(
        person.id!,
      );
      summaries.add(PersonSummary(person: person, entries: entries));
    }
    summaries.sort((a, b) {
      final aDate = a.latest?.recordedAt ?? a.person.createdAt;
      final bDate = b.latest?.recordedAt ?? b.person.createdAt;
      return bDate.compareTo(aDate);
    });
    return summaries;
  }

  void _refresh() {
    setState(() {
      _future = _loadSummaries();
    });
  }

  Future<void> _openAddPerson() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AddPersonSheet(),
    );
    if (added == true) {
      _refresh();
    }
  }

  Future<void> _openAddEntry([Person? person]) async {
    final people = await AppDatabase.instance.getPeople();
    if (!mounted) {
      return;
    }

    if (people.isEmpty) {
      await _openAddPerson();
      return;
    }

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          AddWeightEntrySheet(people: people, selectedPerson: person),
    );
    if (added == true) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            AppLogoMark(size: 38),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track My Weight',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 2),
                Text(
                  'Track every change, clearly.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF647067),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: themeModeLabel(widget.themeMode),
            onPressed: widget.onToggleTheme,
            icon: Icon(themeModeIcon(widget.themeMode)),
          ),
          IconButton(
            tooltip: 'Add person',
            onPressed: _openAddPerson,
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<PersonSummary>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final summaries = snapshot.data ?? [];
          if (summaries.isEmpty) {
            return EmptyDashboard(onAddPerson: _openAddPerson);
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: summaries.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return DashboardHero(
                    summaries: summaries,
                    onAddPerson: _openAddPerson,
                    isCloudEnabled: AppDatabase.instance.isCloudEnabled,
                  );
                }

                if (index == 1) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(2, 20, 2, 10),
                    child: SectionTitle(
                      title: 'People',
                      subtitle: 'Tap a person to see their full record',
                    ),
                  );
                }

                final summary = summaries[index - 2];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PersonCard(
                    summary: summary,
                    onAddEntry: () => _openAddEntry(summary.person),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PersonDetailScreen(person: summary.person),
                        ),
                      );
                      _refresh();
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEntry(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log weight'),
      ),
    );
  }
}

class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        Icons.monitor_weight_rounded,
        size: size * 0.56,
        color: Colors.white,
      ),
    );
  }
}

class DashboardHero extends StatelessWidget {
  const DashboardHero({
    super.key,
    required this.summaries,
    required this.onAddPerson,
    required this.isCloudEnabled,
  });

  final List<PersonSummary> summaries;
  final VoidCallback onAddPerson;
  final bool isCloudEnabled;

  @override
  Widget build(BuildContext context) {
    final totalRecords = summaries.fold<int>(
      0,
      (total, summary) => total + summary.recordCount,
    );
    final updatedPeople = summaries
        .where((summary) => summary.latest != null)
        .length;
    final lastEntry = summaries
        .map((summary) => summary.latest?.recordedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (latest, date) {
          if (latest == null || date.isAfter(latest)) {
            return date;
          }
          return latest;
        });

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B3B38),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF165A54)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppLogoMark(size: 46),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weight register',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'A clearer version of the paper book.',
                      style: TextStyle(
                        color: Color(0xFFC8D8D2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Add person',
                onPressed: onAddPerson,
                icon: const Icon(Icons.person_add_alt_1_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: HeroMetric(
                  label: 'People',
                  value: summaries.length.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: HeroMetric(
                  label: 'Records',
                  value: totalRecords.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: HeroMetric(
                  label: 'Updated',
                  value: '$updatedPeople/${summaries.length}',
                ),
              ),
            ],
          ),
          if (lastEntry != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  color: Color(0xFFE9B949),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Last entry ${DateFormat.yMMMd().format(lastEntry)}',
                  style: const TextStyle(
                    color: Color(0xFFE8F0EC),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          CloudStatusBadge(isCloudEnabled: isCloudEnabled),
        ],
      ),
    );
  }
}

class CloudStatusBadge extends StatelessWidget {
  const CloudStatusBadge({super.key, required this.isCloudEnabled});

  final bool isCloudEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCloudEnabled
                ? Icons.cloud_done_rounded
                : Icons.phone_android_rounded,
            color: const Color(0xFFE9B949),
            size: 17,
          ),
          const SizedBox(width: 7),
          Text(
            isCloudEnabled ? 'Cloud sync: Supabase' : 'Storage: This device',
            style: const TextStyle(
              color: Color(0xFFE8F0EC),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class HeroMetric extends StatelessWidget {
  const HeroMetric({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFC8D8D2), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: Color(0xFF647067))),
            ],
          ),
        ),
      ],
    );
  }
}

class EmptyDashboard extends StatelessWidget {
  const EmptyDashboard({super.key, required this.onAddPerson});

  final VoidCallback onAddPerson;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogoMark(size: 74),
                const SizedBox(height: 20),
                const Text(
                  'Start your digital weight book',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Add a person, then record each check-in with date, weight, and notes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF5B665D), height: 1.35),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: onAddPerson,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Add first person'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PersonCard extends StatelessWidget {
  const PersonCard({
    super.key,
    required this.summary,
    required this.onAddEntry,
    required this.onTap,
  });

  final PersonSummary summary;
  final VoidCallback onAddEntry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final latest = summary.latest;
    final change = summary.change;
    final totalChange = summary.totalChange;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFE1F1EC),
                    child: Text(
                      summary.person.name.characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF0F766E),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.person.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          latest == null
                              ? 'Ready for first record'
                              : DateFormat.yMMMd().format(latest.recordedAt),
                          style: const TextStyle(color: Color(0xFF647067)),
                        ),
                      ],
                    ),
                  ),
                  ChangeChip(change: change),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Latest weight',
                          style: TextStyle(
                            color: Color(0xFF647067),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          latest == null
                              ? '-- kg'
                              : '${latest.weightKg.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total change',
                          style: TextStyle(
                            color: Color(0xFF647067),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          totalChange == null ? '-- kg' : signedKg(totalChange),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: changeColor(totalChange),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Log weight',
                    onPressed: onAddEntry,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PersonHeader extends StatelessWidget {
  const PersonHeader({
    super.key,
    required this.person,
    required this.entries,
    required this.totalChange,
  });

  final Person person;
  final List<WeightEntry> entries;
  final double? totalChange;

  @override
  Widget build(BuildContext context) {
    final latest = entries.isEmpty ? null : entries.last;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B3B38),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF165A54)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Text(
                  person.name.characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF0F766E),
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entries.length} weight records',
                      style: const TextStyle(
                        color: Color(0xFFC8D8D2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: HeroMetric(
                  label: latest == null
                      ? 'No latest entry'
                      : DateFormat.MMMd().format(latest.recordedAt),
                  value: latest == null
                      ? '-- kg'
                      : '${latest.weightKg.toStringAsFixed(1)} kg',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: HeroMetric(
                  label: 'Since first entry',
                  value: totalChange == null ? '-- kg' : signedKg(totalChange!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PersonDetailScreen extends StatefulWidget {
  const PersonDetailScreen({super.key, required this.person});

  final Person person;

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  late Future<List<WeightEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadEntries();
  }

  Future<List<WeightEntry>> _loadEntries() {
    return AppDatabase.instance.getEntriesForPerson(widget.person.id!);
  }

  void _refresh() {
    setState(() {
      _future = _loadEntries();
    });
  }

  Future<void> _addEntry() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddWeightEntrySheet(
        people: [widget.person],
        selectedPerson: widget.person,
      ),
    );
    if (added == true) {
      _refresh();
    }
  }

  Future<void> _deleteEntry(WeightEntry entry) async {
    await AppDatabase.instance.deleteWeightEntry(entry.id!);
    _refresh();
  }

  Future<void> _deletePerson() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete person?'),
        content: Text(
          'This removes ${widget.person.name} and all weight records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AppDatabase.instance.deletePerson(widget.person.id!);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.person.name),
        actions: [
          IconButton(
            tooltip: 'Delete person',
            onPressed: _deletePerson,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<WeightEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data ?? [];
          final latest = entries.isEmpty ? null : entries.last;
          final first = entries.isEmpty ? null : entries.first;
          final totalChange = latest == null || first == null
              ? null
              : latest.weightKg - first.weightKg;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              PersonHeader(
                person: widget.person,
                entries: entries,
                totalChange: totalChange,
              ),
              const SizedBox(height: 12),
              StatsGrid(entries: entries, totalChange: totalChange),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Weight trend',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.show_chart_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 220,
                        child: entries.length < 2
                            ? const Center(
                                child: Text(
                                  'Add two records to see the line move.',
                                  style: TextStyle(color: Color(0xFF647067)),
                                ),
                              )
                            : WeightTrendChart(entries: entries),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(2, 20, 2, 10),
                child: SectionTitle(
                  title: 'History',
                  subtitle: 'Every check-in sorted newest first',
                ),
              ),
              if (entries.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'No weight records yet.',
                      style: TextStyle(color: Color(0xFF647067)),
                    ),
                  ),
                )
              else
                ...entries.reversed.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: HistoryTile(
                      entry: entry,
                      onDelete: () => _deleteEntry(entry),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEntry,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log weight'),
      ),
    );
  }
}

class StatsGrid extends StatelessWidget {
  const StatsGrid({
    super.key,
    required this.entries,
    required this.totalChange,
  });

  final List<WeightEntry> entries;
  final double? totalChange;

  @override
  Widget build(BuildContext context) {
    final latest = entries.isEmpty ? null : entries.last.weightKg;
    final low = entries.isEmpty
        ? null
        : entries
              .map((entry) => entry.weightKg)
              .reduce((a, b) => a < b ? a : b);
    final high = entries.isEmpty
        ? null
        : entries
              .map((entry) => entry.weightKg)
              .reduce((a, b) => a > b ? a : b);

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        StatCard(
          icon: Icons.monitor_weight_rounded,
          label: 'Current',
          value: latest == null ? '-' : '${latest.toStringAsFixed(1)} kg',
        ),
        StatCard(
          icon: Icons.swap_vert_rounded,
          label: 'Total change',
          value: totalChange == null ? '-' : signedKg(totalChange!),
          valueColor: changeColor(totalChange),
        ),
        StatCard(
          icon: Icons.south_rounded,
          label: 'Lowest',
          value: low == null ? '-' : '${low.toStringAsFixed(1)} kg',
        ),
        StatCard(
          icon: Icons.north_rounded,
          label: 'Highest',
          value: high == null ? '-' : '${high.toStringAsFixed(1)} kg',
        ),
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF6A746D)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: valueColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WeightTrendChart extends StatelessWidget {
  const WeightTrendChart({super.key, required this.entries});

  final List<WeightEntry> entries;

  @override
  Widget build(BuildContext context) {
    final weights = entries.map((entry) => entry.weightKg).toList();
    final minWeight = weights.reduce((a, b) => a < b ? a : b);
    final maxWeight = weights.reduce((a, b) => a > b ? a : b);
    final rangePadding = ((maxWeight - minWeight) * 0.15).clamp(1.0, 8.0);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (entries.length - 1).toDouble(),
        minY: minWeight - rangePadding,
        maxY: maxWeight + rangePadding,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: const TextStyle(fontSize: 11, color: Color(0xFF6A746D)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: entries.length <= 4
                  ? 1
                  : (entries.length / 4).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= entries.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat.Md().format(entries[index].recordedAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6A746D),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < entries.length; i++)
                FlSpot(i.toDouble(), entries[i].weightKg),
            ],
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 4,
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
            ),
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}

class HistoryTile extends StatelessWidget {
  const HistoryTile({super.key, required this.entry, required this.onDelete});

  final WeightEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.only(
          left: 12,
          right: 8,
          top: 4,
          bottom: 4,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFE1F1EC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat.MMM().format(entry.recordedAt).toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF0F766E),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                DateFormat.d().format(entry.recordedAt),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        title: Text(
          '${entry.weightKg.toStringAsFixed(1)} kg',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          [
            DateFormat.y().format(entry.recordedAt),
            if ((entry.note ?? '').isNotEmpty) entry.note!,
          ].join(' | '),
        ),
        trailing: IconButton(
          tooltip: 'Delete entry',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ),
    );
  }
}

class SheetFrame extends StatelessWidget {
  const SheetFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD5DED7),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Color(0xFF647067))),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class AddPersonSheet extends StatefulWidget {
  const AddPersonSheet({super.key});

  @override
  State<AddPersonSheet> createState() => _AddPersonSheetState();
}

class _AddPersonSheetState extends State<AddPersonSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await AppDatabase.instance.addPerson(_nameController.text);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'Add person',
      subtitle: 'Create a profile before recording weight.',
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Save person'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddWeightEntrySheet extends StatefulWidget {
  const AddWeightEntrySheet({
    super.key,
    required this.people,
    this.selectedPerson,
  });

  final List<Person> people;
  final Person? selectedPerson;

  @override
  State<AddWeightEntrySheet> createState() => _AddWeightEntrySheetState();
}

class _AddWeightEntrySheetState extends State<AddWeightEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _noteController = TextEditingController();
  late Person _selectedPerson;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedPerson = widget.selectedPerson ?? widget.people.first;
  }

  @override
  void dispose() {
    _weightController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDate: _selectedDate,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await AppDatabase.instance.addWeightEntry(
      WeightEntry(
        id: null,
        personId: _selectedPerson.id!,
        weightKg: double.parse(_weightController.text.trim()),
        recordedAt: _selectedDate,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'Log weight',
      subtitle: 'Record the number exactly as you checked it.',
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.people.length > 1)
                DropdownButtonFormField<Person>(
                  initialValue: _selectedPerson,
                  decoration: const InputDecoration(
                    labelText: 'Person',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  items: [
                    for (final person in widget.people)
                      DropdownMenuItem(value: person, child: Text(person.name)),
                  ],
                  onChanged: (person) {
                    if (person != null) {
                      setState(() => _selectedPerson = person);
                    }
                  },
                ),
              if (widget.people.length > 1) const SizedBox(height: 12),
              TextFormField(
                controller: _weightController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Weight in kg',
                  prefixIcon: Icon(Icons.monitor_weight_outlined),
                ),
                validator: (value) {
                  final weight = double.tryParse(value?.trim() ?? '');
                  if (weight == null || weight <= 0 || weight > 500) {
                    return 'Enter a valid weight';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_rounded),
                label: Text(DateFormat.yMMMd().format(_selectedDate)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'Optional',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save weight'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChangeChip extends StatelessWidget {
  const ChangeChip({super.key, required this.change});

  final double? change;

  @override
  Widget build(BuildContext context) {
    if (change == null) {
      return const Chip(label: Text('New'));
    }

    return Chip(
      avatar: Icon(
        change! > 0
            ? Icons.trending_up_rounded
            : change! < 0
            ? Icons.trending_down_rounded
            : Icons.drag_handle_rounded,
        size: 18,
        color: changeColor(change),
      ),
      label: Text(signedKg(change!)),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w800,
        color: changeColor(change),
      ),
      backgroundColor: changeColor(change).withValues(alpha: 0.1),
      side: BorderSide.none,
    );
  }
}

Color changeColor(double? value) {
  if (value == null || value == 0) {
    return const Color(0xFF647067);
  }
  return value < 0 ? const Color(0xFF1D8F5A) : const Color(0xFFC75B37);
}

String signedKg(double value) {
  final prefix = value > 0 ? '+' : '';
  return '$prefix${value.toStringAsFixed(1)} kg';
}

IconData themeModeIcon(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.light => Icons.light_mode_rounded,
    ThemeMode.dark => Icons.dark_mode_rounded,
    ThemeMode.system => Icons.contrast_rounded,
  };
}

String themeModeLabel(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.light => 'Light mode',
    ThemeMode.dark => 'Dark mode',
    ThemeMode.system => 'System theme',
  };
}
