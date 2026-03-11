import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/service_repository.dart';
import '../../domain/models/service.dart';
import 'service_list_provider.dart';

final serviceDetailProvider =
    FutureProvider.family<Service, String>((ref, id) async {
  final repo = ref.watch(serviceRepositoryProvider);
  return repo.getById(id);
});

