import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'results_screen.dart';

// ---------------------------------------------------------------------------
// Question data for all 5 clinical tools
// ---------------------------------------------------------------------------

class _Question {
  const _Question(this.text, this.scaleLabels);
  final String text;
  final List<String> scaleLabels; // index 0 = lowest value label
}

class _AssessmentConfig {
  const _AssessmentConfig({
    required this.label,
    required this.instruction,
    required this.questions,
    required this.minValue,
    required this.maxValue,
  });
  final String label;
  final String instruction;
  final List<_Question> questions;
  final int minValue;
  final int maxValue;
}

const _gad7Config = _AssessmentConfig(
  label: 'Anxiety (GAD-7)',
  instruction:
      'Over the last 2 weeks, how often have you been bothered by the following?',
  minValue: 0,
  maxValue: 3,
  questions: [
    _Question('Feeling nervous, anxious, or on edge',
        ['Not at all', 'Several days', 'More than half the days', 'Nearly every day']),
    _Question('Not being able to stop or control worrying',
        ['Not at all', 'Several days', 'More than half the days', 'Nearly every day']),
    _Question('Worrying too much about different things',
        ['Not at all', 'Several days', 'More than half the days', 'Nearly every day']),
    _Question('Trouble relaxing',
        ['Not at all', 'Several days', 'More than half the days', 'Nearly every day']),
    _Question('Being so restless that it is hard to sit still',
        ['Not at all', 'Several days', 'More than half the days', 'Nearly every day']),
    _Question('Becoming easily annoyed or irritable',
        ['Not at all', 'Several days', 'More than half the days', 'Nearly every day']),
    _Question('Feeling afraid, as if something awful might happen',
        ['Not at all', 'Several days', 'More than half the days', 'Nearly every day']),
  ],
);

const _phq9Config = _AssessmentConfig(
  label: 'Depression (PHQ-9)',
  instruction:
      'Over the last 2 weeks, how often have you been bothered by the following?',
  minValue: 0,
  maxValue: 3,
  questions: [
    _Question('Little interest or pleasure in doing things',
        ['Not at all', 'Several days', 'More than half the days', 'Nearly every day']),
    _Question('Feeling down, depressed, or hopeless',
        ['Not at all', 'Several days', 'More than half the days', 'Nearly every day']),
    _Question('Trouble falling or staying asleep, or sleeping too much',
        ['Not at all', 'Several days', 'More than half the days', 'Nearly every day']),
    _Question('Feeling tired or having little energy',
        ['Not at all', 'Several days', 'More than half the days', 'Nearly every day']),
    _Question('Poor appetite or overeating',
        ['Not at all', 'Several days', 'More than half the days', 'Nearly every day']),
    _Question(
        'Feeling bad about yourself — or that you are a failure or have let yourself or your family down',
        ['Not at all', 'Several days', 'More than half the days', 'Nearly every day']),
    _Question(
        'Trouble concentrating on things, such as reading or watching television',
        ['Not at all', 'Several days', 'More than half the days', 'Nearly every day']),
    _Question(
        'Moving or speaking so slowly that other people could have noticed, or the opposite — being so fidgety or restless that you have been moving around more than usual',
        ['Not at all', 'Several days', 'More than half the days', 'Nearly every day']),
    _Question(
        'Thoughts that you would be better off dead, or of hurting yourself in some way',
        ['Not at all', 'Several days', 'More than half the days', 'Nearly every day']),
  ],
);

const _pss10Config = _AssessmentConfig(
  label: 'Stress (PSS-10)',
  instruction:
      'In the last month, how often have you felt or thought the following?',
  minValue: 0,
  maxValue: 4,
  questions: [
    _Question('Been upset because of something that happened unexpectedly',
        ['Never', 'Almost never', 'Sometimes', 'Fairly often', 'Very often']),
    _Question('Felt that you were unable to control the important things in your life',
        ['Never', 'Almost never', 'Sometimes', 'Fairly often', 'Very often']),
    _Question('Felt nervous and stressed',
        ['Never', 'Almost never', 'Sometimes', 'Fairly often', 'Very often']),
    _Question('Felt confident about your ability to handle your personal problems',
        ['Never', 'Almost never', 'Sometimes', 'Fairly often', 'Very often']),
    _Question('Felt that things were going your way',
        ['Never', 'Almost never', 'Sometimes', 'Fairly often', 'Very often']),
    _Question('Found that you could not cope with all the things you had to do',
        ['Never', 'Almost never', 'Sometimes', 'Fairly often', 'Very often']),
    _Question('Been able to control irritations in your life',
        ['Never', 'Almost never', 'Sometimes', 'Fairly often', 'Very often']),
    _Question('Felt that you were on top of things',
        ['Never', 'Almost never', 'Sometimes', 'Fairly often', 'Very often']),
    _Question('Been angered because of things that happened that were outside of your control',
        ['Never', 'Almost never', 'Sometimes', 'Fairly often', 'Very often']),
    _Question('Felt difficulties were piling up so high that you could not overcome them',
        ['Never', 'Almost never', 'Sometimes', 'Fairly often', 'Very often']),
  ],
);

const _asrsConfig = _AssessmentConfig(
  label: 'ADHD (ASRS v1.1 Part A)',
  instruction:
      'Over the past 6 months, how often have you experienced the following? Answer Never (0) or Sometimes/Often (1).',
  minValue: 0,
  maxValue: 1,
  questions: [
    _Question('How often do you have trouble wrapping up the final details of a project, once the challenging parts have been done?',
        ['Never / Rarely', 'Sometimes / Often']),
    _Question('How often do you have difficulty getting things in order when you have to do a task that requires organization?',
        ['Never / Rarely', 'Sometimes / Often']),
    _Question('How often do you have problems remembering appointments or obligations?',
        ['Never / Rarely', 'Sometimes / Often']),
    _Question('When you have a task that requires a lot of thought, how often do you avoid or delay getting started?',
        ['Never / Rarely', 'Sometimes / Often']),
    _Question('How often do you fidget or squirm with your hands or feet when you have to sit down for a long time?',
        ['Never / Rarely', 'Sometimes / Often']),
    _Question('How often do you feel overly active and compelled to do things, like you were driven by a motor?',
        ['Never / Rarely', 'Sometimes / Often']),
  ],
);

const _uclaConfig = _AssessmentConfig(
  label: 'Loneliness (UCLA-3)',
  instruction: 'How often do you feel the following way?',
  minValue: 1,
  maxValue: 3,
  questions: [
    _Question('How often do you feel that you lack companionship?',
        ['Hardly ever', 'Some of the time', 'Often']),
    _Question('How often do you feel left out?',
        ['Hardly ever', 'Some of the time', 'Often']),
    _Question('How often do you feel isolated from others?',
        ['Hardly ever', 'Some of the time', 'Often']),
  ],
);

const Map<String, _AssessmentConfig> _configs = {
  'anxiety': _gad7Config,
  'depression': _phq9Config,
  'stress': _pss10Config,
  'adhd': _asrsConfig,
  'loneliness': _uclaConfig,
};

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key});

  static const routeName = '/assessment';

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  final _api = ApiService();
  String _assessmentType = 'anxiety';
  bool _isSubmitting = false;

  _AssessmentConfig get _config => _configs[_assessmentType]!;

  late List<int> _answers = _defaultAnswers('anxiety');

  List<int> _defaultAnswers(String type) {
    final config = _configs[type]!;
    return List<int>.filled(config.questions.length, config.minValue);
  }

  void _configureByType(String type) {
    setState(() {
      _assessmentType = type;
      _answers = _defaultAnswers(type);
    });
  }

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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    return Scaffold(
      appBar: AppBar(title: const Text('Self-Assessment')),
      body: Column(
        children: [
          // Tool selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: DropdownButtonFormField<String>(
              value: _assessmentType,
              decoration: const InputDecoration(
                labelText: 'Select assessment',
                border: OutlineInputBorder(),
              ),
              items: _configs.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value.label),
                      ))
                  .toList(),
              onChanged: (v) => _configureByType(v ?? 'anxiety'),
            ),
          ),

          // Instruction text
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              config.instruction,
              style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54),
            ),
          ),

          // Questions list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: config.questions.length,
              itemBuilder: (context, i) {
                final q = config.questions[i];
                final currentVal = _answers[i];
                final labelText = q.scaleLabels[currentVal - config.minValue];

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Question number badge + text
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 10, top: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                q.text,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Current answer label
                        Center(
                          child: Text(
                            labelText,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 13,
                            ),
                          ),
                        ),

                        // Slider
                        Slider(
                          min: config.minValue.toDouble(),
                          max: config.maxValue.toDouble(),
                          divisions: config.maxValue - config.minValue,
                          value: currentVal.toDouble(),
                          onChanged: (value) {
                            setState(() => _answers[i] = value.toInt());
                          },
                        ),

                        // Min / Max labels at ends
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(q.scaleLabels.first,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.black45)),
                            Text(q.scaleLabels.last,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.black45)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Disclaimer + submit
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                const Text(
                  'This is a screening tool, not a diagnosis. Results are for awareness only.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.black45),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit Assessment'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
