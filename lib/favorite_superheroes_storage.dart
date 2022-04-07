import 'dart:convert';

import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superheroes/model/superhero.dart';

class FavoriteSuperheroesStorage {
  static const _key = "favorite_superheroes";

  final updater = PublishSubject<Null>();

  static FavoriteSuperheroesStorage? _instance;

  factory FavoriteSuperheroesStorage.getInstance() =>
      _instance ??= FavoriteSuperheroesStorage._internal();

  FavoriteSuperheroesStorage._internal();


  // метод добавления в избранное
  Future<bool> addToFavorites(final Superhero superhero) async {
    // получаем сырой список героев, листы со стрингами
    final rawSuperheroes = await _getRawSuperheroes();
    // сохраняем нового героя
    rawSuperheroes.add(json.encode(superhero.toJson()));
    // // прокидываем событие об изменении хранилища
    return _setRawSuperheroes(rawSuperheroes);
  }

  // удаление по id
  Future<bool> removeFromFavorites(final String id) async {
    // получаем супергерой по id, сырой список превратили в стринг
    final superheroes = await _getSuperheroes();
    // сохраняем нового героя
    superheroes.removeWhere((superhero) => superhero.id == id);
    // сохраняем
    return _setSuperheroes(superheroes);
  }

  /* вспомогательные методы сохранения */

  Future<List<String>> _getRawSuperheroes() async {
    final sp = await SharedPreferences.getInstance();
    // получаем сырой список героев, листы со стрингами
    return sp.getStringList(_key) ?? [];
  }

  Future<bool> _setRawSuperheroes(final List<String> rawSuperheroes) async {
    final sp = await SharedPreferences.getInstance();
    // прокидываем событие об изменении хранилища
    final result = sp.setStringList(_key, rawSuperheroes);
    updater.add(null);
    return result;
  }

  /* КОНЕЦ методы сохранения */

  /* вспомогательные методы удаления */
  Future<List<Superhero>> _getSuperheroes() async {
    // получаем сырой список героев, листы со стрингами
    final rawSuperheroes = await _getRawSuperheroes();
    // получаем супергерой по id, сырой список превратили в стринг
    return rawSuperheroes
        .map((rawSuperhero) => Superhero.fromJson(json.decode(rawSuperhero)))
        .toList();
  }

  Future<bool> _setSuperheroes(final List<Superhero> superheroes) async {
    final rawSuperheroes = superheroes
        .map((superhero) => json.encode(superhero.toJson()))
        .toList();
    // сохраняем
    return _setRawSuperheroes(rawSuperheroes);
  }

  /* КОНЕЦ методы удаления */

  // сохранение списка избранного в локальном хранилище
  // и его отображение на экране
  Future<Superhero?> getSuperhero(final String id) async {
    // получаем супергероя
    final superheroes = await _getSuperheroes();
    for (final superhero in superheroes) {
      if (superhero.id == id) {
        return superhero;
      }
    }
    return null;
  }

  // отображение всего списка избранного на главном экране
  // при изменении данных запашивать данные у shared_Preferences
  // подписка на супергероев
  Stream<List<Superhero>> observeFavoriteSuperheroes() async* {
    // возвращаем значение в Stream подождав, от сюда _getSuperheroes()
    yield await _getSuperheroes();
    await for (final _ in updater) {
      // приходит инфа в updater
      // отдаем текущее состояние хранилища
      yield await _getSuperheroes();
    }
  }

  // для значка избранного. Есть ли сейчас этот герой в избранном или нет
  Stream<bool> observeIsFavorite(final String id) {
    return observeFavoriteSuperheroes().map(
        (superheroes) => superheroes.any((superhero) => superhero.id == id));
  }
}
