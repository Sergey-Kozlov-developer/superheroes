import 'package:json_annotation/json_annotation.dart';
import 'package:superheroes/model/powerstats.dart';

import 'biography.dart';
import 'server_image.dart';

part 'superhero.g.dart';

@JsonSerializable()
class Superhero {
  final String id;
  final String name;
  final Biography biography;
  final ServerImage image;
  final Powerstats powerstats;

  Superhero({
    required this.id,
    required this.name,
    required this.biography,
    required this.image,
    required this.powerstats,
  });


  factory Superhero.fromJson(final Map<String, dynamic> json) =>
      _$SuperheroFromJson(json);

  Map<String, dynamic> toJson() => _$SuperheroToJson(this);

}
