/// Where each exercise lives in the user's own copy of the book.
///
/// This is an *index* — page numbers and nothing else. The pages themselves
/// come from the PDF the user imports from their own copy; the app ships no
/// notation and never will.
///
/// The scanned edition places two book pages on each PDF page, so the two are
/// not interchangeable and both are recorded here: [bookPage] is what is
/// printed on the paper, [pdfPageFor] is where to find it in the file.
library;

/// Book pages per page of the scanned PDF.
const int kBookPagesPerPdfPage = 2;

/// Book page numbers, read from the headings of the scanned edition.
///
/// Derived by indexing the section headings rather than transcribing anything.
/// A few are approximate where an example starts mid-page — the viewer lets
/// you step a page either way, which is the practical answer to being one out.
const Map<String, int> kExerciseBookPages = {
  'ex_1': 2,
  'ex_2': 3,
  'ex_3': 4,
  'ex_4': 5,
  'ex_5': 9,
  'ex_6': 10,
  'ex_7': 10,
  'ex_8': 11,
  'ex_9': 12,
  'ex_10': 14,
  'ex_11': 17,
  'ex_12': 21,
  'ex_13': 23,
  'ex_14': 26,
  'ex_15': 28,
  'ex_16': 29,
  'ex_17': 33,
  'ex_18': 36,
  'ex_19': 37,
  'ex_20': 39,
  'ex_21': 41,
  'ex_22': 43,
  'ex_23': 44,
  'ex_24': 45,
  'ex_25': 47,
  'ex_26': 47,
  'ex_27': 48,
  'ex_28': 48,
  'ex_29': 48,
  'ex_30': 49,
  'ex_31': 51,
};

/// Fragments of Example 11 run across several pages; the index points at the
/// page each group starts on so a scheduled fragment opens near itself rather
/// than at the start of the example.
const Map<String, int> kVariantBookPages = {
  'ex_11_frag_01': 17,
  'ex_11_frag_02': 17,
  'ex_11_frag_03': 17,
  'ex_11_frag_04': 17,
  'ex_11_frag_05': 17,
  'ex_11_frag_06': 17,
  'ex_11_frag_07': 18,
  'ex_11_frag_08': 18,
  'ex_11_frag_09': 18,
  'ex_11_frag_10': 18,
  'ex_11_frag_11': 18,
  'ex_11_frag_12': 18,
  'ex_11_frag_13': 19,
  'ex_11_frag_14': 19,
  'ex_11_frag_15': 19,
  'ex_11_frag_16': 19,
  'ex_11_frag_17': 20,
  'ex_11_frag_18': 20,
  'ex_11_dev_1': 20,
  'ex_11_dev_2': 20,
  'ex_11_dev_3': 21,
  'ex_11_dev_4': 21,
};

/// The lowest and highest book page this edition covers.
const int kFirstBookPage = 2;
const int kLastBookPage = 53;

/// The page of the scanned PDF that carries [bookPage].
///
/// Two book pages share one scan, so page 4 and page 5 are both on PDF page 3.
int pdfPageFor(int bookPage) => (bookPage ~/ kBookPagesPerPdfPage) + 1;

/// Where to open for an exercise, preferring the variant's own page.
int? bookPageFor(String exerciseId, [String? variantId]) {
  if (variantId != null) {
    final variantPage = kVariantBookPages[variantId];
    if (variantPage != null) return variantPage;
  }
  return kExerciseBookPages[exerciseId];
}

/// Whether this edition contains the exercise at all. The scanned tab section
/// stops at Example 31, so anything past it has no page to open.
bool isInScannedEdition(String exerciseId) =>
    kExerciseBookPages.containsKey(exerciseId);
