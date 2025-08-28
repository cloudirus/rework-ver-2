import 'package:flutter/material.dart';

class SnellenChartWidget extends StatelessWidget {
  final int currentLine;
  final String currentLetter;
  final Function(String) onLetterSelected;

  const SnellenChartWidget({
    super.key,
    required this.currentLine,
    required this.currentLetter,
    required this.onLetterSelected,
  });

  static const List<List<String>> _snellenChart = [
    ['E'], // 20/200
    ['F', 'P'], // 20/100
    ['T', 'O', 'Z'], // 20/70
    ['L', 'P', 'E', 'D'], // 20/50
    ['P', 'E', 'C', 'F', 'D'], // 20/40
    ['E', 'D', 'F', 'C', 'Z', 'P'], // 20/30
    ['F', 'E', 'L', 'O', 'P', 'Z', 'D'], // 20/25
    ['D', 'E', 'F', 'P', 'O', 'T', 'E', 'C'], // 20/20
  ];

  static const List<String> _visionLevels = [
    '20/200', '20/100', '20/70', '20/50', 
    '20/40', '20/30', '20/25', '20/20'
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Line ${currentLine + 1}/8 (${_visionLevels[currentLine]})',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 24),
        
        Container(
          width: 250,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              currentLetter,
              style: TextStyle(
                fontSize: _getLetterSize(currentLine),
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontFamily: 'Courier',
              ),
            ),
          ),
        ),
        // const SizedBox(height: 8),
        // // 👇 Debug text for current letter size
        // Text(
        //   'Size: ${_getLetterSize(currentLine).toStringAsFixed(1)}',
        //   style: const TextStyle(
        //     fontSize: 12,
        //     color: Colors.grey,
        //   ),
        // ),
        const SizedBox(height: 24),
        
        const Text(
          'Select the letter you see:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _getAllLetters().map((letter) {
            return SizedBox(
              width: 50,
              height: 50,
              child: ElevatedButton(
                onPressed: () => onLetterSelected(letter),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  side: BorderSide(color: Colors.blue.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  letter,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  double _getLetterSize(int line) {
    print("Getting letter size");
    // Approximate mapping of Snellen chart sizes (in logical pixels)
    const List<double> sizes = [
      57, // 20/200 (largest)
      29, // 20/100
      20, // 20/70
      15, // 20/50
      11, // 20/40
      9,  // 20/30
      7,  // 20/25
      6,  // 20/20 (smallest)
    ];
    print('Line: $line, Size: ${sizes[line]}');
    return sizes[line];
  }

  List<String> _getAllLetters() {
    return _snellenChart.expand((line) => line).toSet().toList()..sort();
  }
}