import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/courses/data/repositories/course_requirement_repository.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';

import '../../../helpers/test_database.dart';

Future<void> _seed() async {
  final db = DatabaseService.instance.database;
  await db.customStatement(
    "INSERT INTO divers (id, name, created_at, updated_at) "
    "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
  );
  await db.customStatement(
    "INSERT INTO courses (id, diver_id, name, agency, start_date, "
    "created_at, updated_at) "
    "VALUES ('course-1', 'diver-1', 'AOW', 'padi', 1000, 1000, 1000)",
  );
}

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('courseProgressProvider resolves progress and refreshes after a '
      'requirement write', () async {
    await _seed();
    final repository = CourseRequirementRepository();
    await repository.createRequirement(
      courseId: 'course-1',
      name: 'Deep adventure dive',
      kind: RequirementKind.dive,
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Keep the provider actively listened: invalidateSelfWhen defers
    // refreshes while a provider is paused (no listeners), which is the
    // Riverpod 3 auto-pause state a bare container.read leaves it in.
    final subscription = container.listen(
      courseProgressProvider('course-1'),
      (_, _) {},
    );
    addTearDown(subscription.close);

    final progress = await container.read(
      courseProgressProvider('course-1').future,
    );
    expect(progress.totalCount, 1);
    expect(progress.satisfiedCount, 0);

    await repository.createRequirement(
      courseId: 'course-1',
      name: 'Knowledge development',
      kind: RequirementKind.checklist,
    );
    // invalidateSelfWhen listens to a table stream; give it a tick.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final refreshed = await container.read(
      courseProgressProvider('course-1').future,
    );
    expect(refreshed.totalCount, 2);
  });
}
