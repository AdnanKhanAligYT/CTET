/// Turns an email address's local-part into a best-effort display name
/// suggestion. The result is always meant to be shown on an editable
/// confirmation screen — never saved without the student seeing it first —
/// so an imperfect guess here is an acceptable default, not a failure.
library;

/// How the suggestion was derived, so the UI/analytics can tell a confident
/// guess apart from a weak fallback.
enum NameSuggestionSource { separator, dictionary, fallback }

class NameSuggestion {
  const NameSuggestion(this.name, this.source);

  final String name;
  final NameSuggestionSource source;
}

class NameSuggestionService {
  const NameSuggestionService();

  static final RegExp _trailingDigits = RegExp(r'\d+$');
  static final RegExp _separators = RegExp(r'[._\-]+');
  static final RegExp _anyDigits = RegExp(r'\d+');

  /// Common Indian first names used to split a concatenated local-part like
  /// `mohammadadnan7275` into `Mohammad` + `Adnan`. Not exhaustive by design —
  /// it only needs to catch the common case; anything it misses falls back
  /// to a single-word guess. Sorted longest-first so greedy prefix matching
  /// prefers the longest valid name (e.g. "priyanka" over "priya").
  static const List<String> _commonFirstNames = [
    'mohammad',
    'mohammed',
    'muhammad',
    'abdullah',
    'abdul',
    'ibrahim',
    'ismail',
    'rahman',
    'rasheed',
    'rashid',
    'hamza',
    'usman',
    'imran',
    'irfan',
    'kamran',
    'salman',
    'farhan',
    'faisal',
    'zeeshan',
    'shahid',
    'tariq',
    'waseem',
    'yasin',
    'yusuf',
    'ayaan',
    'adnan',
    'arsalan',
    'sameer',
    'shoaib',
    'junaid',
    'kashif',
    'nadeem',
    'naveed',
    'saif',
    'aamir',
    'aslam',
    'asif',
    'zaid',
    'zoya',
    'aisha',
    'ayesha',
    'fatima',
    'sana',
    'sadia',
    'nazia',
    'rubina',
    'shabana',
    'shazia',
    'tabassum',
    'aditya',
    'abhishek',
    'abhinav',
    'akshay',
    'amit',
    'anand',
    'anil',
    'ankit',
    'ankur',
    'anuj',
    'arjun',
    'arun',
    'ashish',
    'ashok',
    'ashwin',
    'bhavesh',
    'chetan',
    'darshan',
    'deepak',
    'dev',
    'dhruv',
    'gaurav',
    'girish',
    'gopal',
    'harsh',
    'harish',
    'hemant',
    'himanshu',
    'jatin',
    'kapil',
    'karan',
    'karthik',
    'kartik',
    'kaushal',
    'kiran',
    'kishore',
    'kunal',
    'lokesh',
    'mahesh',
    'manish',
    'manoj',
    'mayank',
    'mohan',
    'mukesh',
    'naveen',
    'nikhil',
    'nilesh',
    'nitin',
    'pankaj',
    'parth',
    'pawan',
    'piyush',
    'prakash',
    'pranav',
    'prashant',
    'prateek',
    'praveen',
    'preet',
    'rahul',
    'raj',
    'rajat',
    'rajesh',
    'rajeev',
    'raju',
    'rakesh',
    'ramesh',
    'ranjan',
    'ravi',
    'rishabh',
    'rohan',
    'rohit',
    'sachin',
    'sagar',
    'sanjay',
    'sandeep',
    'sanjeev',
    'santosh',
    'saurabh',
    'shashank',
    'shekhar',
    'shivam',
    'shubham',
    'siddharth',
    'sohan',
    'somesh',
    'sourabh',
    'subhash',
    'sudhir',
    'sumit',
    'sunil',
    'suraj',
    'suresh',
    'tarun',
    'tushar',
    'umesh',
    'utkarsh',
    'varun',
    'vicky',
    'vijay',
    'vikas',
    'vikram',
    'vinay',
    'vinod',
    'vipin',
    'vishal',
    'vivek',
    'yash',
    'yogesh',
    'aarti',
    'aditi',
    'akanksha',
    'alka',
    'amrita',
    'anamika',
    'anita',
    'anjali',
    'ankita',
    'anu',
    'anushka',
    'aparna',
    'archana',
    'arti',
    'asha',
    'babita',
    'bharti',
    'bhavna',
    'bhumika',
    'chitra',
    'deepa',
    'deepika',
    'divya',
    'geeta',
    'gunjan',
    'gayatri',
    'jaya',
    'juhi',
    'jyoti',
    'kajal',
    'kalpana',
    'kanchan',
    'kavita',
    'kavya',
    'komal',
    'kriti',
    'kumkum',
    'lata',
    'madhu',
    'madhuri',
    'mamta',
    'manisha',
    'meena',
    'meera',
    'megha',
    'monika',
    'mansi',
    'namrata',
    'nandini',
    'neelam',
    'neeta',
    'neha',
    'nidhi',
    'nikita',
    'nisha',
    'nishtha',
    'pallavi',
    'pooja',
    'poonam',
    'prachi',
    'pratibha',
    'preeti',
    'priya',
    'priyanka',
    'radha',
    'rani',
    'reena',
    'rekha',
    'renu',
    'richa',
    'ritu',
    'riya',
    'ruchi',
    'sadhana',
    'sakshi',
    'sangeeta',
    'sapna',
    'saroj',
    'seema',
    'shalini',
    'shanti',
    'sharda',
    'sheetal',
    'shilpa',
    'shivani',
    'shraddha',
    'shreya',
    'shruti',
    'simran',
    'sneha',
    'sonal',
    'sonam',
    'sonia',
    'sudha',
    'suman',
    'sumitra',
    'sunita',
    'supriya',
    'swati',
    'tanvi',
    'tanya',
    'tara',
    'urmila',
    'usha',
    'vandana',
    'vanita',
    'vidya',
    'vijaya',
    'vimla',
    'vinita',
    'ananya',
    'aryan',
    'ayush',
    'daksh',
    'dhruvi',
    'ishaan',
    'ishita',
    'kabir',
    'krishna',
    'lakshay',
    'mahi',
    'myra',
    'navya',
    'nitya',
    'pari',
    'pihu',
    'reyansh',
    'saanvi',
    'sara',
    'siya',
    'vivaan',
    'zara',
    'harjeet',
    'gurpreet',
    'harpreet',
    'jaspreet',
    'manpreet',
    'navjot',
    'simarjeet',
    'sukhwinder',
    'amarjeet',
    'baljeet',
    'inderjeet',
    'jagdeep',
    'kuldeep',
    'mandeep',
    'sandeep',
    'sukhdev',
    'davinder',
    'jasmine',
    'joseph',
    'john',
    'jacob',
    'thomas',
    'george',
    'peter',
    'anil',
    'stephen',
    'rose',
    'mary',
    'anna',
    'grace',
  ];

  static final Set<String> _dictionary = {for (final n in _commonFirstNames) n};

  /// Sorted so the longest names are tried first — this makes prefix
  /// matching greedy without needing a trie.
  static final List<String> _byLengthDesc = [..._dictionary]
    ..sort((a, b) => b.length.compareTo(a.length));

  String _titleCase(String token) {
    if (token.isEmpty) return token;
    return token[0].toUpperCase() + token.substring(1).toLowerCase();
  }

  /// Derives a suggested display name from an email address.
  NameSuggestion suggestFromEmail(String email) {
    final atIndex = email.indexOf('@');
    final rawLocalPart = atIndex >= 0 ? email.substring(0, atIndex) : email;
    final localPart = rawLocalPart.trim().toLowerCase();

    if (localPart.isEmpty) {
      return const NameSuggestion('', NameSuggestionSource.fallback);
    }

    // Rule 1: explicit separators (mohammad.adnan, mohammad_adnan7275, ...).
    if (_separators.hasMatch(localPart)) {
      final tokens = localPart
          .split(_separators)
          .map((t) => t.replaceAll(_anyDigits, ''))
          .where((t) => t.isNotEmpty)
          .map(_titleCase)
          .toList();
      if (tokens.isNotEmpty) {
        return NameSuggestion(tokens.join(' '), NameSuggestionSource.separator);
      }
    }

    // Rule 2: no separators — strip trailing digits, then try to split a
    // concatenated name using the common-names dictionary.
    final stripped = localPart.replaceFirst(_trailingDigits, '');
    if (stripped.isEmpty) {
      return NameSuggestion(
        _titleCase(localPart.replaceAll(_anyDigits, '')),
        NameSuggestionSource.fallback,
      );
    }

    for (final candidate in _byLengthDesc) {
      if (stripped.startsWith(candidate) &&
          stripped.length > candidate.length) {
        final remainder = stripped
            .substring(candidate.length)
            .replaceAll(_anyDigits, '');
        if (remainder.isNotEmpty) {
          return NameSuggestion(
            '${_titleCase(candidate)} ${_titleCase(remainder)}',
            NameSuggestionSource.dictionary,
          );
        }
      }
    }

    // Rule 3: fallback — the whole token, title-cased, as one word.
    return NameSuggestion(_titleCase(stripped), NameSuggestionSource.fallback);
  }
}
