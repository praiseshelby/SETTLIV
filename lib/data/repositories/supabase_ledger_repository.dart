import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../models/iou_note.dart';
import '../models/person.dart';
import '../models/recurring_template.dart';
import '../models/savings_goal.dart';
import '../models/settlement.dart';
import 'persistent_app_repository.dart';

@immutable
class LedgerSyncState {
  final bool isSyncing;
  final bool isOffline;
  final bool isSettingUpAccount;
  final bool setupFailed;
  final DateTime? lastSyncedAt;
  final String? errorMessage;

  const LedgerSyncState({
    this.isSyncing = false,
    this.isOffline = false,
    this.isSettingUpAccount = false,
    this.setupFailed = false,
    this.lastSyncedAt,
    this.errorMessage,
  });

  LedgerSyncState copyWith({
    bool? isSyncing,
    bool? isOffline,
    bool? isSettingUpAccount,
    bool? setupFailed,
    DateTime? lastSyncedAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LedgerSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      isOffline: isOffline ?? this.isOffline,
      isSettingUpAccount: isSettingUpAccount ?? this.isSettingUpAccount,
      setupFailed: setupFailed ?? this.setupFailed,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Per-user PostgreSQL repository backed by Supabase and UID-namespaced
/// local cache in SharedPreferences.
class SupabaseLedgerRepository extends PersistentAppRepository {
  final SupabaseClient _client;
  final String uid;
  final VoidCallback? onRemoteChange;
  final void Function(LedgerSyncState)? onSyncStateChanged;

  RealtimeChannel? _channel;
  LedgerSyncState _syncState = const LedgerSyncState();

  SupabaseLedgerRepository({
    required SupabaseClient client,
    required this.uid,
    Person? initialUser,
    SharedPreferences? prefs,
    DateTime Function()? clock,
    this.onRemoteChange,
    this.onSyncStateChanged,
  })  : _client = client,
        super(
          prefs: prefs,
          clock: clock,
          storageKey: 'settliv_ledger_uid_$uid',
          startEmpty: true,
          initialUser: initialUser,
        );

  LedgerSyncState get syncState => _syncState;

  void _updateSync(LedgerSyncState next) {
    _syncState = next;
    onSyncStateChanged?.call(next);
  }

  Future<void> initialize() async {
    _updateSync(_syncState.copyWith(isSyncing: true, clearError: true));
    try {
      final settings = await _client
          .from('user_settings')
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      if (settings == null || settings['seeded_at_ms'] == null) {
        _updateSync(
          _syncState.copyWith(
            isSettingUpAccount: true,
            setupFailed: false,
            clearError: true,
          ),
        );
        await _initializeEmptyNewAccount();
      } else {
        await refreshFromRemote();
      }

      _subscribeRealtime();
      _updateSync(
        _syncState.copyWith(
          isSyncing: false,
          isOffline: false,
          isSettingUpAccount: false,
          setupFailed: false,
          lastSyncedAt: DateTime.now(),
          clearError: true,
        ),
      );
    } catch (_) {
      _updateSync(
        _syncState.copyWith(
          isSyncing: false,
          isOffline: true,
          isSettingUpAccount: false,
          setupFailed: _syncState.isSettingUpAccount,
          errorMessage: 'Offline — showing cached data',
        ),
      );
    }
  }

  Future<void> _initializeEmptyNewAccount() async {
    await startFresh();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final peopleRows = getPeople()
        .map((p) => {
              'user_id': uid,
              'id': p.id,
              'name': p.name,
              'upi_id': p.upiId,
              'phone': p.phone,
              'is_current_user': p.id == currentUserId,
              'schema_version': PersistentAppRepository.schemaVersion,
              'updated_at_ms': nowMs,
            })
        .toList();

    final groupRows = getGroups()
        .map((g) => {
              'user_id': uid,
              'id': g.id,
              'name': g.name,
              'type': g.type.name,
              'cover_type': g.coverType.name,
              'member_ids': g.memberIds,
              'is_personal': g.isPersonal,
              'is_pinned': g.isPinned,
              'is_archived': g.isArchived,
              'default_split_mode': g.defaultSplitMode,
              'trip_start_ms': g.startDate?.millisecondsSinceEpoch,
              'trip_end_ms': g.endDate?.millisecondsSinceEpoch,
              'schema_version': PersistentAppRepository.schemaVersion,
              'updated_at_ms': nowMs,
            })
        .toList();

    await _upsertChunked('people', peopleRows);
    await _upsertChunked('groups', groupRows);
    await _client.from('user_settings').upsert({
      'user_id': uid,
      'seeded_at_ms': nowMs,
      'seed_version': PersistentAppRepository.seedVersion,
      'schema_version': PersistentAppRepository.schemaVersion,
      'updated_at_ms': nowMs,
    });
    onRemoteChange?.call();
  }

  Future<void> _seedNewAccount() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final peopleRows = getPeople()
        .map((p) => {
              'user_id': uid,
              'id': p.id,
              'name': p.name,
              'upi_id': p.upiId,
              'phone': p.phone,
              'is_current_user': p.id == currentUserId,
              'schema_version': PersistentAppRepository.schemaVersion,
              'updated_at_ms': nowMs,
            })
        .toList();

    final groupRows = getGroups()
        .map((g) => {
              'user_id': uid,
              'id': g.id,
              'name': g.name,
              'type': g.type.name,
              'cover_type': g.coverType.name,
              'member_ids': g.memberIds,
              'is_personal': g.isPersonal,
              'is_pinned': g.isPinned,
              'is_archived': g.isArchived,
              'default_split_mode': g.defaultSplitMode,
              'trip_start_ms': g.startDate?.millisecondsSinceEpoch,
              'trip_end_ms': g.endDate?.millisecondsSinceEpoch,
              'schema_version': PersistentAppRepository.schemaVersion,
              'updated_at_ms': nowMs,
            })
        .toList();

    final expenseRows = getAllExpenses()
        .map((e) => _expenseToRow(e, nowMs))
        .toList();

    final settlementRows = getAllSettlements()
        .map((s) => _settlementToRow(s, nowMs))
        .toList();

    final goalRows = getSavingsGoals()
        .map((g) => {
              'user_id': uid,
              'id': g.id,
              'name': g.name,
              'target_paise': g.targetPaise,
              'saved_paise': g.savedPaise,
              'target_date_ms': g.targetDate?.millisecondsSinceEpoch,
              'created_at_ms': g.createdAt.millisecondsSinceEpoch,
              'schema_version': PersistentAppRepository.schemaVersion,
              'updated_at_ms': nowMs,
            })
        .toList();

    await _upsertChunked('people', peopleRows);
    await _upsertChunked('groups', groupRows);
    await _upsertChunked('expenses', expenseRows);
    await _upsertChunked('settlements', settlementRows);
    await _upsertChunked('goals', goalRows);

    await _client.from('user_settings').upsert({
      'user_id': uid,
      'seeded_at_ms': nowMs,
      'seed_version': PersistentAppRepository.seedVersion,
      'schema_version': PersistentAppRepository.schemaVersion,
      'updated_at_ms': nowMs,
    });
  }

  Future<void> _upsertChunked(
    String table,
    List<Map<String, dynamic>> rows, {
    int chunkSize = 20,
  }) async {
    for (int i = 0; i < rows.length; i += chunkSize) {
      final end = (i + chunkSize < rows.length) ? i + chunkSize : rows.length;
      await _client.from(table).upsert(rows.sublist(i, end));
    }
  }

  Future<void> refreshFromRemote() async {
    final results = await Future.wait([
      _client.from('people').select(),
      _client.from('groups').select(),
      _client.from('expenses').select(),
      _client.from('settlements').select(),
      _client.from('ious').select().eq('user_id', uid),
      _client.from('recurring').select(),
      _client.from('goals').select().eq('user_id', uid),
    ]);

    final people = (results[0] as List)
        .map((r) => Person(
              id: r['id'] as String,
              name: r['name'] as String,
              upiId: r['upi_id'] as String?,
              phone: r['phone'] as String?,
              linkedUserId: r['linked_user_id'] as String?,
            ))
        .toList();

    final groups = (results[1] as List)
        .map((r) => Group.fromJson({
              'id': r['id'],
              'name': r['name'],
              'type': r['type'],
              'coverThemeIndex': r['cover_type'] == 'flatmates'
                  ? 0
                  : (r['cover_type'] == 'goaTrip' ? 1 : 2),
              'memberIds': r['member_ids'],
              'isPersonal': r['is_personal'],
              'isPinned': r['is_pinned'],
              'isArchived': r['is_archived'],
              'defaultSplitMode': r['default_split_mode'],
              if (r['trip_start_ms'] != null)
                'startDate': DateTime.fromMillisecondsSinceEpoch(
                        (r['trip_start_ms'] as num).toInt())
                    .toIso8601String(),
              if (r['trip_end_ms'] != null)
                'endDate': DateTime.fromMillisecondsSinceEpoch(
                        (r['trip_end_ms'] as num).toInt())
                    .toIso8601String(),
            }).copyWith(
              ownerId: r['owner_id'] as String?,
              joinCode: r['join_code'] as String?,
              joinCodeEnabled: (r['join_code_enabled'] as bool?) ?? true,
            ))
        .toList();

    final expenses = (results[2] as List)
        .map((r) => Expense.fromJson({
              'id': r['id'],
              'groupId': r['group_id'],
              'title': r['title'],
              'totalPaise': (r['total_paise'] as num?)?.toInt() ?? 0,
              'paidBy': r['paid_by'],
              'payers': r['payers'],
              'splitMode': r['split_mode'],
              'shares': r['shares'],
              'category': r['category'],
              'date': DateTime.fromMillisecondsSinceEpoch(
                      (r['date_ms'] as num).toInt())
                  .toIso8601String(),
              'note': r['notes'],
              if (r['deleted_at_ms'] != null)
                'deletedAt': DateTime.fromMillisecondsSinceEpoch(
                        (r['deleted_at_ms'] as num).toInt())
                    .toIso8601String(),
              'revisions': r['revisions'],
            }))
        .toList();

    final settlements = (results[3] as List)
        .map((r) => Settlement.fromJson({
              'id': r['id'],
              'groupId': r['group_id'],
              'from': r['from_id'],
              'to': r['to_id'],
              'paise': r['paise'],
              'method': r['method'],
              'date': DateTime.fromMillisecondsSinceEpoch(
                      (r['date_ms'] as num).toInt())
                  .toIso8601String(),
              if (r['deleted_at_ms'] != null)
                'deletedAt': DateTime.fromMillisecondsSinceEpoch(
                        (r['deleted_at_ms'] as num).toInt())
                    .toIso8601String(),
              'note': r['note'],
            }))
        .toList();

    if (people.isNotEmpty && groups.isNotEmpty) {
      replaceAllState(
        people: people,
        groups: groups,
        expenses: expenses,
        settlements: settlements,
        ious: (results[4] as List)
            .map((r) => IouNote.fromJson({
                  'id': r['id'],
                  'direction': r['direction'],
                  'personName': r['person_name'],
                  'phone': r['phone'],
                  'amountPaise': (r['amount_paise'] as num).toInt(),
                  'note': r['note'],
                  if (r['due_date_ms'] != null)
                    'dueDate': DateTime.fromMillisecondsSinceEpoch(
                            (r['due_date_ms'] as num).toInt())
                        .toIso8601String(),
                  'date': DateTime.fromMillisecondsSinceEpoch(
                          (r['created_at_ms'] as num).toInt())
                      .toIso8601String(),
                  'payments': r['payments'],
                  if (r['deleted_at_ms'] != null)
                    'deletedAt': DateTime.fromMillisecondsSinceEpoch(
                            (r['deleted_at_ms'] as num).toInt())
                        .toIso8601String(),
                }))
            .toList(),
        recurring: (results[5] as List)
            .map((r) => RecurringTemplate.fromJson({
                  'id': r['id'],
                  'groupId': r['group_id'],
                  'description': r['title'],
                  'totalPaise': (r['amount_paise'] as num?)?.toInt() ?? 0,
                  'payers': [
                    {
                      'personId': r['paid_by'],
                      'paise': (r['amount_paise'] as num?)?.toInt() ?? 0,
                    }
                  ],
                  'splitMode': r['split_mode'],
                  'participants': (r['shares'] as Map?)?.keys.toList() ?? const [],
                  'category': r['category'],
                  'frequency': r['frequency'],
                  'startDate': DateTime.fromMillisecondsSinceEpoch(
                          (r['next_due_ms'] as num).toInt())
                      .toIso8601String(),
                  if (r['last_generated_ms'] != null)
                    'lastGeneratedDate': DateTime.fromMillisecondsSinceEpoch(
                            (r['last_generated_ms'] as num).toInt())
                        .toIso8601String(),
                  'isPaused': r['is_paused'],
                }))
            .toList(),
        goals: (results[6] as List)
            .map((r) => SavingsGoal.fromJson({
                  'id': r['id'],
                  'name': r['name'],
                  'targetPaise': r['target_paise'],
                  'savedPaise': r['saved_paise'],
                  if (r['target_date_ms'] != null)
                    'targetDate': DateTime.fromMillisecondsSinceEpoch(
                            (r['target_date_ms'] as num).toInt())
                        .toIso8601String(),
                  'createdAt': DateTime.fromMillisecondsSinceEpoch(
                          (r['created_at_ms'] as num).toInt())
                      .toIso8601String(),
                }))
            .toList(),
      );
      onRemoteChange?.call();
    }
  }

  void _subscribeRealtime() {
    _channel?.unsubscribe();
    _channel = _client.channel('ledger_$uid')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'expenses',
        callback: (_) => refreshFromRemote().catchError((_) {}),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'settlements',
        callback: (_) => refreshFromRemote().catchError((_) {}),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'groups',
        callback: (_) => refreshFromRemote().catchError((_) {}),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'group_members',
        callback: (_) => refreshFromRemote().catchError((_) {}),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'group_invites',
        callback: (_) => onRemoteChange?.call(),
      )
      ..subscribe();
  }

  Map<String, dynamic> _expenseToRow(Expense e, int nowMs) => {
        'user_id': uid,
        'id': e.id,
        'group_id': e.groupId,
        'title': e.title,
        'total_paise': e.totalPaise,
        'paid_by': e.paidBy,
        'payers': e.payers.map((p) => p.toJson()).toList(),
        'split_mode': e.splitMode.name,
        'shares': e.shares,
        'category': e.category.name,
        'date_ms': e.date.millisecondsSinceEpoch,
        'notes': e.note,
        'is_recurring': false,
        'deleted_at_ms': e.deletedAt?.millisecondsSinceEpoch,
        'revisions': e.revisions.map((r) => r.toJson()).toList(),
        'schema_version': PersistentAppRepository.schemaVersion,
        'updated_at_ms': nowMs,
      };

  Map<String, dynamic> _settlementToRow(Settlement s, int nowMs) => {
        'user_id': uid,
        'id': s.id,
        'group_id': s.groupId,
        'from_id': s.from,
        'to_id': s.to,
        'paise': s.paise,
        'method': s.method.name,
        'date_ms': s.date.millisecondsSinceEpoch,
        'deleted_at_ms': s.deletedAt?.millisecondsSinceEpoch,
        'note': s.note,
        'schema_version': PersistentAppRepository.schemaVersion,
        'updated_at_ms': nowMs,
      };

  void _syncMutation(Future<void> Function() op) {
    op().then((_) {
      _updateSync(
        _syncState.copyWith(
          isOffline: false,
          lastSyncedAt: DateTime.now(),
          clearError: true,
        ),
      );
    }).catchError((_) {
      _updateSync(
        _syncState.copyWith(
          isOffline: true,
          errorMessage: 'Connection required to save changes to your account',
        ),
      );
    });
  }

  @override
  void updateCurrentUser({String? name, String? upiId}) {
    super.updateCurrentUser(name: name, upiId: upiId);
    final updated = currentUser;
    if (updated != null) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      _syncMutation(() => _client.from('people').upsert({
            'user_id': uid,
            'id': updated.id,
            'name': updated.name,
            'upi_id': updated.upiId,
            'phone': updated.phone,
            'is_current_user': true,
            'schema_version': PersistentAppRepository.schemaVersion,
            'updated_at_ms': nowMs,
          }));
    }
  }

  @override
  void addExpense(Expense expense) {
    super.addExpense(expense);
    _syncMutation(() => _client.from('expenses').upsert(_expenseToRow(expense, DateTime.now().millisecondsSinceEpoch)));
  }

  @override
  void updateExpense(Expense expense) {
    super.updateExpense(expense);
    _syncMutation(() => _client.from('expenses').upsert(_expenseToRow(expense, DateTime.now().millisecondsSinceEpoch)));
  }

  @override
  void deleteExpense(String id) {
    super.deleteExpense(id);
    final exp = getExpense(id);
    if (exp != null) {
      _syncMutation(() => _client.from('expenses').upsert(_expenseToRow(exp, DateTime.now().millisecondsSinceEpoch)));
    }
  }

  @override
  void restoreExpense(String id) {
    super.restoreExpense(id);
    final exp = getExpense(id);
    if (exp != null) {
      _syncMutation(() => _client.from('expenses').upsert(_expenseToRow(exp, DateTime.now().millisecondsSinceEpoch)));
    }
  }

  @override
  void addSettlement(Settlement settlement) {
    super.addSettlement(settlement);
    _syncMutation(() => _client.from('settlements').upsert(_settlementToRow(settlement, DateTime.now().millisecondsSinceEpoch)));
  }

  @override
  void deleteSettlement(String id) {
    super.deleteSettlement(id);
    _syncMutation(() => _client.rpc('rpc_delete_settlements', params: {'p_ids': [id]}));
  }

  Future<void> addSettlementsAtomic(List<Settlement> settlements) async {
    for (final s in settlements) {
      super.addSettlement(s);
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final rows = settlements.map((s) => _settlementToRow(s, nowMs)).toList();
    _syncMutation(() => _client.rpc('rpc_insert_settlements', params: {'p_rows': rows}));
  }

  @override
  void addGroup(Group group) {
    super.addGroup(group);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _syncMutation(() async {
      await _client.from('groups').upsert({
        'user_id': uid,
        'owner_id': group.ownerId ?? uid,
        'id': group.id,
        'name': group.name,
        'type': group.type.name,
        'cover_type': group.coverType.name,
        'member_ids': group.memberIds,
        'is_personal': group.isPersonal,
        'is_pinned': group.isPinned,
        'is_archived': group.isArchived,
        'default_split_mode': group.defaultSplitMode,
        'trip_start_ms': group.startDate?.millisecondsSinceEpoch,
        'trip_end_ms': group.endDate?.millisecondsSinceEpoch,
        'schema_version': PersistentAppRepository.schemaVersion,
        'updated_at_ms': nowMs,
      });
      if (!group.isPersonal) {
        try {
          await _client.from('group_members').upsert({
            'group_id': group.id,
            'user_id': uid,
            'role': 'owner',
          });
        } catch (_) {}
      }
    });
  }

  void dispose() {
    _channel?.unsubscribe();
  }
}
