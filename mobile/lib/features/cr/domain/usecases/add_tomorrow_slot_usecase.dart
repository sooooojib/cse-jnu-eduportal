import '../../../auth/domain/entities/user.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../repositories/cr_repository.dart';

class AddTomorrowSlotUseCase {
  final CrRepository repository;

  AddTomorrowSlotUseCase(this.repository);

  Future<void> execute({
    required User crUser,
    required ScheduleSlot slot,
  }) {
    return repository.addTomorrowClassSlot(
      crUser: crUser,
      slot: slot,
    );
  }
}
