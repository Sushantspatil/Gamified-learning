import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../domain/entities/learning_path.dart';
import '../../domain/repositories/learning_path_repository.dart';
import '../datasources/learning_path_datasource.dart';

class LearningPathRepositoryImpl implements LearningPathRepository {
  final LearningPathDatasource _datasource;
  final LocalStorageService _storage;

  LearningPathRepositoryImpl(this._datasource, this._storage);

  @override
  Future<List<LearningPath>> getLearningPaths() =>
      _datasource.getLearningPaths();

  @override
  Future<String?> getSelectedLearningPathId() async {
    return _storage.getString(StorageKeys.selectedLearningPathId);
  }

  @override
  Future<void> selectLearningPath(String id) async {
    await _storage.setString(StorageKeys.selectedLearningPathId, id);
  }
}
