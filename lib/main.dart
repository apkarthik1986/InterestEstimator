import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Interest Estimator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      home: const InterestCalculatorPage(),
    );
  }
}

class InterestCalculatorPage extends StatefulWidget {
  const InterestCalculatorPage({super.key});

  @override
  State<InterestCalculatorPage> createState() => _InterestCalculatorPageState();
}

class _InterestCalculatorPageState extends State<InterestCalculatorPage> {
  final _formKey = GlobalKey<FormState>();
  final _loanAmountController = TextEditingController();
  DateTime? _loanDate;
  
  // Base settings (configurable via settings dialog)
  double _interestRatePerMonth = 2.0;
  
  // Settings dialog controller
  late final TextEditingController _settingsInterestRateController;
  
  // Interest calculation results
  double? _loanAmount;
  int? _months;
  double? _interestRate;
  double? _interestPerMonth;
  double? _totalInterest;
  double? _totalAmount;

  @override
  void initState() {
    super.initState();
    _settingsInterestRateController = TextEditingController();
    _loadBaseValues();
  }

  @override
  void dispose() {
    _loanAmountController.dispose();
    _settingsInterestRateController.dispose();
    super.dispose();
  }

  Future<void> _loadBaseValues() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _interestRatePerMonth = prefs.getDouble('interest_rate') ?? 2.0;
      _updateSettingsControllers();
    });
  }

  void _updateSettingsControllers() {
    _settingsInterestRateController.text = _interestRatePerMonth.toString();
  }

  Future<void> _saveBaseValues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('interest_rate', _interestRatePerMonth);
  }

  Future<void> _resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _interestRatePerMonth = 2.0;
      _settingsInterestRateController.text = '2.0';
    });
    await prefs.setDouble('interest_rate', 2.0);
  }

  /// Calculate months between loan date and today using the Excel logic:
  /// YEARFRAC * 12 - 1, then round up if fractional part >= 0.07
  int _calculateMonths(DateTime loanDate, DateTime today) {
    // Calculate year fraction similar to Excel YEARFRAC
    final int daysDiff = today.difference(loanDate).inDays;
    final double yearFrac = daysDiff / 365.0;
    double months = (yearFrac * 12) - 1;
    
    // Handle negative values first before fractional part calculation
    if (months < 0) {
      return 0;
    }
    
    // Apply Excel rounding logic: if remainder >= 0.07, round up; else round down
    final double fractionalPart = months - months.floor();
    return fractionalPart >= 0.07 ? months.ceil() : months.floor();
  }

  void _calculateInterest() {
    if (_formKey.currentState!.validate() && _loanDate != null) {
      final amount = double.tryParse(_loanAmountController.text.replaceAll(',', ''));
      if (amount == null || amount <= 0) return;

      final today = DateTime.now();
      final months = _calculateMonths(_loanDate!, today);
      final monthlyRate = _interestRatePerMonth / 100;
      final interestPerMonth = amount * monthlyRate;
      final totalInterest = interestPerMonth * months;
      final totalAmount = amount + totalInterest;

      setState(() {
        _loanAmount = amount;
        _months = months;
        _interestRate = _interestRatePerMonth;
        _interestPerMonth = interestPerMonth;
        _totalInterest = totalInterest;
        _totalAmount = totalAmount;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _loanDate ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Select Loan Date',
    );
    if (picked != null) {
      setState(() {
        _loanDate = picked;
        // Clear previous results when date changes
        _clearResults();
      });
    }
  }

  void _clearResults() {
    setState(() {
      _loanAmount = null;
      _months = null;
      _interestRate = null;
      _interestPerMonth = null;
      _totalInterest = null;
      _totalAmount = null;
    });
  }

  void _reset() {
    setState(() {
      _loanAmountController.clear();
      _loanDate = null;
      _clearResults();
    });
  }

  String _formatCurrency(double value) {
    return '₹${value.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showSettingsDialog() {
    // Update controller with current value before showing dialog
    _updateSettingsControllers();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚙️ Base Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Interest Rate Settings',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Interest Rate (% per month)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., 2.0',
                  suffixText: '%',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                controller: _settingsInterestRateController,
                onChanged: (value) {
                  _interestRatePerMonth = double.tryParse(value) ?? 2.0;
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This rate will be used for all interest calculations.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _resetToDefaults();
              Navigator.of(context).pop();
              setState(() {});
            },
            child: const Text('Reset to Default'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _saveBaseValues();
              Navigator.of(context).pop();
              setState(() {
                _clearResults();
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Pawn Broker Interest'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
            tooltip: 'Reset',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Current Interest Rate Display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.percent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Interest Rate: ${_interestRatePerMonth.toStringAsFixed(2)}% per month',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _showSettingsDialog,
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Loan Amount Input
              TextFormField(
                controller: _loanAmountController,
                decoration: const InputDecoration(
                  labelText: 'Loan Amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                  hintText: 'Enter loan amount',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d,]')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter loan amount';
                  }
                  final amount = double.tryParse(value.replaceAll(',', ''));
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
                onChanged: (_) => _clearResults(),
              ),
              const SizedBox(height: 16),
              
              // Loan Date Picker
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Loan Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _loanDate != null 
                        ? _formatDate(_loanDate!)
                        : 'Select loan date',
                    style: TextStyle(
                      color: _loanDate != null 
                          ? Theme.of(context).textTheme.bodyLarge?.color
                          : Theme.of(context).hintColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Calculate Button
              FilledButton.icon(
                onPressed: _loanDate != null ? _calculateInterest : null,
                icon: const Icon(Icons.calculate),
                label: const Text('Calculate Interest'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 24),
              
              // Results Section
              if (_totalAmount != null) ...[
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Interest Summary',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(height: 24),
                        _buildResultRow('Loan Amount', _formatCurrency(_loanAmount!)),
                        _buildResultRow('Interest Rate', '${_interestRate!.toStringAsFixed(2)}% / month'),
                        _buildResultRow('Loan Date', _formatDate(_loanDate!)),
                        _buildResultRow('Today\'s Date', _formatDate(DateTime.now())),
                        _buildResultRow('Duration', '$_months month${_months == 1 ? '' : 's'}'),
                        _buildResultRow('Interest/Month', _formatCurrency(_interestPerMonth!)),
                        const Divider(height: 16),
                        _buildResultRow(
                          'Total Interest',
                          _formatCurrency(_totalInterest!),
                          isHighlight: true,
                          highlightColor: Colors.orange,
                        ),
                        _buildResultRow(
                          'Total Amount',
                          _formatCurrency(_totalAmount!),
                          isHighlight: true,
                          highlightColor: Colors.green,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {bool isHighlight = false, Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isHighlight ? 16 : 14,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 18 : 14,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              color: highlightColor,
            ),
          ),
        ],
      ),
    );
  }
}
