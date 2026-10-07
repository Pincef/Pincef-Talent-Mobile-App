import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talentbridge/core/network/dio_provider.dart';
import '../data/admin_repository.dart';
import '../data/models/admin_models.dart';

typedef AdminJobsQuery = ({int page, String search});
typedef AdminTicketsQuery = ({int page, String status});

final adminRepositoryProvider =
    Provider((ref) => AdminRepository(ref.watch(dioProvider)));

final adminUsersProvider = FutureProvider.autoDispose<List<AdminUserRecord>>(
  (ref) => ref.watch(adminRepositoryProvider).listUsers(),
);

final adminSubscriptionsProvider =
    FutureProvider.autoDispose<List<AdminSubscriptionRecord>>(
  (ref) => ref.watch(adminRepositoryProvider).listSubscriptions(),
);

final adminJobsProvider = FutureProvider.autoDispose
    .family<AdminPaginatedResult<AdminJobRecord>, AdminJobsQuery>(
  (ref, query) => ref.watch(adminRepositoryProvider).listJobs(
        page: query.page,
        search: query.search,
      ),
);

final adminTicketsProvider = FutureProvider.autoDispose
    .family<AdminPaginatedResult<AdminTicketRecord>, AdminTicketsQuery>(
  (ref, query) => ref.watch(adminRepositoryProvider).listTickets(
        page: query.page,
        status: query.status,
      ),
);
