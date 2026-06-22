class PredictionResult {
  /// -1 = uncertain/borderline (no diagnosis), 0 = Normal, 1 = Glaucoma
  final int predictedClass;
  final double confidenceScore;
  final double uncertainty;
  final String riskStatus;

  /// 'very_high' | 'high' | 'moderate' | 'low' | 'borderline' | 'uncertain'
  final String confidenceLevel;

  /// Human-readable label shown in the confidence badge
  final String confidenceLabel;

  /// Clinical recommendation text shown below the badge
  final String confidenceAction;

  /// False when the model is uncertain or borderline — UI must NOT show
  /// a Normal/Glaucoma diagnosis in this case.
  final bool showDiagnosis;

  final String? auditId;
  final String disclaimer;
  final String? warning;

  PredictionResult({
    required this.predictedClass,
    required this.confidenceScore,
    this.uncertainty = 0.0,
    required this.riskStatus,
    this.confidenceLevel = 'moderate',
    this.confidenceLabel = 'Moderate Confidence',
    this.confidenceAction = 'Clinical review recommended.',
    this.showDiagnosis = true,
    this.auditId,
    this.disclaimer =
        'FOR RESEARCH AND SCREENING USE ONLY. NOT A MEDICAL DIAGNOSIS.',
    this.warning,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      predictedClass: json['predicted_class'] ?? 0,
      confidenceScore: (json['confidence_score'] ?? 0.0).toDouble(),
      uncertainty: (json['uncertainty'] ?? 0.0).toDouble(),
      riskStatus: json['risk_status'] ?? 'Unknown',
      confidenceLevel: json['confidence_level'] ?? 'moderate',
      confidenceLabel: json['confidence_label'] ?? 'Moderate Confidence',
      confidenceAction:
          json['confidence_action'] ?? 'Clinical review recommended.',
      showDiagnosis: json['show_diagnosis'] ?? true,
      auditId: json['audit_id'],
      disclaimer: json['disclaimer'] ??
          'FOR RESEARCH AND SCREENING USE ONLY. NOT A MEDICAL DIAGNOSIS.',
      warning: json['warning'],
    );
  }
}
