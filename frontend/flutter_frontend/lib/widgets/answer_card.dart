import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnswerCard extends StatelessWidget {
  final String question;
  final String answer;
  final List<String> keyPoints;

  const AnswerCard({
    super.key,
    required this.question,
    required this.answer,
    required this.keyPoints,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Header - simplified
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.question_mark, size: 20, color: const Color(0xFF4CAF50)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    question,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Answer Content - simplified
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: _formatAnswerText(answer),
          ),
          
          // Key Points - simplified
          if (keyPoints.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Key Points',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...keyPoints.map((point) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: const Color(0xFF4CAF50), fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            point,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF666666),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Simplified text formatting
  Widget _formatAnswerText(String text) {
    // Split text into paragraphs
    List<String> paragraphs = text.split('\n\n');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((paragraph) {
        paragraph = paragraph.trim();
        if (paragraph.isEmpty) return const SizedBox.shrink();
        
        // Check if paragraph starts with a colon (indicating a section header)
        if (paragraph.contains(':')) {
          List<String> parts = paragraph.split(':');
          if (parts.length >= 2) {
            String header = parts[0].trim();
            String content = parts.sublist(1).join(':').trim();
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    header,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF555555),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            );
          }
        }
        
        // Regular paragraph
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            paragraph,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF555555),
              height: 1.5,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// Example usage widget for testing
class AnswerCardExample extends StatelessWidget {
  const AnswerCardExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Answer Card Example'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: AnswerCard(
          question: "How to grow mangoes in containers?",
          answer: "Choose the right variety: Select dwarf mango varieties suitable for container growing like 'Nam Doc Mai' or 'Cogshall'.\n\nLots of light: Mangoes need lots of light, ideally 6-8 hours of direct sunlight daily, preferably from a south-facing window.\n\nTemperature control: Maintain consistent warm temperatures, avoid drafts and cold spots.\n\nHumidity: Mangoes love humidity. Use a humidifier, regular misting, or place the pot on a tray with pebbles and water.\n\nSoil and drainage: Use well-draining potting mix formulated for fruit trees, or a mix of potting soil, perlite, and vermiculite.",
          keyPoints: [
            "Choose dwarf varieties for containers",
            "Provide 6-8 hours of direct sunlight",
            "Maintain warm, consistent temperatures",
            "Keep humidity levels high",
            "Use well-draining soil mix"
          ],
        ),
      ),
    );
  }
} 