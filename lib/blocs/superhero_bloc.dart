import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';
import 'package:superheroes/exception/api_exception.dart';
import 'package:superheroes/model/superhero.dart';


class SuperheroBloc {
  // HTTP
  http.Client? client;
  final String id;

  final superheroSubject = BehaviorSubject<Superhero>();

  StreamSubscription? requestSubscription;

  // общий доступ в bloc
  SuperheroBloc({this.client, required this.id}) {
    requestSuperhero();
  }

  // поиск на сервере
  void requestSuperhero() {
    requestSubscription?.cancel();
    // слушатель поиска
    requestSubscription = request().asStream().listen((superhero) {
      superheroSubject.add(superhero);

    }, onError: (error, stackTrace) {
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
  Stream<Superhero> observeSuperhero() => superheroSubject;

    void dispose() {
      client?.close();

      requestSubscription?.cancel();

      superheroSubject.close();
    }

}
