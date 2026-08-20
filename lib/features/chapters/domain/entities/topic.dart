import 'package:equatable/equatable.dart';

class Topic extends Equatable {
  final String id;
  final String chapterId;
  final String title;
  final int order;
  final bool isCompleted;

  const Topic({
    required this.id,
    required this.chapterId,
    required this.title,
    required this.order,
    required this.isCompleted,
  });

  @override
  List<Object?> get props => [id, chapterId, title, order, isCompleted];
}
