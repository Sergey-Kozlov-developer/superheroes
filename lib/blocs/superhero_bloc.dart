import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';
import 'package:superheroes/exception/api_exception.dart';
import 'package:superheroes/favorite_superheroes_storage.dart';
import 'package:superheroes/model/superhero.dart';

class SuperheroBloc {
  // HTTP
  http.Client? client;
  final String id;

  final superheroSubject = BehaviorSubject<Superhero>();

  final superheroPageStateSubject = BehaviorSubject<SuperheroPageState>();

  StreamSubscription? getFromFavoritesSubscription;
  StreamSubscription? requestSubscription;
  StreamSubscription? addToFavoriteSubscription;
  StreamSubscription? removeFromFavoriteSubscription;

  // общий доступ в bloc
  SuperheroBloc({this.client, required this.id}) {
    getFromFavorites();
  }

  // данные из кеша если они есть, отображать полную страницу с героем
  // без запроса с сервера. как бы нажимая на звездочку, то мы сохраняем это в кеше
  // зашли в storage и запросили id
  void getFromFavorites() {
    getFromFavoritesSubscription?.cancel();
    getFromFavoritesSubscription = FavoriteSuperheroesStorage.getInstance()
        .getSuperhero(id)
        .asStream()
        .listen(
      (superhero) {
        if (superhero != null) {
          superheroSubject.add(superhero);
          superheroPageStateSubject.add(SuperheroPageState.loaded);
        } else {
          superheroPageStateSubject.add(SuperheroPageState.loading);
        }
        // вызов requestSuperhero если данные устарели и их надо обновить
        requestSuperhero(superhero != null);
      },
      onError: (error, stackTrace) =>
          print("Error happened in requestSubscription: $error, $stackTrace"),
    );
  }

  // ИЗБРАННОЕ
  void addToFavorite() {
    final superhero = superheroSubject.valueOrNull;
    if (superhero == null) {
      print("ERROR: superhero is null");
      return;
    }
    addToFavoriteSubscription?.cancel();
    addToFavoriteSubscription = FavoriteSuperheroesStorage.getInstance()
        .addToFavorites(superhero)
        .asStream()
        .listen(
      (event) {
        print("Added to favorites: $event");
      },
      onError: (error, stackTrace) =>
          print("Error happened in requestSubscription: $error, $stackTrace"),
    );
  }

  // удаление из избранного
  void removeFromFavorites() {
    removeFromFavoriteSubscription?.cancel();
    removeFromFavoriteSubscription = FavoriteSuperheroesStorage.getInstance()
        .removeFromFavorites(id)
        .asStream()
        .listen(
      (event) {
        print("Removed from favorites: $event");
      },
      onError: (error, stackTrace) =>
          print("Error happened in removeFromFavorites: $error, $stackTrace"),
    );
  }

  Stream<bool> observeIsFavorite() =>
      FavoriteSuperheroesStorage.getInstance().observeIsFavorite(id);

  // КОНЕЦ ИЗБРАННОГО

  // поиск на сервере
  void requestSuperhero(final bool isInFavorites) {
    requestSubscription?.cancel();
    // слушатель поиска
    requestSubscription = request().asStream().listen((superhero) {
      superheroSubject.add(superhero);
      superheroPageStateSubject.add(SuperheroPageState.loaded);
    }, onError: (error, stackTrace) {
      if(!isInFavorites){
        superheroPageStateSubject.add(SuperheroPageState.error);
      }
      print("Error happened in requestSubscription: $error, $stackTrace");
    });
  }

  Future<Superhero> request() async {
    // вывод loading индикатором перед отображением результата поиска
    // HTTP
    final token = dotenv.env["SUPERHERO_TOKEN"];
    // если client null то создаем новый запрос и присваиваем его в client
    final response = await (client ??= http.Client())
        .get(Uri.parse("https://superheroapi.com/api/$token/$id"));
    // обработка ошибок от сервера
    if (response.statusCode >= 500 && response.statusCode <= 599) {
      throw ApiException("Server error happened");
    }
    if (response.statusCode >= 400 && response.statusCode <= 499) {
      throw ApiException("Client error happened");
    }
    // если нет ошибки,раскодируем пришедшие данные из сервера
    final decoded = json.decode(response.body);
    // все данные берутся из API.
    if (decoded['response'] == 'success') {
      return Superhero.fromJson(decoded);
    } else if (decoded['response'] == 'error') {
      throw ApiException("Client error happened");
    }
    // при ошибке выводим ошибку
    throw Exception("Unknown error happened");
  }

  // Stream c супергероем
  Stream<Superhero> observeSuperhero() => superheroSubject.distinct();


  Stream<SuperheroPageState> observeSuperheroPageState() => superheroPageStateSubject.distinct();

  void dispose() {
    client?.close();

    requestSubscription?.cancel();
    addToFavoriteSubscription?.cancel();
    removeFromFavoriteSubscription?.cancel();
    getFromFavoritesSubscription?.cancel();

    superheroSubject.close();
    superheroPageStateSubject.close();
  }
}

enum SuperheroPageState { loading, loaded, error }
