class GesSubjectCatalogItem {
  final String name;
  final String code;
  final bool isCore;
  final String description;

  const GesSubjectCatalogItem({
    required this.name,
    required this.code,
    required this.isCore,
    required this.description,
  });
}

/// Ghana subject catalog (seed data).
///
/// Notes:
/// - KG/Primary/JHS subject structure is based on NaCCA (Standards-Based Curriculum / CCP).
/// - SHS core vs electives is based on WAEC WASSCE subject groupings.
/// - "Subject codes" here are app-internal stable IDs (since public official code lists are
///   not consistently published in a machine-friendly way).
class GesSubjectCatalog {
  static const List<GesSubjectCatalogItem> items = [
    // Kindergarten (NaCCA KG curriculum learning areas)
    GesSubjectCatalogItem(
      name: 'Language and Literacy',
      code: 'kg.language_literacy',
      isCore: true,
      description: 'KG learning area (NaCCA).',
    ),
    GesSubjectCatalogItem(
      name: 'Numeracy',
      code: 'kg.numeracy',
      isCore: true,
      description: 'KG learning area (NaCCA).',
    ),
    GesSubjectCatalogItem(
      name: 'Our World Our People',
      code: 'kg.owop',
      isCore: true,
      description: 'KG learning area (NaCCA).',
    ),
    GesSubjectCatalogItem(
      name: 'Creative Arts',
      code: 'kg.creative_arts',
      isCore: true,
      description: 'KG learning area (NaCCA).',
    ),

    // Primary (NaCCA Standards-Based Curriculum learning areas/subjects)
    GesSubjectCatalogItem(
      name: 'English Language',
      code: 'be.english_language',
      isCore: true,
      description: 'Primary/JHS core (NaCCA).',
    ),
    GesSubjectCatalogItem(
      name: 'Mathematics',
      code: 'be.mathematics',
      isCore: true,
      description: 'Primary/JHS core (NaCCA).',
    ),
    GesSubjectCatalogItem(
      name: 'Science',
      code: 'be.science',
      isCore: true,
      description: 'Primary/JHS core (NaCCA).',
    ),
    GesSubjectCatalogItem(
      name: 'Ghanaian Language',
      code: 'be.ghanaian_language',
      isCore: true,
      description: 'Primary/JHS core (NaCCA).',
    ),
    GesSubjectCatalogItem(
      name: 'History',
      code: 'be.history',
      isCore: true,
      description: 'Primary learning area/subject (NaCCA).',
    ),
    GesSubjectCatalogItem(
      name: 'Our World Our People',
      code: 'be.owop',
      isCore: true,
      description: 'Primary learning area/subject (NaCCA).',
    ),
    GesSubjectCatalogItem(
      name: 'Creative Arts',
      code: 'be.creative_arts',
      isCore: true,
      description: 'Primary learning area/subject (NaCCA).',
    ),
    GesSubjectCatalogItem(
      name: 'Religious and Moral Education',
      code: 'be.rme',
      isCore: true,
      description: 'Primary/JHS core (NaCCA).',
    ),
    GesSubjectCatalogItem(
      name: 'Physical Education',
      code: 'be.physical_education',
      isCore: true,
      description: 'Primary learning area/subject (NaCCA).',
    ),
    GesSubjectCatalogItem(
      name: 'Computing',
      code: 'be.computing',
      isCore: true,
      description: 'Primary/JHS learning area/subject (NaCCA).',
    ),
    GesSubjectCatalogItem(
      name: 'French',
      code: 'be.french',
      isCore: false,
      description: 'Often offered as an optional/second language (NaCCA).',
    ),

    // JHS (Common Core Programme)
    GesSubjectCatalogItem(
      name: 'Social Studies',
      code: 'jhs.social_studies',
      isCore: true,
      description: 'JHS core (NaCCA CCP).',
    ),
    GesSubjectCatalogItem(
      name: 'Creative Arts and Design',
      code: 'jhs.creative_arts_design',
      isCore: true,
      description: 'JHS learning area/subject (NaCCA CCP).',
    ),
    GesSubjectCatalogItem(
      name: 'Career Technology',
      code: 'jhs.career_technology',
      isCore: true,
      description: 'JHS learning area/subject (NaCCA CCP).',
    ),
    GesSubjectCatalogItem(
      name: 'Physical and Health Education',
      code: 'jhs.physical_health_education',
      isCore: true,
      description: 'JHS learning area/subject (NaCCA CCP).',
    ),
    GesSubjectCatalogItem(
      name: 'Arabic',
      code: 'be.arabic',
      isCore: false,
      description: 'Optional subject where offered.',
    ),

    // SHS (WAEC WASSCE – subject offerings)
    GesSubjectCatalogItem(
      name: 'English Language',
      code: 'shs.core.english_language',
      isCore: true,
      description: 'SHS core (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Integrated Science',
      code: 'shs.core.integrated_science',
      isCore: true,
      description: 'SHS core (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Mathematics (Core)',
      code: 'shs.core.mathematics',
      isCore: true,
      description: 'SHS core (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Social Studies',
      code: 'shs.core.social_studies',
      isCore: true,
      description: 'SHS core (WAEC WASSCE).',
    ),

    // SHS electives (selected common electives across programmes/options)
    GesSubjectCatalogItem(
      name: 'Mathematics (Elective)',
      code: 'shs.elective.mathematics',
      isCore: false,
      description: 'SHS elective (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Biology',
      code: 'shs.elective.biology',
      isCore: false,
      description: 'SHS elective (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Chemistry',
      code: 'shs.elective.chemistry',
      isCore: false,
      description: 'SHS elective (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Physics',
      code: 'shs.elective.physics',
      isCore: false,
      description: 'SHS elective (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Economics',
      code: 'shs.elective.economics',
      isCore: false,
      description: 'SHS elective (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Government',
      code: 'shs.elective.government',
      isCore: false,
      description: 'SHS elective (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Geography',
      code: 'shs.elective.geography',
      isCore: false,
      description: 'SHS elective (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'History',
      code: 'shs.elective.history',
      isCore: false,
      description: 'SHS elective (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Literature in English',
      code: 'shs.elective.literature_english',
      isCore: false,
      description: 'SHS elective (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'French',
      code: 'shs.elective.french',
      isCore: false,
      description: 'SHS elective (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'ICT (Elective)',
      code: 'shs.elective.ict',
      isCore: false,
      description: 'SHS elective (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Financial Accounting',
      code: 'shs.elective.financial_accounting',
      isCore: false,
      description: 'SHS elective (Business) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Cost Accounting',
      code: 'shs.elective.cost_accounting',
      isCore: false,
      description: 'SHS elective (Business) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Business Management',
      code: 'shs.elective.business_management',
      isCore: false,
      description: 'SHS elective (Business) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Management in Living',
      code: 'shs.elective.management_in_living',
      isCore: false,
      description: 'SHS elective (Home Economics) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Foods and Nutrition',
      code: 'shs.elective.foods_nutrition',
      isCore: false,
      description: 'SHS elective (Home Economics) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Clothing and Textiles',
      code: 'shs.elective.clothing_textiles',
      isCore: false,
      description: 'SHS elective (Home Economics) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'General Knowledge in Art',
      code: 'shs.elective.gka',
      isCore: false,
      description: 'SHS elective (Visual Arts) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Graphic Design',
      code: 'shs.elective.graphic_design',
      isCore: false,
      description: 'SHS elective (Visual Arts) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Picture Making',
      code: 'shs.elective.picture_making',
      isCore: false,
      description: 'SHS elective (Visual Arts) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Technical Drawing',
      code: 'shs.elective.technical_drawing',
      isCore: false,
      description: 'SHS elective (Technical) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Applied Electricity',
      code: 'shs.elective.applied_electricity',
      isCore: false,
      description: 'SHS elective (Technical) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Electronics',
      code: 'shs.elective.electronics',
      isCore: false,
      description: 'SHS elective (Technical) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Auto Mechanics',
      code: 'shs.elective.auto_mechanics',
      isCore: false,
      description: 'SHS elective (Technical) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Building Construction',
      code: 'shs.elective.building_construction',
      isCore: false,
      description: 'SHS elective (Technical) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Woodwork',
      code: 'shs.elective.woodwork',
      isCore: false,
      description: 'SHS elective (Technical) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Metalwork',
      code: 'shs.elective.metalwork',
      isCore: false,
      description: 'SHS elective (Technical) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Animal Husbandry',
      code: 'shs.elective.animal_husbandry',
      isCore: false,
      description: 'SHS elective (Agric) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Crop Husbandry and Horticulture',
      code: 'shs.elective.crop_husbandry_horticulture',
      isCore: false,
      description: 'SHS elective (Agric) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Fisheries',
      code: 'shs.elective.fisheries',
      isCore: false,
      description: 'SHS elective (Agric) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Forestry',
      code: 'shs.elective.forestry',
      isCore: false,
      description: 'SHS elective (Agric) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Christian Religious Studies',
      code: 'shs.elective.crs',
      isCore: false,
      description: 'SHS elective (General Arts) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Islamic Religious Studies',
      code: 'shs.elective.irs',
      isCore: false,
      description: 'SHS elective (General Arts) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'West African Traditional Religion',
      code: 'shs.elective.watr',
      isCore: false,
      description: 'SHS elective (General Arts) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Arabic',
      code: 'shs.elective.arabic',
      isCore: false,
      description: 'SHS elective (General Arts) (WAEC WASSCE).',
    ),
    GesSubjectCatalogItem(
      name: 'Music',
      code: 'shs.elective.music',
      isCore: false,
      description: 'SHS elective (WAEC WASSCE).',
    ),
  ];
}
