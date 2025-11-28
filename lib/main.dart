import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

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
  final _loanNumberController = TextEditingController();
  DateTime? _loanDate;
  
  // Loan ledger data loaded from Excel - indexed by loan number for O(1) lookup
  Map<String, Map<String, dynamic>> _loanLedger = {};
  bool _isLedgerLoaded = false;
  String? _loanLookupError;
  
  // Base settings (configurable via settings dialog)
  double _interestRatePerMonth = 2.0;
  String _excelFilePath = '';  // Empty means use bundled asset
  
  // Settings dialog controller
  late final TextEditingController _settingsInterestRateController;
  late final TextEditingController _settingsExcelPathController;
  
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
    _settingsExcelPathController = TextEditingController();
    _loadBaseValues();
  }

  Future<void> _loadLoanLedger() async {
    try {
      Uint8List bytes;
      
      if (_excelFilePath.isNotEmpty) {
        // Load from file path
        final file = File(_excelFilePath);
        if (!await file.exists()) {
          setState(() {
            _isLedgerLoaded = false;
            _loanLookupError = 'Excel file not found at the specified path';
          });
          return;
        }
        
        try {
          bytes = await file.readAsBytes();
        } catch (e) {
          setState(() {
            _isLedgerLoaded = false;
            _loanLookupError = 'Failed to read file: ${e.toString()}';
          });
          return;
        }
      } else {
        // Load from bundled asset
        final ByteData data = await rootBundle.load('Loan Ledger.xlsx');
        bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      }
      
      final excel = Excel.decodeBytes(bytes);
      
      if (excel.tables.isEmpty) {
        setState(() {
          _isLedgerLoaded = false;
          _loanLookupError = 'Excel file contains no sheets';
        });
        return;
      }
      
      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null) return;
      
      final Map<String, Map<String, dynamic>> ledger = {};
      
      // Skip header row (index 0) and process data rows
      for (int i = 1; i < sheet.maxRows; i++) {
        final row = sheet.row(i);
        if (row.isEmpty || row[0]?.value == null) continue;
        
        final loanDateValue = row[0]?.value;
        final loanNumberValue = row[1]?.value;
        final amountValue = row[2]?.value;
        
        if (loanNumberValue == null) continue;
        
        DateTime? loanDate;
        if (loanDateValue is DateCellValue) {
          loanDate = DateTime(
            loanDateValue.year, 
            loanDateValue.month, 
            loanDateValue.day
          );
        }
        
        double? amount;
        if (amountValue is IntCellValue) {
          amount = amountValue.value.toDouble();
        } else if (amountValue is DoubleCellValue) {
          amount = amountValue.value;
        }
        
        String loanNumber;
        if (loanNumberValue is IntCellValue) {
          loanNumber = loanNumberValue.value.toString();
        } else if (loanNumberValue is TextCellValue) {
          // TextCellValue.value returns TextSpan in excel 4.x, use toString() for safe conversion
          loanNumber = loanNumberValue.value.toString();
        } else {
          loanNumber = loanNumberValue.toString();
        }
        
        // Use loan number as key for O(1) lookup
        ledger[loanNumber] = {
          'loanDate': loanDate,
          'amount': amount,
        };
      }
      
      setState(() {
        _loanLedger = ledger;
        _isLedgerLoaded = true;
      });
    } catch (e) {
      setState(() {
        _isLedgerLoaded = false;
        _loanLookupError = 'Failed to load loan ledger: ${e.toString()}';
      });
    }
  }

  void _lookupLoan() {
    final loanNumber = _loanNumberController.text.trim();
    if (loanNumber.isEmpty) {
      setState(() {
        _loanLookupError = null;
      });
      return;
    }
    
    // O(1) lookup using Map
    final loan = _loanLedger[loanNumber];
    
    if (loan == null) {
      setState(() {
        _loanLookupError = 'Loan number not found in ledger';
        _loanDate = null;
        _loanAmountController.clear();
        _clearResults();
      });
      return;
    }
    
    setState(() {
      _loanLookupError = null;
      _loanDate = loan['loanDate'] as DateTime?;
      final amount = loan['amount'] as double?;
      if (amount != null) {
        _loanAmountController.text = amount.round().toString();
      }
    });
    
    // Trigger interest calculation
    _tryCalculateInterest();
  }

  @override
  void dispose() {
    _loanAmountController.dispose();
    _loanNumberController.dispose();
    _settingsInterestRateController.dispose();
    _settingsExcelPathController.dispose();
    super.dispose();
  }

  Future<void> _loadBaseValues() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _interestRatePerMonth = prefs.getDouble('interest_rate') ?? 2.0;
      _excelFilePath = prefs.getString('excel_file_path') ?? '';
      _updateSettingsControllers();
    });
    // Load loan ledger after settings are loaded
    _loadLoanLedger();
  }

  void _updateSettingsControllers() {
    _settingsInterestRateController.text = _interestRatePerMonth.toString();
    _settingsExcelPathController.text = _excelFilePath;
  }

  Future<void> _saveBaseValues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('interest_rate', _interestRatePerMonth);
    await prefs.setString('excel_file_path', _excelFilePath);
  }

  Future<void> _resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _interestRatePerMonth = 2.0;
      _excelFilePath = '';
      _settingsInterestRateController.text = '2.0';
      _settingsExcelPathController.text = '';
    });
    await prefs.setDouble('interest_rate', 2.0);
    await prefs.setString('excel_file_path', '');
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
      });
      // Recalculate automatically when date changes
      _tryCalculateInterest();
    }
  }

  void _tryCalculateInterest() {
    final amountText = _loanAmountController.text.replaceAll(',', '');
    final amount = double.tryParse(amountText);
    
    if (amount != null && amount > 0 && _loanDate != null) {
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
    } else {
      _clearResults();
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
      _loanNumberController.clear();
      _loanDate = null;
      _loanLookupError = null;
      _clearResults();
    });
  }

  String _formatCurrency(double value) {
    return 'Rs.${value.round()}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Generate PDF document optimized for thermal printer (58mm/80mm)
  /// Uses large fonts for readability on thermal printer receipts
  Future<void> _printReceipt() async {
    if (_totalAmount == null || _loanDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please calculate interest before printing'),
        ),
      );
      return;
    }

    try {
      final pdf = pw.Document();

      // Use standard thermal receipt paper format (58mm width)
      // Using roll format with minimal margins to prevent extra space at bottom
      final pageFormat = PdfPageFormat.roll57.copyWith(
        marginBottom: 0,
      );

      // Large font sizes for thermal printer readability
      final titleStyle = pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
      );
      final headerStyle = pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
      );
      const labelStyle = pw.TextStyle(fontSize: 12);
      final valueStyle = pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
      );
      final totalStyle = pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Header
                pw.Text('INTEREST RECEIPT', style: titleStyle),
                pw.SizedBox(height: 4),
                pw.Container(
                  width: double.infinity,
                  child: pw.Divider(thickness: 1),
                ),
                pw.SizedBox(height: 8),
                
                // Loan Details Section
                _buildPdfRow('Loan Amount:', _formatCurrency(_loanAmount!), labelStyle, valueStyle),
                pw.SizedBox(height: 4),
                _buildPdfRow('Rate:', '${_interestRate!.toStringAsFixed(2)}%/mo', labelStyle, valueStyle),
                pw.SizedBox(height: 4),
                _buildPdfRow('Loan Date:', _formatDate(_loanDate!), labelStyle, valueStyle),
                pw.SizedBox(height: 4),
                _buildPdfRow('Today:', _formatDate(DateTime.now()), labelStyle, valueStyle),
                pw.SizedBox(height: 4),
                _buildPdfRow('Duration:', '$_months month${_months == 1 ? '' : 's'}', labelStyle, valueStyle),
                pw.SizedBox(height: 4),
                _buildPdfRow('Int/Month:', _formatCurrency(_interestPerMonth!), labelStyle, valueStyle),
                
                pw.SizedBox(height: 8),
                pw.Container(
                  width: double.infinity,
                  child: pw.Divider(thickness: 1),
                ),
                pw.SizedBox(height: 8),
                
                // Totals Section - Larger fonts
                pw.Text('TOTAL INTEREST', style: headerStyle),
                pw.SizedBox(height: 4),
                pw.Text(_formatCurrency(_totalInterest!), style: totalStyle),
                pw.SizedBox(height: 12),
                pw.Text('TOTAL AMOUNT', style: headerStyle),
                pw.SizedBox(height: 4),
                pw.Text(_formatCurrency(_totalAmount!), style: totalStyle),
                
                pw.SizedBox(height: 12),
                pw.Container(
                  width: double.infinity,
                  child: pw.Divider(thickness: 1),
                ),
                pw.SizedBox(height: 8),
                
                // Footer
                pw.Text(
                  'Generated: ${_formatDate(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            );
          },
        ),
      );
      // Note: pw.Page with roll format naturally sizes to content

      // Generate readable filename with date
      final dateStr = _formatDate(DateTime.now()).replaceAll('/', '-');
      
      // Use Printing.layoutPdf which supports both printing and PDF save
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Interest_Receipt_$dateStr',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating receipt: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Helper to build PDF row with label and value
  pw.Widget _buildPdfRow(String label, String value, pw.TextStyle labelStyle, pw.TextStyle valueStyle) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: labelStyle),
        pw.Text(value, style: valueStyle),
      ],
    );
  }

  Future<void> _pickExcelFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: false,
      );
      
      if (result != null && result.files.single.path != null) {
        setState(() {
          _excelFilePath = result.files.single.path!;
          _settingsExcelPathController.text = _excelFilePath;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSettingsDialog() {
    // Update controller with current value before showing dialog
    _updateSettingsControllers();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
              const SizedBox(height: 24),
              const Text('Excel File Settings',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Excel File Path',
                  border: OutlineInputBorder(),
                  hintText: 'Select an Excel file',
                  prefixIcon: Icon(Icons.file_present),
                ),
                readOnly: true,
                controller: _settingsExcelPathController,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _pickExcelFile();
                  },
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Browse Excel File'),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Select an Excel file (.xlsx or .xls) from your device. Leave empty to use the bundled file.',
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
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('Reset to Default'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Update values from controllers before saving
              _excelFilePath = _settingsExcelPathController.text.trim();
              await _saveBaseValues();
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              // Check if widget is still mounted before using context
              if (!mounted) return;
              // Reload loan ledger with new Excel file path
              _loadLoanLedger();
              // Recalculate with the new interest rate
              _tryCalculateInterest();
              // Show green success snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings saved successfully'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
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
              // Loan Number Input with Search
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _loanNumberController,
                      decoration: InputDecoration(
                        labelText: 'Loan Number',
                        border: const OutlineInputBorder(),
                        hintText: 'Enter loan number to search',
                        errorText: _loanLookupError,
                        suffixIcon: _isLedgerLoaded 
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : const Icon(Icons.warning, color: Colors.orange),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onFieldSubmitted: (_) => _lookupLoan(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLedgerLoaded ? _lookupLoan : null,
                      child: const Text('Search'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Loan Amount Input (can be edited manually or populated via lookup)
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
                onChanged: (_) => _tryCalculateInterest(),
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
                const SizedBox(height: 16),
                // Print Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _printReceipt,
                    icon: const Icon(Icons.print, size: 28),
                    label: const Text(
                      'Print',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 18 : 14,
              fontWeight: FontWeight.bold,
              color: highlightColor,
            ),
          ),
        ],
      ),
    );
  }
}
