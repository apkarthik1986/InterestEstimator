import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  
  // Interest calculation results
  double? _loanAmount;
  int? _months;
  double? _interestPerMonth;
  double? _totalInterest;
  double? _totalAmount;
  
  // Monthly interest rate (2% as per Excel)
  static const double monthlyInterestRate = 0.02;

  @override
  void dispose() {
    _loanAmountController.dispose();
    super.dispose();
  }

  /// Calculate months between loan date and today using the Excel logic:
  /// YEARFRAC * 12 - 1, then round up if fractional part >= 0.07
  int _calculateMonths(DateTime loanDate, DateTime today) {
    // Calculate year fraction similar to Excel YEARFRAC
    final int daysDiff = today.difference(loanDate).inDays;
    final double yearFrac = daysDiff / 365.0;
    double months = (yearFrac * 12) - 1;
    
    // Apply Excel rounding logic: if remainder >= 0.07, round up; else round down
    if (months < 0) months = 0;
    final double fractionalPart = months - months.floor();
    return fractionalPart >= 0.07 ? months.ceil() : months.floor();
  }

  void _calculateInterest() {
    if (_formKey.currentState!.validate() && _loanDate != null) {
      final amount = double.tryParse(_loanAmountController.text.replaceAll(',', ''));
      if (amount == null || amount <= 0) return;

      final today = DateTime.now();
      final months = _calculateMonths(_loanDate!, today);
      final interestPerMonth = amount * monthlyInterestRate;
      final totalInterest = interestPerMonth * months;
      final totalAmount = amount + totalInterest;

      setState(() {
        _loanAmount = amount;
        _months = months;
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
    _loanAmount = null;
    _months = null;
    _interestPerMonth = null;
    _totalInterest = null;
    _totalAmount = null;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Pawn Broker Interest'),
        actions: [
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
              // Info Card
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Interest Rate: 2% per month',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
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
