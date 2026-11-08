import '../l10n/l10n.dart';

// Recovered public learning assets from the inaccessible Cloudinary account.
String contentMediaUrl(String url) => _recoveredMedia[url] ?? url;

const _recoveredMedia = <String, String>{
  'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783509989/Module1_Introduction_Definition_of_Waste.pdf':
      'https://res.cloudinary.com/zkebg27g/image/upload/v1794122667/Module1_Introduction_Definition_of_Waste.pdf',
  'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783572651/Module1_Introduction_Definition_of_Waste_eg2e0e.png':
      'https://res.cloudinary.com/zkebg27g/image/upload/v1794122668/Module1_Introduction_Definition_of_Waste_eg2e0e.png',
  'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783509989/Module2_Categories_of_Organic_Waste_cb4tbs.pdf':
      'https://res.cloudinary.com/zkebg27g/image/upload/v1794122669/Module2_Categories_of_Organic_Waste_cb4tbs.pdf',
  'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783572651/Module2_Categories_of_Organic_Waste_cox1on.png':
      'https://res.cloudinary.com/zkebg27g/image/upload/v1794122670/Module2_Categories_of_Organic_Waste_cox1on.png',
  'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783509989/Module3_Categories_of_Inorganic_Waste_plebtk.pdf':
      'https://res.cloudinary.com/zkebg27g/image/upload/v1794122670/Module3_Categories_of_Inorganic_Waste_plebtk.pdf',
  'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783572652/Module3_Categories_of_Inorganic_Waste_z6bpmw.png':
      'https://res.cloudinary.com/zkebg27g/image/upload/v1794122672/Module3_Categories_of_Inorganic_Waste_z6bpmw.png',
  'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783509989/Module4_Biodegradable_vs_NonBiodegradable_xqivuz.pdf':
      'https://res.cloudinary.com/zkebg27g/image/upload/v1794122672/Module4_Biodegradable_vs_NonBiodegradable_xqivuz.pdf',
  'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783572652/Module4_Biodegradable_vs_NonBiodegradable_jy0wjd.png':
      'https://res.cloudinary.com/zkebg27g/image/upload/v1794122673/Module4_Biodegradable_vs_NonBiodegradable_jy0wjd.png',
  'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783510217/composting_biogas_kcmsws.png':
      'https://res.cloudinary.com/zkebg27g/image/upload/v1794122674/composting_biogas_kcmsws.png',
  'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783510221/composting_fundamentals_ytultz.png':
      'https://res.cloudinary.com/zkebg27g/image/upload/v1794122675/composting_fundamentals_ytultz.png',
  'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783510216/introduction_waste_management_uekl0h.png':
      'https://res.cloudinary.com/zkebg27g/image/upload/v1794122676/introduction_waste_management_uekl0h.png',
  'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783510221/hazardous_characteristics_nc5d7x.png':
      'https://res.cloudinary.com/zkebg27g/image/upload/v1794122677/hazardous_characteristics_nc5d7x.png',
  'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783510222/hazardous_intro_gbcrps.png':
      'https://res.cloudinary.com/zkebg27g/image/upload/v1794122678/hazardous_intro_gbcrps.png',
  'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783510220/hazardous_safe_handling_vsgd7z.png':
      'https://res.cloudinary.com/zkebg27g/image/upload/v1794122679/hazardous_safe_handling_vsgd7z.png',
  'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783576395/Inorganic_waste_management_uu8lxh.jpg':
      'https://res.cloudinary.com/zkebg27g/image/upload/v1794122680/Inorganic_waste_management_uu8lxh.jpg',
  'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783510215/organic_intro_ayp7ec.png':
      'https://res.cloudinary.com/zkebg27g/image/upload/v1794122681/organic_intro_ayp7ec.png',
  'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783510220/recyclable_waste_az24ed.png':
      'https://res.cloudinary.com/zkebg27g/image/upload/v1794122681/recyclable_waste_az24ed.png',
  'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783510216/reduce_impact_pjgjvl.png':
      'https://res.cloudinary.com/zkebg27g/image/upload/v1794122682/reduce_impact_pjgjvl.png',
  'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783510217/reuse_creative_solutions_s5ey13.png':
      'https://res.cloudinary.com/zkebg27g/image/upload/v1794122683/reuse_creative_solutions_s5ey13.png',
};

String guideMediaUrl(String url) =>
    (l10n.localeName == 'id' ? _indonesianGuides[url] : null) ??
    contentMediaUrl(url);

const _indonesianGuides = <String, String>{
  'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783509989/Module1_Introduction_Definition_of_Waste.pdf':
      'https://res.cloudinary.com/zkebg27g/image/upload/v1794123504/Module1_Introduction_Definition_of_Waste_id.pdf',
  'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783509989/Module2_Categories_of_Organic_Waste_cb4tbs.pdf':
      'https://res.cloudinary.com/zkebg27g/image/upload/v1794123505/Module2_Categories_of_Organic_Waste_cb4tbs_id.pdf',
  'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783509989/Module3_Categories_of_Inorganic_Waste_plebtk.pdf':
      'https://res.cloudinary.com/zkebg27g/image/upload/v1794123506/Module3_Categories_of_Inorganic_Waste_plebtk_id.pdf',
  'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783509989/Module4_Biodegradable_vs_NonBiodegradable_xqivuz.pdf':
      'https://res.cloudinary.com/zkebg27g/image/upload/v1794123507/Module4_Biodegradable_vs_NonBiodegradable_xqivuz_id.pdf',
};

// Original published guides have no i18n fields; translated Firestore text still wins.
String guideContentText(String value) =>
    l10n.localeName == 'id' ? (_guideTextId[value] ?? value) : value;

const _guideTextId = <String, String>{
  'Introduction & Definitions of Waste': 'Pengantar dan Definisi Sampah',
  'Categories of Organic Waste': 'Kategori Sampah Organik',
  'Categories of Inorganic Waste': 'Kategori Sampah Anorganik',
  'Biodegradable vs. Non-Biodegradable Properties':
      'Sifat Biodegradabel dan Non-Biodegradabel',
  'Foundational principles of physical waste streams and sorting logic.':
      'Prinsip dasar aliran fisik sampah dan logika pemilahan.',
  'Learn the types and characteristics of organic waste.':
      'Pelajari jenis dan karakteristik sampah organik.',
  'Learn the types and characteristics of inorganic waste.':
      'Pelajari jenis dan karakteristik sampah anorganik.',
  'Compare biodegradable and non-biodegradable waste properties.':
      'Bandingkan sifat sampah biodegradabel dan non-biodegradabel.',
  'Module 1: Waste Classification & Identification':
      'Modul 1: Klasifikasi dan Identifikasi Sampah',
  'Module 2: Inorganic / Recyclable Waste':
      'Modul 2: Sampah Anorganik / Dapat Didaur Ulang',
};
