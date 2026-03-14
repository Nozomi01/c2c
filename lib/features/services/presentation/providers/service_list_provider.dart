import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/service_repository.dart';
import '../../../services/domain/models/service.dart' as domain;

final _firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final serviceRepositoryProvider = Provider<ServiceRepository>((ref) {
  return FirestoreServiceRepository(ref.watch(_firestoreProvider));
});

final recommendedServicesProvider =
    StreamProvider.autoDispose<List<domain.Service>>((ref) {
  final repo = ref.watch(serviceRepositoryProvider);
  return repo.watchRecommended();
});

final servicesByCategoryProvider = StreamProvider.autoDispose
    .family<List<domain.Service>, String>((ref, category) {
  final repo = ref.watch(serviceRepositoryProvider);
  return repo.watchByCategory(category);
});

