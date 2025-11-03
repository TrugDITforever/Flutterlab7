import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('expenses');
  runApp(const ExpenseApp());
}

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const ExpenseHomePage(),
    );
  }
}

class ExpenseHomePage extends StatefulWidget {
  const ExpenseHomePage({super.key});

  @override
  State<ExpenseHomePage> createState() => _ExpenseHomePageState();
}

class _ExpenseHomePageState extends State<ExpenseHomePage> {
  final Box expenseBox = Hive.box('expenses');
  final TextEditingController titleCtrl = TextEditingController();
  final TextEditingController amountCtrl = TextEditingController();

  void _addExpense() {
    final title = titleCtrl.text.trim();
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;

    if (title.isEmpty || amount <= 0) return;

    expenseBox.add({
      'title': title,
      'amount': amount,
      'date': DateTime.now().toIso8601String(),
    });

    titleCtrl.clear();
    amountCtrl.clear();
    Navigator.pop(context);
    setState(() {});
  }

  void _deleteExpense(int index) {
    expenseBox.deleteAt(index);
    setState(() {});
  }

  double getTotalToday() {
    final now = DateTime.now();
    final todayExpenses = expenseBox.values.where((e) {
      final date = DateTime.parse(e['date']);
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();

    return todayExpenses.fold(0, (sum, e) => sum + e['amount']);
  }

  Map<String, double> getDailySummary() {
    final Map<String, double> summary = {};
    for (var e in expenseBox.values) {
      final date = DateTime.parse(e['date']);
      final key = "${date.day}/${date.month}";
      summary[key] = (summary[key] ?? 0) + e['amount'];
    }
    return summary;
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(onPressed: _addExpense, child: const Text('Save')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenses = expenseBox.values.toList().reversed.toList();
    final dailySummary = getDailySummary();

    return Scaffold(
      appBar: AppBar(
        title: const Text('💰 Expense Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ChartPage(summary: dailySummary)),
              );
            },
          ),
        ],
      ),
      body: expenses.isEmpty
          ? const Center(child: Text('No expenses yet. Tap + to add.'))
          : ListView.builder(
              itemCount: expenses.length,
              itemBuilder: (context, index) {
                final e = expenses[index];
                final date = DateTime.parse(e['date']);
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: ListTile(
                    title: Text(e['title']),
                    subtitle: Text(
                        "${date.day}/${date.month}/${date.year} - ${e['amount']} ₫"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteExpense(expenses.length - 1 - index),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.teal[50],
        child: Text(
          "Today's total: ${getTotalToday().toStringAsFixed(0)} ₫",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// 📊 Trang biểu đồ tổng hợp
class ChartPage extends StatelessWidget {
  final Map<String, double> summary;
  const ChartPage({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final keys = summary.keys.toList();
    final values = summary.values.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('📈 Expense Summary')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: summary.isEmpty
            ? const Center(child: Text('No data to display.'))
            : BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (values.reduce((a, b) => a > b ? a : b)) * 1.2,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: true, reservedSize: 40)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          final index = val.toInt();
                          if (index < 0 || index >= keys.length) {
                            return const SizedBox();
                          }
                          return Text(keys[index],
                              style: const TextStyle(fontSize: 12));
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(
                    keys.length,
                    (i) => BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: values[i],
                          width: 20,
                          color: Colors.teal,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
