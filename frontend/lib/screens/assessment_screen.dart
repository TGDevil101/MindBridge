import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'results_screen.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key});

  static const routeName = '/assessment';

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  final _api = ApiService();
  String _assessmentType = 'anxiety';
  int _questionCount = 7;
  bool _isSubmitting = false;
  List<int> _answers = List<int>.filled(7, 0);

  void _configureByType(String type) {
    setState(() {
      _assessmentType = type;
      if (type == 'anxiety') {
        _questionCount = 7;
        _answers = List<int>.filled(7, 0);
      } else if (type == 'depression') {
        _questionCount = 9;
        _answers = List<int>.filled(9, 0);
      } else if (type == 'stress') {
        _questionCount = 10;
        _answers = List<int>.filled(10, 0);
      } else if (type == 'adhd') {
        _questionCount = 6;
        _answers = List<int>.filled(6, 0);
      } else {
        _questionCount = 3;
        _answers = List<int>.filled(3, 1);
      }
    });
  }

  int _maxValue() {
    if (_assessmentType == 'stress') return 4;
    if (_assessmentType == 'loneliness') return 3;
    return _assessmentType == 'adhd' ? 1 : 3;
  }

  int _minValue() => _assessmentType == 'loneliness' ? 1 : 0;

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final result = await _api.assess(
        assessmentType: _assessmentType,
        answers: _answers,
      );
      if (!mounted) return;
      Navigator.pushNamed(context, ResultsScreen.routeName, arguments: result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assessment')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _assessmentType,
              items: const [
                DropdownMenuItem(value: 'anxiety', child: Text('Anxiety (GAD-7)')),
                DropdownMenuItem(value: 'depression', child: Text('Depression (PHQ-9)')),
                DropdownMenuItem(value: 'stress', child: Text('Stress (PSS-10)')),
                DropdownMenuItem(value: 'adhd', child: Text('ADHD (ASRS v1.1 Part A)')),
                DropdownMenuItem(value: 'loneliness', child: Text('Loneliness (UCLA-3)')),
              ],
              onChanged: (v) => _configureByType(v ?? 'anxiety'),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _questionCount,
                itemBuilder: (context, i) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Question ${i + 1}'),
                          Slider(
                            min: _minValue().toDouble(),
                            max: _maxValue().toDouble(),
                            divisions: _maxValue() - _minValue(),
                            value: _answers[i].toDouble(),
                            label: _answers[i].toString(),
                            onChanged: (value) {
                              setState(() {
                                _answers[i] = value.toInt();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : const Text('Submit Assessment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
