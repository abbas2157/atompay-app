// Canned answers read best as adjacent strings inside lists.
// ignore_for_file: no_adjacent_strings_in_list

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:atompay_mobile/core/format/dates.dart';
import 'package:dio/dio.dart';

/// Which customer the fake server plays.
enum FakeScenario {
  /// Signed up, no profile or application yet.
  newCustomer,

  /// Limit approved, nothing bought.
  approved,

  /// Limit approved and one 3-month plan being repaid (the canvas's Ayesha).
  repaying,

  /// As [repaying], with the 2nd instalment overdue.
  late;

  static FakeScenario parse(String value) => FakeScenario.values.firstWhere(
    (s) => s.name == value,
    orElse: () => FakeScenario.repaying,
  );
}

/// A stand-in for the AtomPay API that speaks the documented contract
/// (`docs/api/*.md` and brief §7.2) exactly, in memory. Used when the whole
/// app runs on fakes (`FAKE_API=true`), by tests, and for every §7.2
/// endpoint the server hasn't shipped yet.
class FakeServer implements HttpClientAdapter {
  new({
    this.scenario = FakeScenario.repaying,
    this.latency = const Duration(milliseconds: 350),
    this.trustAnyToken = false,
    DateTime? now,
  }) : _now = now ?? DateTime.now() {
    _seed();
  }

  final FakeScenario scenario;
  final Duration latency;

  /// Next to the live server, the token comes from the real sign-in, so any
  /// bearer token counts as signed in.
  final bool trustAnyToken;
  final DateTime _now;

  /// Every request the fake has answered, newest last. Tests assert on it.
  final List<RequestOptions> log = [];

  /// Make the next call to a path fail: `failNext['/dashboard'] = 503`.
  final Map<String, int> failNext = {};

  /// Calls to these paths fail as if the phone had no connection; `*`
  /// takes every path.
  final Set<String> offline = {};

  /// Calls to these paths never answer (loading states in golden tests).
  final Set<String> hang = {};

  /// Calls to these paths time out.
  final Set<String> timeout = {};

  /// `app-config.store_url`, `support` and `maintenance.until`; null like
  /// the live config until the business supplies them.
  String? storeUrl;
  Map<String, String?> support = {
    'phone': null,
    'whatsapp': null,
    'email': null,
  };
  String? maintenanceUntil;

  /// `app-config.min_version`; above the app's version → Update required.
  String minVersion = '1.0.0';

  /// `app-config.maintenance.active`.
  bool maintenance = false;

  /// `app-config.business`: the company's facts from Atomshop's admin
  /// panel. All null, as on the live server today.
  Map<String, String?> business = {
    'company_name': null,
    'registered_address': null,
    'data_hosting': null,
    'late_payment': null,
    'early_settlement': null,
    'complaint_response_time': null,
  };

  /// `app-config.features.push`: the server has FCM credentials.
  bool pushEnabled = false;

  // ---- state ---------------------------------------------------------------

  static const validPassword = 'password12';
  static const validCode = '123456';

  bool signedIn = false;
  String password = validPassword;
  late Map<String, dynamic> user;
  Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> assessments = [];
  final List<Map<String, dynamic>> orders = [];
  final List<Map<String, dynamic>> notifications = [];
  final List<Map<String, dynamic>> complaints = [];
  final List<Map<String, dynamic>> sessions = [];
  bool emailAlerts = true;
  int _nextId = 2000;
  int _codeTries = 0;

  DateTime _day(int offset) =>
      DateTime(_now.year, _now.month, _now.day + offset);

  void _seed() {
    final hasLimit = scenario != FakeScenario.newCustomer;
    signedIn = false;
    user = {
      'id': 5012,
      'name': 'Ayesha Khan',
      'short_name': 'Ayesha K.',
      'email': 'ayesha@example.com',
      'email_verified': true,
      'phone': '03007013707',
      'phone_formatted': '0300 7013707',
      'member_since': '2026-09-24',
      'kyc_status': hasLimit ? 'verified' : 'not_started',
    };
    sessions
      ..clear()
      ..addAll([
        {
          'id': 140,
          'device_name': 'This phone',
          'current': true,
          'signed_in_at': _day(-3).toIso8601String(),
          'last_used_at': _now.toIso8601String(),
          'expires_at': _day(27).toIso8601String(),
        },
        {
          'id': 131,
          'device_name': 'Samsung Galaxy A54 · Android 14',
          'current': false,
          'signed_in_at': _day(-20).toIso8601String(),
          'last_used_at': _day(-6).toIso8601String(),
          'expires_at': _day(10).toIso8601String(),
        },
      ]);
    if (!hasLimit) return;

    profile = _profileJson(status: 'verified');
    assessments.add(
      _assessment(
        id: 311,
        status: 'approved',
        income: 200000,
        limit: 60000,
        decidedDaysAgo: 30,
      ),
    );
    if (scenario == FakeScenario.repaying || scenario == FakeScenario.late) {
      final late = scenario == FakeScenario.late;
      orders.add(
        _order(
          id: 1279,
          reference: 'AS-01279',
          productId: 51,
          title: 'OXY 3218L Android',
          price: 47000,
          firstDue: late ? -45 : -20,
          paidCount: 1,
        ),
      );
    }
    notifications.addAll([
      _notification(
        57,
        'instalment_due',
        'Instalment due in 10 days',
        'Rs. 15,666 for OXY 3218L Android is due soon.',
        {'screen': 'plan', 'order_id': 1279},
        read: false,
        daysAgo: 0,
      ),
      _notification(
        41,
        'limit_decided',
        'Your AtomPay limit is approved',
        'You can spend up to Rs. 60,000 at Atomshop.pk checkout.',
        {'screen': 'dashboard', 'assessment_id': 311},
        read: true,
        daysAgo: 30,
      ),
      _notification(
        33,
        'kyc_verified',
        'Your address is verified',
        'Thanks for meeting our team. Your identity check is complete.',
        {'screen': 'profile'},
        read: true,
        daysAgo: 32,
      ),
    ]);
  }

  /// A new customer part-way through applying: identity filled in, no
  /// photos yet (golden tests compare the filled forms).
  void seedDraftProfile() => profile = _profileJson(status: 'not_started');

  /// One order in each status the Orders list can show (canvas
  /// "OrderStates").
  void seedEveryOrderState() {
    orders.clear();
    var id = 1300;
    for (final (status, firstDue, paid, title) in [
      ('Pending', 40, 0, 'Haier 1.5 ton inverter AC'),
      ('Varification', 40, 0, 'Samsung Galaxy A35'),
      ('Processing', 35, 0, 'Dawlance 9178 refrigerator'),
      ('Delivered', 30, 0, 'OXY 3218L Android'),
      ('Instalments', -20, 1, 'Infinix Hot 50'),
      ('Instalments', -45, 1, 'Anker Soundcore Q20i'),
      ('Instalments', -80, 3, 'Xiaomi Redmi Pad SE'),
      ('Cancelled', 30, 0, 'Canon EOS 2000D'),
    ]) {
      id++;
      orders.add(
        _order(
          id: id,
          reference: 'AS-0$id',
          productId: id,
          title: title,
          price: 47000,
          firstDue: firstDue,
          paidCount: paid,
          status: status,
        ),
      );
    }
  }

  /// A first application sent and waiting (or turned down): the identity
  /// check is pending and there is no limit.
  void seedPendingApplication({bool rejected = false}) {
    profile = _profileJson(status: 'pending');
    user['kyc_status'] = 'pending';
    assessments.add(
      _assessment(
        id: 939,
        status: rejected ? 'rejected' : 'pending',
        income: 200000,
        decidedDaysAgo: rejected ? 1 : 0,
      ),
    );
  }

  Map<String, dynamic> _profileJson({required String status}) => {
    'status': status,
    'full_name': 'Ayesha Khan',
    'cnic': '3520112345671',
    'cnic_formatted': '35201-1234567-1',
    'mobile': '03007013707',
    'mobile_formatted': '0300 7013707',
    'date_of_birth': '1994-03-14',
    'residential_address': 'House 12, Street 4, Block G',
    'city': {'id': 50, 'name': 'Lahore'},
    'area': {'id': 24, 'title': 'Johar Town'},
    'documents': {
      for (final d in ['cnic_front', 'cnic_back', 'selfie'])
        d: {
          'uploaded': status != 'not_started',
          'url': status != 'not_started'
              ? 'https://atompay.shop/api/v1/profile/documents/$d'
              : null,
        },
    },
    'address_verified': status == 'verified',
    'verified_at': status == 'verified' ? _day(-32).toIso8601String() : null,
    'submitted_at': status == 'not_started'
        ? null
        : _day(-35).toIso8601String(),
  };

  Map<String, dynamic> _assessment({
    required int id,
    required String status,
    required int income,
    int? limit,
    int decidedDaysAgo = 0,
    String employment = 'salaried',
    String? employer = 'Acme Ltd',
    String source = 'salary',
    int existing = 10000,
    int expenses = 90000,
  }) {
    final decided = status != 'pending';
    final disposable = income - existing - expenses;
    return {
      'id': id,
      'status': status,
      'status_label': _statusLabel(status),
      'is_usable': status == 'approved' || status == 'conditional',
      'employment_status': employment,
      'employment_status_label': _employmentLabels[employment],
      'employer_name': employer,
      'income_source': source,
      'income_source_label': _incomeLabels[source],
      'monthly_income': income,
      'existing_instalments': existing,
      'monthly_expenses': expenses,
      'disposable_income': disposable,
      'approved_limit': decided && limit != null ? limit : null,
      'max_instalment': decided && limit != null
          ? [income ~/ 10, disposable].reduce((a, b) => a < b ? a : b)
          : null,
      'approved_tenure': decided && limit != null ? 3 : null,
      'notes': status == 'rejected'
          ? 'Your expenses leave too little room for monthly payments.'
          : null,
      'submitted_at': _day(-decidedDaysAgo - 2).toIso8601String(),
      'decided_at': decided ? _day(-decidedDaysAgo).toIso8601String() : null,
    };
  }

  static String _statusLabel(String s) => switch (s) {
    'approved' => 'Approved',
    'conditional' => 'Conditionally approved',
    'rejected' => 'Not approved',
    _ => 'Pending',
  };

  static const _employmentLabels = {
    'salaried': 'Salaried',
    'self_employed': 'Self-employed',
    'business_owner': 'Business owner',
    'freelancer': 'Freelancer',
    'retired': 'Retired',
    'unemployed': 'Unemployed',
  };

  static const _incomeLabels = {
    'salary': 'Salary',
    'business': 'Business',
    'rental': 'Rental',
    'remittance': 'Remittance',
    'pension': 'Pension',
    'other': 'Other',
  };

  /// One AtomPay order: 3 months, no advance, the last month takes the
  /// rounding (brief §2).
  Map<String, dynamic> _order({
    required int id,
    required String reference,
    required int productId,
    required String title,
    required int price,
    required int firstDue,
    required int paidCount,
    String status = 'Instalments',
  }) {
    final monthly = price ~/ 3;
    final amounts = [monthly, monthly, price - 2 * monthly];
    final instalments = [
      for (var i = 0; i < 3; i++)
        {
          'id': id * 10 + i,
          'order_id': id,
          'label': '${['1st', '2nd', '3rd'][i]} Instalment',
          'due_date': apiDate(_day(firstDue + 30 * i)),
          'amount': amounts[i],
          'paid_amount': i < paidCount ? amounts[i] : null,
          'paid_via': i < paidCount ? 'JazzCash' : null,
          'paid_on': i < paidCount
              ? apiDate(_day(firstDue + 30 * i - 1))
              : null,
          'state': _instalmentState(i < paidCount, firstDue + 30 * i),
        },
    ];
    return {
      'order': {
        'id': id,
        'reference': reference,
        'status': status,
        'status_label': status,
        'ordered_at': _day(firstDue - 31).toIso8601String(),
        // Proposed (docs/api/plans.md): set once AtomShop delivers.
        'delivered_at': status == 'Instalments' || status == 'Delivered'
            ? _day(firstDue - 29).toIso8601String()
            : null,
        'total_price': price,
        'advance': 0,
        'financed': price,
        'tenure': 3,
      },
      'product': {
        'id': productId,
        'title': title,
        'picture_url': null,
        'shop_url': 'https://atomshop.pk/product/${_slug(title)}',
      },
      'instalments': instalments,
    };
  }

  static String _instalmentState(bool paid, int dueOffset) {
    if (paid) return 'paid';
    if (dueOffset < 0) return 'late';
    if (dueOffset <= 14) return 'due';
    return 'upcoming';
  }

  static String _slug(String s) =>
      s.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-');

  Map<String, dynamic> _notification(
    int id,
    String type,
    String title,
    String body,
    Map<String, dynamic> payload, {
    required bool read,
    required int daysAgo,
  }) => {
    'id': id,
    'type': type,
    'title': title,
    'body': body,
    'payload': payload,
    'read': read,
    'created_at': _day(-daysAgo)
        .add(const Duration(hours: 9))
        .toIso8601String(),
  };

  // ---- derived views --------------------------------------------------------

  Map<String, dynamic> _planView(
    Map<String, dynamic> o, {
    bool detail = false,
  }) {
    final inst = (o['instalments'] as List).cast<Map<String, dynamic>>();
    final paid = inst.where((i) => i['state'] == 'paid').toList();
    final unpaid = inst.where((i) => i['state'] != 'paid').toList();
    final total = inst.fold<int>(0, (s, i) => s + (i['amount'] as int));
    final paidAmount = paid.fold<int>(0, (s, i) => s + (i['amount'] as int));
    final state = switch ((o['order'] as Map)['status']) {
      'Pending' || 'Varification' => 'pending',
      'Processing' || 'Delivered' => 'processing',
      'Cancelled' => 'cancelled',
      _ =>
        unpaid.isEmpty
            ? 'completed'
            : (unpaid.any((i) => i['state'] == 'late') ? 'late' : 'on_track'),
    };
    return {
      'order': o['order'],
      'product': o['product'],
      'state': state,
      'progress': {
        'paid_count': paid.length,
        'total_count': inst.length,
        'paid_amount': paidAmount,
        'total_amount': total,
        'remaining_amount': total - paidAmount,
        'percent': total == 0 ? 0 : paidAmount * 100 ~/ total,
      },
      'next_due': unpaid.isEmpty ? null : _withOrder(unpaid.first, o),
      if (detail) 'instalments': inst,
    };
  }

  Map<String, dynamic> _withOrder(
    Map<String, dynamic> i,
    Map<String, dynamic> o,
  ) => {
    ...i,
    'order_reference': (o['order'] as Map)['reference'],
    'product_title': (o['product'] as Map?)?['title'],
  };

  Map<String, dynamic>? get _active {
    for (final a in assessments.reversed) {
      if (a['is_usable'] == true) return a;
    }
    return null;
  }

  int get _used {
    var used = 0;
    for (final o in orders) {
      for (final i in (o['instalments'] as List).cast<Map<String, dynamic>>()) {
        if (i['state'] != 'paid') used += i['amount'] as int;
      }
    }
    return used;
  }

  Map<String, dynamic> _dashboard() {
    final active = _active;
    final latest = assessments.isEmpty ? null : assessments.last;
    final approved = (active?['approved_limit'] as int?) ?? 0;
    final used = active == null ? 0 : _used;
    final available = (approved - used).clamp(0, approved);
    Map<String, dynamic>? nextDue;
    for (final o in orders) {
      final view = _planView(o);
      final n = view['next_due'] as Map<String, dynamic>?;
      if (n != null &&
          (nextDue == null ||
              (n['due_date'] as String).compareTo(
                    nextDue['due_date'] as String,
                  ) <
                  0)) {
        nextDue = n;
      }
    }
    final kyc = user['kyc_status'] as String;
    final hasProfile = profile != null && profile!['status'] != 'not_started';
    // A local helper in the fake: two flags read fine here.
    // ignore: avoid_positional_boolean_parameters
    String stage(bool done, bool current) =>
        done ? 'done' : (current ? 'current' : 'upcoming');
    return {
      'kyc_status': kyc,
      'application_status': latest?['status'],
      'banner': active != null
          ? {
              'tone': 'done',
              'title': 'Verification complete',
              'text':
                  'Your limit below is confirmed and ready to use at '
                  'AtomShop checkout.',
              'cta': 'Improve my limit',
              'action': 'application',
            }
          : latest != null
          ? {
              'tone': latest['status'] == 'rejected' ? 'blocked' : 'pending',
              'title': latest['status'] == 'rejected'
                  ? 'Application not approved'
                  : 'Application under review',
              'text': latest['status'] == 'rejected'
                  ? (latest['notes'] ?? 'We could not approve a limit.')
                  : 'We usually decide within 2 working days.',
              'cta': latest['status'] == 'rejected'
                  ? 'Update and resend'
                  : null,
              'action': latest['status'] == 'rejected' ? 'application' : null,
            }
          : {
              'tone': 'pending',
              'title': 'Get your AtomPay limit',
              'text':
                  'Tell us who you are and what you earn. It takes about '
                  '5 minutes.',
              'cta': 'Get a limit',
              'action': 'apply',
            },
      'limit': {
        'has_limit': active != null,
        'status': active?['status'],
        'approved': approved,
        'used': used,
        'available': available,
        'used_percent': approved == 0 ? 0 : used * 100 ~/ approved,
        'max_instalment': active?['max_instalment'] ?? 0,
        'tenure': active == null ? null : 3,
        // Proposed fields (docs/api/dashboard.md).
        'available_after_next': switch (nextDue?['amount']) {
          final int amount => available + amount,
          _ => null,
        },
      },
      'stages': [
        {
          'key': 'kyc',
          'title': 'KYC',
          'hint': 'Identity details and CNIC uploaded',
          'state': stage(hasProfile, !hasProfile),
        },
        {
          'key': 'address',
          'title': 'Address verification',
          'hint': 'One-time physical visit by our team',
          'state': stage(kyc == 'verified', hasProfile && kyc == 'pending'),
        },
        {
          'key': 'income',
          'title': 'Income assessment',
          'hint': 'Your financial profile',
          'state': stage(latest != null, hasProfile && latest == null),
        },
        {
          'key': 'risk',
          'title': 'Risk assessment',
          'hint': 'Reviewed by AtomPay',
          'state': stage(
            active != null,
            latest != null && latest['status'] == 'pending',
          ),
        },
        {
          'key': 'limit',
          'title': 'Purchase limit',
          'hint': 'Approved limit, instalment cap and tenure',
          'state': stage(active != null, false),
        },
        {
          'key': 'shop',
          'title': 'AtomShop purchase',
          'hint': 'Choose AtomPay at checkout',
          'state': stage(orders.isNotEmpty, active != null && orders.isEmpty),
        },
      ],
      'next_due': nextDue,
      'plans': {
        'active_count': orders
            .where(
              (o) =>
                  _planView(o)['state'] == 'on_track' ||
                  _planView(o)['state'] == 'late',
            )
            .length,
        'pending_count': orders
            .where((o) => _planView(o)['state'] == 'pending')
            .length,
        'has_late': orders.any((o) => _planView(o)['state'] == 'late'),
      },
      'unread_notifications': notifications
          .where((n) => n['read'] != true)
          .length,
      'lowest_eligible_price': active == null
          ? null
          : _products.map((p) => p.$4).reduce((a, b) => a < b ? a : b),
    };
  }

  // ---- products (brief §7.2) ------------------------------------------------

  static const _products = [
    (51, 'OXY', 'OXY 3218L Android', 47000, 3, 'TVs'),
    (52, 'OPPO', 'Oppo A6K', 53995, 1, 'Phones'),
    (53, 'OXY', 'OXY 4018 Android TV', 62000, 3, 'TVs'),
    (54, 'OPPO', 'Oppo A6', 69995, 1, 'Phones'),
    (55, 'OXY', 'OXY 4318F Smart TV', 70000, 3, 'TVs'),
    (56, 'OXY', 'OXY 6518G Smart TV', 179900, 3, 'TVs'),
    (57, 'SAMSUNG', 'Samsung Galaxy S26 FE', 231995, 1, 'Phones'),
    (58, 'APPLE', 'Apple iPhone 17 Pro', 473999, 1, 'Phones'),
  ];

  Map<String, dynamic> _productJson(
    (int, String, String, int, int, String) p, {
    bool detail = false,
  }) {
    final (id, brand, title, price, catId, catTitle) = p;
    final monthly = price ~/ 3;
    final available = signedIn && _active != null
        ? ((_active!['approved_limit'] as int) - _used)
        : null;
    return {
      'id': id,
      'title': title,
      'brand': brand,
      'category': {'id': catId, 'title': catTitle},
      'price': price,
      'monthly': monthly,
      'last_monthly': price - 2 * monthly,
      'image_url': null,
      'url': 'https://atomshop.pk/product/${_slug(title)}',
      'within_limit': available == null ? null : price <= available,
      if (detail)
        'description':
            '$title from $brand, sold and delivered by Atomshop.pk. '
            'Pay over three months with AtomPay.',
    };
  }

  // ---- Ask Atom (brief §7.2): rules-based ---------------------------------

  Map<String, dynamic> _askAtom(String question) {
    final q = question.toLowerCase();
    final chips = [
      'When are my payments due?',
      'How is my limit worked out?',
      'What does AtomPay cost?',
    ];
    if (q.contains('cost') || q.contains('fee') || q.contains('markup')) {
      return {
        'paragraphs': [
          'AtomPay is **3 months, no advance and 0% markup**. You pay the '
              'cash price in three monthly payments.',
          'A **3% processing fee** is shown with every plan, and delivery '
              'charges apply.',
        ],
        'table': [
          {'label': 'Month 1', 'value': 15666},
          {'label': 'Month 2', 'value': 15666},
          {'label': 'Month 3', 'value': 15668},
        ],
        'actions': [
          {'label': 'Try the calculator', 'route': '/calculator'},
        ],
        'chips': chips.where((c) => !c.contains('cost')).toList(),
      };
    }
    if (q.contains('due') || q.contains('pay') || q.contains('when')) {
      final next = _dashboard()['next_due'] as Map<String, dynamic>?;
      return {
        'paragraphs': [
          if (next == null)
            "You don't have any payments due."
          else
            'Your next payment is **Rs. ${grouped(next['amount'] as int)}**, '
                'due on ${dayMonth(DateTime.parse('${next['due_date']}'))}.',
          'Pay through Atomshop.pk the same way you paid at checkout.',
        ],
        'table': null,
        'actions': [
          if (next != null)
            {'label': 'See the order', 'route': '/plans/${next['order_id']}'},
        ],
        'chips': chips.where((c) => !c.contains('due')).toList(),
      };
    }
    if (q.contains('limit')) {
      return {
        'paragraphs': [
          'Your limit is **30% of your monthly income**. Each monthly '
              'payment has to fit within 10% of your income and what is '
              'left after your expenses.',
          'Your limit frees up as you pay.',
        ],
        'table': null,
        'actions': [
          {'label': 'See eligible products', 'route': '/shop'},
        ],
        'chips': chips.where((c) => !c.contains('limit')).toList(),
      };
    }
    return {
      'paragraphs': [
        'I can help with your limit, payments, orders and how AtomPay '
            'works. Try one of these questions.',
      ],
      'table': null,
      'actions': [
        {'label': 'Open Help', 'route': '/help'},
      ],
      'chips': chips,
    };
  }

  // ---- transport ------------------------------------------------------------

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    log.add(options);
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final path = options.uri.path.replaceFirst(RegExp('^.*/api/v1'), '');
    if (hang.contains(path)) {
      // Never answers: the screen stays in its loading state.
      await Completer<void>().future;
    }
    if (timeout.contains(path)) {
      throw DioException.receiveTimeout(
        timeout: const Duration(seconds: 20),
        requestOptions: options,
      );
    }
    if (offline.contains('*') || offline.contains(path)) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Fake: no connection',
      );
    }
    final failing = failNext.remove(path);
    if (failing != null) {
      return _json(failing, {
        'message': failing >= 500 ? 'Server Error' : 'Error',
      });
    }
    final body = await _readBody(options, requestStream);
    final (status, json, headers) = _route(options.method, path, options, body);
    return _json(status, json, headers: headers);
  }

  Future<Map<String, dynamic>> _readBody(
    RequestOptions options,
    Stream<Uint8List>? stream,
  ) async {
    final data = options.data;
    if (data is Map) return data.cast<String, dynamic>();
    if (data is FormData) {
      return {
        for (final f in data.fields) f.key: f.value,
        for (final f in data.files) f.key: '<file>',
      };
    }
    if (data is String && data.isNotEmpty) {
      return (jsonDecode(data) as Map).cast<String, dynamic>();
    }
    return const {};
  }

  ResponseBody _json(
    int status,
    Object? json, {
    Map<String, List<String>> headers = const {},
  }) => ResponseBody.fromString(
    json == null ? '' : jsonEncode(json),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...headers,
    },
  );

  bool _authed(RequestOptions o) =>
      o.headers['Authorization'] != null && (signedIn || trustAnyToken);

  (int, Object?, Map<String, List<String>>) _route(
    String method,
    String path,
    RequestOptions o,
    Map<String, dynamic> body,
  ) {
    const none = <String, List<String>>{};
    (int, Object?, Map<String, List<String>>) ok(Object? data, [int s = 200]) =>
        (s, data == null ? null : {'data': data}, none);
    (int, Object?, Map<String, List<String>>) invalid(
      String field,
      String message,
    ) => (
      422,
      {
        'message': message,
        'errors': {
          field: [message],
        },
      },
      none,
    );
    const unauth = (
      401,
      {'message': 'Unauthenticated.'},
      <String, List<String>>{},
    );
    final q = o.uri.queryParameters;
    final segs = path.split('/').where((s) => s.isNotEmpty).toList();

    // Public.
    switch ((method, path)) {
      case ('GET', '/app-config'):
        return ok({
          'min_version': {'android': minVersion, 'ios': minVersion},
          'store_url': {'android': storeUrl, 'ios': storeUrl},
          'shop_url': 'https://atomshop.pk',
          'password_reset_url': 'https://atompay.shop/forgot-password',
          'privacy_url': 'https://atompay.shop/privacy-policy',
          'terms_url': null,
          'account_deletion_url': 'https://atompay.shop/delete-account',
          'support': support,
          // Set in Atomshop's admin panel; null until supplied there.
          'business': business,
          'features': {
            'push': pushEnabled,
            'password_reset_channels': ['email', 'whatsapp'],
            'signup_channels': ['email', 'whatsapp'],
            'voice': true,
          },
          'maintenance': {
            'active': maintenance,
            'message': null,
            'until': maintenanceUntil,
          },
          'apps': {
            'atomshop': {
              'android': null,
              'ios': null,
              'web': 'https://atomshop.pk',
            },
            'atompay': {
              'android': null,
              'ios': null,
              'web': 'https://atompay.shop',
            },
            'atomseller': {
              'android': null,
              'ios': null,
              'web': 'https://atomshop.pk/smart-seller',
            },
            'atombrand': {
              'android': null,
              'ios': null,
              'web': 'https://atomshop.pk/brand-partners',
            },
          },
        });
      case ('GET', '/options'):
        return ok({
          'employment_statuses': [
            for (final e in _employmentLabels.entries)
              {
                'value': e.key,
                'label': e.value,
                'has_employer': const {
                  'salaried',
                  'self_employed',
                  'business_owner',
                }.contains(e.key),
              },
          ],
          'income_sources': [
            for (final e in _incomeLabels.entries)
              {'value': e.key, 'label': e.value},
          ],
          'complaint_topics': [
            {'value': 'payment', 'label': 'A payment'},
            {'value': 'order', 'label': 'An order'},
            {'value': 'limit', 'label': 'My limit or application'},
            {'value': 'account', 'label': 'My account or sign-in'},
            {'value': 'other', 'label': 'Something else'},
          ],
        });
      case ('GET', '/plan-preview'):
        final price = int.tryParse(q['price'] ?? '');
        if (price == null || price < 1000) {
          return invalid('price', 'Enter a price of at least Rs. 1,000.');
        }
        final m = price ~/ 3;
        final available = signedIn && _active != null
            ? (_active!['approved_limit'] as int) - _used
            : null;
        return ok({
          'price': price,
          'advance': 0,
          'markup': 0,
          'months': 3,
          'instalments': [m, m, price - 2 * m],
          'total': price,
          'processing_fee_percent': 3,
          'processing_fee': price * 3 ~/ 100,
          'fits_limit': available == null ? null : price <= available,
        });
      case ('POST', '/estimate'):
        final income = (body['monthly_income'] as num?)?.toInt() ?? 0;
        return ok({
          'monthly_income': income,
          'estimated_limit': income * 30 ~/ 100,
          'estimated_max_instalment': income ~/ 10,
        });
      case ('GET', '/products/categories'):
        return ok([
          {'id': 3, 'title': 'TVs', 'count': 4},
          {'id': 1, 'title': 'Phones', 'count': 4},
        ]);
      case ('GET', '/products'):
        final cat = q['category'];
        final query = (q['q'] ?? '').toLowerCase();
        final within = q['within_limit'] == '1';
        final list = [
          for (final p in _products)
            if ((cat == null ||
                    cat.isEmpty ||
                    p.$6.toLowerCase().startsWith(cat.toLowerCase()) ||
                    '${p.$5}' == cat) &&
                (query.isEmpty ||
                    '${p.$2} ${p.$3}'.toLowerCase().contains(query)))
              _productJson(p),
        ].where((p) => !within || p['within_limit'] != false).toList();
        return (
          200,
          {
            'data': list,
            'meta': {'current_page': 1, 'last_page': 1, 'total': list.length},
          },
          none,
        );
      case ('GET', '/ask-atom/chips'):
        return ok([
          'What does AtomPay cost?',
          'When are my payments due?',
          'How is my limit worked out?',
          'Which products can I buy?',
        ]);
      case ('POST', '/ask-atom'):
        final question = '${body['question'] ?? ''}'.trim();
        if (question.isEmpty || question.length > 300) {
          return invalid('question', 'Ask a question of up to 300 characters.');
        }
        return ok(_askAtom(question));
      case ('POST', '/auth/login'):
        final login = '${body['login'] ?? ''}';
        if (body['password'] != password ||
            !(login.contains('@') ||
                login.replaceAll(RegExp(r'\D'), '').length >= 10)) {
          return invalid(
            'login',
            'Those details do not match an AtomShop account.',
          );
        }
        return ok(_signIn());
      case ('POST', '/auth/register'):
        final login = '${body['login'] ?? ''}';
        if (login.isEmpty) {
          return invalid(
            'login',
            'Enter your email address or mobile number, e.g. 0300 1234567.',
          );
        }
        if (login.startsWith('021')) {
          return invalid(
            'login',
            'That looks like a landline. Enter a mobile number so we can '
                'text you about payments.',
          );
        }
        _codeTries = 0;
        return ok(_codeSent('signup_id', login), 202);
      case ('POST', '/auth/register/resend'):
        return ok(_codeSent('signup_id', '0300 7013707'));
      case ('POST', '/auth/register/verify'):
        if (body['code'] != validCode) {
          _codeTries++;
          return _codeTries >= 5
              ? invalid('signup', 'Too many wrong codes. Please start again.')
              : invalid(
                  'code',
                  "That code isn't right. ${5 - _codeTries} tries left.",
                );
        }
        user['kyc_status'] = 'not_started';
        return ok(_signIn(), 201);
      case ('POST', '/auth/password/forgot'):
        _codeTries = 0;
        return ok(_codeSent('request_id', '${body['login'] ?? ''}'), 202);
      case ('POST', '/auth/password/verify'):
        if (body['code'] != validCode) {
          _codeTries++;
          return _codeTries >= 5
              ? invalid('code', 'Too many wrong codes. Request a new one.')
              : invalid(
                  'code',
                  "That code isn't right. ${5 - _codeTries} tries left.",
                );
        }
        return ok({'reset_token': 'fake-reset-token', 'expires_in': 900});
      case ('POST', '/auth/password/reset'):
        if ('${body['password'] ?? ''}'.length < 8) {
          return invalid(
            'password',
            'The password must be at least 8 characters.',
          );
        }
        password = '${body['password']}';
        return ok(_signIn());
    }

    if (!_authed(o)) {
      // Public reads that also work signed out.
      if (method == 'GET' && segs.length == 2 && segs[0] == 'products') {
        return _productDetail(segs[1]);
      }
      return unauth;
    }

    switch ((method, path)) {
      case ('GET', '/me'):
        return ok(user);
      case ('POST', '/auth/logout'):
        signedIn = false;
        return (204, null, none);
      case ('POST', '/auth/logout-all'):
        signedIn = false;
        return (204, null, none);
      case ('GET', '/auth/sessions'):
        return ok(sessions);
      case ('GET', '/me/preferences'):
        return ok({'email_alerts': emailAlerts});
      case ('PATCH', '/me/preferences'):
        emailAlerts = body['email_alerts'] == true;
        return ok({'email_alerts': emailAlerts});
      case ('POST', '/me/delete'):
        if (body['password'] != password) {
          return invalid('password', "That password isn't right.");
        }
        if (orders.any((o) => _planView(o)['state'] != 'completed')) {
          return (
            409,
            {
              'message':
                  'You still have instalments to pay. You can delete your '
                  'account once every plan is repaid.',
              'code': 'outstanding_balance',
            },
            none,
          );
        }
        signedIn = false;
        return (204, null, none);
      case ('POST', '/me/password'):
        if (body['current_password'] != password) {
          return invalid('current_password', "That password isn't right.");
        }
        if ('${body['password'] ?? ''}'.length < 8) {
          return invalid(
            'password',
            'The password must be at least 8 characters.',
          );
        }
        if (body['password'] != body['password_confirmation']) {
          return invalid('password', "The passwords don't match.");
        }
        password = '${body['password']}';
        sessions.removeWhere((s) => s['current'] != true);
        return (204, null, none);
      case ('GET', '/dashboard'):
        return ok(_dashboard());
      case ('GET', '/cities'):
        return ok(_cities);
      case ('GET', '/areas'):
        final city = int.tryParse(q['city_id'] ?? '');
        if (city == null || !_cities.any((c) => c['id'] == city)) {
          return invalid('city_id', 'Choose a city from the list.');
        }
        return ok(city == 50 ? _lahoreAreas : <Map<String, dynamic>>[]);
      case ('GET', '/profile'):
        return ok(profile ?? _draftProfile());
      case ('POST', '/profile'):
        final first = profile == null || profile!['status'] == 'not_started';
        if (first && body['cnic_front'] == null) {
          return invalid(
            'cnic_front',
            'Take a photo of the front of your CNIC.',
          );
        }
        final cityId = int.tryParse('${body['city_id'] ?? ''}');
        final areaId = int.tryParse('${body['area_id'] ?? ''}');
        profile = {
          ..._profileJson(status: 'pending'),
          'full_name': body['full_name'],
          'cnic': '${body['cnic']}'.replaceAll('-', ''),
          'mobile': body['mobile'],
          'date_of_birth': body['date_of_birth'],
          'residential_address': body['residential_address'],
          'city': cityId == null
              ? null
              : _cities.firstWhere(
                  (c) => c['id'] == cityId,
                  orElse: () => _cities.first,
                ),
          'area': areaId == null
              ? null
              : {
                  'id': areaId,
                  'title': _lahoreAreas.firstWhere(
                    (a) => a['id'] == areaId,
                    orElse: () => _lahoreAreas.first,
                  )['title'],
                },
        };
        user['kyc_status'] = 'pending';
        return ok(profile, first ? 201 : 200);
      case ('GET', '/application'):
        final hasProfile =
            profile != null && profile!['status'] != 'not_started';
        return ok({
          'can_apply': hasProfile,
          'requires': hasProfile ? null : 'profile',
          'latest': assessments.isEmpty ? null : assessments.last,
          'active': _active,
        });
      case ('POST', '/application'):
        if (profile == null || profile!['status'] == 'not_started') {
          return (
            409,
            {
              'message': 'Please complete your identity details first.',
              'code': 'profile_required',
            },
            none,
          );
        }
        final income = (body['monthly_income'] as num?)?.toInt() ?? 0;
        if (income < 1000) {
          return invalid('monthly_income', 'Enter your monthly income.');
        }
        final active = _active;
        if (active != null &&
            active['monthly_income'] == income &&
            active['monthly_expenses'] ==
                ((body['monthly_expenses'] as num?)?.toInt() ?? 0) &&
            active['existing_instalments'] ==
                ((body['existing_instalments'] as num?)?.toInt() ?? 0) &&
            active['employment_status'] == body['employment_status'] &&
            active['income_source'] == body['income_source']) {
          return (
            409,
            {
              'message':
                  'These are the figures already on file, so there is '
                  'nothing to review.',
              'code': 'nothing_changed',
            },
            none,
          );
        }
        final a = _assessment(
          id: _nextId++,
          status: 'pending',
          income: income,
          employment: '${body['employment_status']}',
          employer: body['employer_name'] as String?,
          source: '${body['income_source']}',
          existing: (body['existing_instalments'] as num?)?.toInt() ?? 0,
          expenses: (body['monthly_expenses'] as num?)?.toInt() ?? 0,
        );
        if (assessments.isNotEmpty && assessments.last['status'] == 'pending') {
          assessments.removeLast();
        }
        assessments.add(a);
        return ok(a, 201);
      case ('GET', '/application/history'):
        return ok(assessments.reversed.toList());
      case ('GET', '/plans'):
        return ok([for (final o in orders.reversed) _planView(o)]);
      case ('GET', '/notifications'):
        final unread = notifications.where((n) => n['read'] != true).length;
        return (
          200,
          {
            'data': notifications,
            'links': {'first': null, 'last': null, 'prev': null, 'next': null},
            'meta': {
              'current_page': 1,
              'last_page': 1,
              'per_page': 20,
              'total': notifications.length,
              'unread_count': unread,
            },
          },
          none,
        );
      case ('POST', '/notifications/read-all'):
        for (final n in notifications) {
          n['read'] = true;
        }
        return (204, null, none);
      case ('GET', '/complaints'):
        return ok(complaints.reversed.toList());
      case ('POST', '/complaints'):
        final message = '${body['message'] ?? ''}'.trim();
        if (message.length < 10) {
          return invalid(
            'message',
            'Tell us a little more: at least 10 characters.',
          );
        }
        final id = complaints.length + 7;
        final orderId = body['order_id'];
        String? orderNumber;
        for (final o in orders) {
          if ((o['order'] as Map)['id'] == orderId) {
            orderNumber = (o['order'] as Map)['reference'] as String;
          }
        }
        final c = {
          'id': id,
          'reference': 'CMP-${1035 + id}',
          'topic': body['topic'],
          'order_number': orderNumber,
          'status': 'open',
          'created_at': _now.toIso8601String(),
          'reply': null,
        };
        complaints.add(c);
        return ok({
          'id': id,
          'reference': c['reference'],
          'status': 'open',
          'created_at': c['created_at'],
        }, 201);
      case ('POST', '/devices'):
        return ok({
          'id': 7,
          'platform': body['platform'],
          'app_version': body['app_version'],
          'registered_at': _now.toIso8601String(),
        }, 201);
      case ('DELETE', '/devices'):
        return (204, null, none);
    }

    // Parameterised paths.
    if (segs.length >= 2 && segs[0] == 'plans') {
      final id = int.tryParse(segs[1]);
      final order = orders
          .where((x) => (x['order'] as Map)['id'] == id)
          .firstOrNull;
      if (order == null) return (404, {'message': 'Not found.'}, none);
      if (segs.length == 2 && method == 'GET') {
        return ok(_planView(order, detail: true));
      }
      if (segs.length == 3 && segs[2] == 'kfs' && method == 'GET') {
        return ok(_kfs(order));
      }
      if (segs.length == 4 && segs[3] == 'send' && method == 'POST') {
        return (202, null, none);
      }
    }
    if (segs.length == 2 && segs[0] == 'products' && method == 'GET') {
      return _productDetail(segs[1]);
    }
    if (segs.length == 3 &&
        segs[0] == 'profile' &&
        segs[1] == 'documents' &&
        method == 'GET') {
      return (404, {'message': 'Not found.'}, none);
    }
    if (segs.length == 3 &&
        segs[0] == 'auth' &&
        segs[1] == 'sessions' &&
        method == 'DELETE') {
      final id = int.tryParse(segs[2]);
      final before = sessions.length;
      sessions.removeWhere((s) => s['id'] == id);
      if (sessions.length == before) {
        return (404, {'message': 'Not found.'}, none);
      }
      return (204, null, none);
    }
    if (segs.length == 3 &&
        segs[0] == 'notifications' &&
        segs[2] == 'read' &&
        method == 'POST') {
      final id = int.tryParse(segs[1]);
      final n = notifications.where((x) => x['id'] == id).firstOrNull;
      if (n == null) return (404, {'message': 'Not found.'}, none);
      n['read'] = true;
      return ok(n);
    }
    return (404, {'message': 'Not found.'}, none);
  }

  (int, Object?, Map<String, List<String>>) _productDetail(String raw) {
    final id = int.tryParse(raw);
    final p = _products.where((x) => x.$1 == id).firstOrNull;
    if (p == null) return (404, {'message': 'Not found.'}, const {});
    return (200, {'data': _productJson(p, detail: true)}, const {});
  }

  Map<String, dynamic> _kfs(Map<String, dynamic> o) {
    final order = o['order'] as Map;
    final inst = (o['instalments'] as List).cast<Map<String, dynamic>>();
    final price = order['total_price'] as int;
    return {
      'order_number': order['reference'],
      'product': (o['product'] as Map?)?['title'],
      'lender': {'name': null, 'licence': null, 'address': null},
      'amount_financed': price,
      'advance': 0,
      'markup_percent': 0,
      'processing_fee_percent': 3,
      'processing_fee': price * 3 ~/ 100,
      'apr_percent': 18.5,
      'months': 3,
      'instalments': [
        for (var i = 0; i < inst.length; i++)
          {
            'number': i + 1,
            'due_date': inst[i]['due_date'],
            'amount': inst[i]['amount'],
          },
      ],
      'total_repayable': price,
      'late_payment': null,
      'early_settlement': null,
      'complaints': 'In the app: Help › Complaints.',
      'issued_at': order['ordered_at'],
    };
  }

  Map<String, dynamic> _draftProfile() => {
    'status': 'not_started',
    'full_name': user['name'],
    'cnic': null,
    'cnic_formatted': null,
    'mobile': user['phone'],
    'mobile_formatted': user['phone_formatted'],
    'date_of_birth': null,
    'residential_address': null,
    'city': null,
    'area': null,
    'documents': {
      for (final d in ['cnic_front', 'cnic_back', 'selfie'])
        d: {'uploaded': false, 'url': null},
    },
    'address_verified': false,
    'verified_at': null,
    'submitted_at': null,
  };

  Map<String, dynamic> _signIn() {
    signedIn = true;
    return {
      'token': '20|atompay_fake${_nextId++}',
      'token_type': 'Bearer',
      'expires_at': _day(30).toIso8601String(),
      'user': user,
    };
  }

  Map<String, dynamic> _codeSent(String idKey, String login) {
    final email = login.contains('@');
    final digits = login.replaceAll(RegExp(r'\D'), '');
    final masked = email
        ? '${login.substring(0, 1)}*****${login.substring(login.indexOf('@'))}'
        : digits.length >= 6
        ? '${digits.substring(0, 4)}*****${digits.substring(digits.length - 2)}'
        : login;
    return {
      idKey: 'fake-$idKey-${_nextId++}',
      'channel': email ? 'email' : 'whatsapp',
      'destination': masked,
      'expires_in': idKey == 'signup_id' ? 1799 : 599,
      'resend_in': 60,
    };
  }

  static const _cityNames = [
    'Ahmadpur East', 'Alipur', 'Attock', 'Bahawalnagar', 'Bahawalpur', //
    'Faisalabad', 'Gujranwala', 'Gujrat', 'Hyderabad', 'Islamabad',
    'Karachi', 'Lahore', 'Multan', 'Peshawar', 'Quetta', 'Rawalpindi',
    'Sahiwal', 'Sargodha', 'Sialkot',
  ];

  static final List<Map<String, dynamic>> _cities = [
    for (var i = 0; i < _cityNames.length; i++)
      {'id': _cityNames[i] == 'Lahore' ? 50 : 60 + i, 'name': _cityNames[i]},
  ];

  static const _areaNames = [
    'Abdalian Housing Society', 'Askari Colony', 'Bahria Town', 'Cantt', //
    'DHA 1', 'DHA 2', 'DHA 3', 'DHA 4', 'DHA 5', 'DHA 6', 'Faisal Town',
    'Garden Town', 'Gulberg', 'Iqbal Town', 'Johar Town', 'Model Town',
    'Township', 'Wapda Town',
  ];

  static final List<Map<String, dynamic>> _lahoreAreas = [
    for (var i = 0; i < _areaNames.length; i++)
      {
        'id': _areaNames[i] == 'Johar Town' ? 24 : 100 + i,
        'title': _areaNames[i],
      },
  ];

  @override
  void close({bool force = false}) {}
}

/// Sends a request to [fake] or [live] depending on [useFake].
class RoutingAdapter implements HttpClientAdapter {
  new({required this.live, required this.fake, required this.useFake});

  final HttpClientAdapter live;
  final HttpClientAdapter fake;
  final bool Function(RequestOptions options) useFake;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => (useFake(options) ? fake : live).fetch(
    options,
    requestStream,
    cancelFuture,
  );

  @override
  void close({bool force = false}) {
    live.close(force: force);
    fake.close(force: force);
  }
}

String grouped(int v) =>
    v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
