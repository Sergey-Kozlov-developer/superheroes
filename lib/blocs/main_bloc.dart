import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rxdart/rxdart.dart';
import 'package:rxdart/subjects.dart';
import 'package:http/http.dart' as http;
import 'package:superheroes/exception/api_exception.dart';
import 'package:superheroes/model/superhero.dart';

class MainBloc {
  // минимальное кол-во введенных символов в поиске
  static const minSymbols = 3;

  // передавать данные с одного метода в другой
  // BehaviorSubject из библиотеки rxDart
  final BehaviorSubject<MainPageState> stateSubject = BehaviorSubject();

  // инфа о героях, котороя будет передаваться в UI
  // Для избранного
  final favoriteSuperheroesSubject =
      BehaviorSubject<List<SuperheroInfo>>.seeded(SuperheroInfo.mocked);

  // для поиска
  final searchedSuperheroesSubject = BehaviorSubject<List<SuperheroInfo>>();

  // что происходит в поисковой строке
  final currentTextSubject = BehaviorSubject<String>.seeded("");

  // чтобы слушать что происходит в currentTextSubject
  StreamSubscription? textSubscription;

  // слушатель поиска с сервера, вход в сеть
  StreamSubscription? searchSubscription;

  // HTTP
  http.Client? client;
  // общий доступ в bloc
  MainBloc({this.client}) {
    stateSubject.add(MainPageState.noFavorites);
    //1 подписываемся на что происходит в currentTextSubject
    // и исходя что ввели будем менять состояние экрана
    // distinct() чтобы при выборе тапом поиск лишний раз не передавалось
    // печатание и также при нажатии на крестик
    //2 комбинируем два стрима
    textSubscription =
        Rx.combineLatest2<String, List<SuperheroInfo>, MainPageStateInfo>(
      currentTextSubject.distinct().debounceTime(Duration(milliseconds: 500)),
      favoriteSuperheroesSubject,
      (searchedText, favorites) =>
          MainPageStateInfo(searchedText, favorites.isNotEmpty),
    ).listen((value) {
      // отменить предыдущий запрос поиска, отменой подписки
      searchSubscription?.cancel();
      if (value.searchText.isEmpty) {
        if (value.haveFavorites) {
          // если пустое значение показываем экран favorites
          stateSubject.add(MainPageState.favorites);
        } else {
          stateSubject.add(MainPageState.noFavorites);
        }
      } else if (value.searchText.length < minSymbols) {
        // если длина меньше трех показываем экран minSymbols
        stateSubject.add(MainPageState.minSymbols);
      } else {
        // в остальных случаях выполнить поиск на сервере
        searchForSuperheroes(value.searchText);
      }
    });
  }

  // поиск на сервере
  void searchForSuperheroes(final String text) {
    // в начале поиска добавим MainPageState.loading
    stateSubject.add(MainPageState.loading);
    // слушатель поиска
    searchSubscription = search(text).asStream().listen((searchResults) {
      if (searchResults.isEmpty) {
        stateSubject.add(MainPageState.nothingFound);
      } else {
        searchedSuperheroesSubject.add(searchResults);
        stateSubject.add(MainPageState.searchResults);
      }
    }, onError: (error, stackTrace) {
      stateSubject.add(MainPageState.loadingError);
    });
  }

  void retry() {
    final currentText = currentTextSubject.value;
    searchForSuperheroes(currentText);
  }

  // методы для подписки из UI
  Stream<List<SuperheroInfo>> observeFavoritesSuperheroes() =>
      favoriteSuperheroesSubject;

  Stream<List<SuperheroInfo>> observeSearchedSuperheroes() =>
      searchedSuperheroesSubject;

  Future<List<SuperheroInfo>> search(final String text) async {
    // вывод loading индикатором перед отображением результата поиска
    // HTTP
    final token = dotenv.env["SUPERHERO_TOKEN"];
    // если client null то создаем новый запрос и присваиваем его в client
    final response = await (client ??= http.Client())
        .get(Uri.parse("https://superheroapi.com/api/$token/search/$text"));

    // обработка ошибок от сервера
    if (response.statusCode >= 500 && response.statusCode <= 599) {
      throw ApiException("Server error hapened");
    }
    if (response.statusCode >= 400 && response.statusCode <= 499) {
      throw ApiException("Client error hapened");
    }
    // раскодируем пришедшие данные из сервера
    final decoded = json.decode(response.body);
    print(decoded);

    // все данные берутся из API.
    if (decoded['response'] == 'success') {
      final List<dynamic> results = decoded['results'];
      final List<Superhero> superheroes = results
          .map((rawSuperhero) => Superhero.fromJson(rawSuperhero))
          .toList();
      final List<SuperheroInfo> found = superheroes.map((superhero) {
        return SuperheroInfo(
          name: superhero.name,
          realName: superhero.biography.fullName,
          imageUrl: superhero.image.url,
        );
      }).toList();
      return found;
    } else if (decoded['response'] == 'error') {
      if (decoded['error'] == 'character with given name not found') {
        return [];
      }
      throw ApiException("Client error hapened");
    }
    // при ошибке выводим ошибку
    throw Exception("Unknown error hapened");
  }

  // ввод без учета регистра
  // возвращаем список по введенному запросу
  // в этом нет необходимости при созданном сетевом запросе
  // return SuperheroInfo.mocked
  //     .where((superheroInfo) =>
  //         superheroInfo.name.toLowerCase().contains(text.toLowerCase()))
  //     .toList();

  // подписка на главный слушатель(используется везде)
  // с помощью него делаем подписки и выводы
  Stream<MainPageState> observeMainPageState() => stateSubject;

  void removeFavorite() {
    final List<SuperheroInfo> currentFavorites =
        favoriteSuperheroesSubject.value;
    if (currentFavorites.isNotEmpty) {
      favoriteSuperheroesSubject.add(SuperheroInfo.mocked);
    } else {
      favoriteSuperheroesSubject
          .add(currentFavorites.sublist(0, currentFavorites.length - 1));
    }
  }

  // обработка нажатия кнопки NEXT STATE in main_page
  void nextState() {
    // add new value to stateController
    // чтобы получить след state
    final currentState = stateSubject.value;
    final nextState = MainPageState.values[
        (MainPageState.values.indexOf(currentState) + 1) %
            MainPageState.values.length];
    stateSubject.add(nextState);
  }

  // связываем TextField
  void updateText(final String? text) {
    currentTextSubject.add(text ?? "");
  }

  // освобождение ресурсов, закрыть контроллер
  void dispose() {
    stateSubject.close();
    favoriteSuperheroesSubject.close();
    searchedSuperheroesSubject.close();
    currentTextSubject.close();

    textSubscription?.cancel();

    client?.close();
  }
}

enum MainPageState {
  noFavorites,
  minSymbols,
  loading,
  nothingFound,
  loadingError,
  searchResults,
  favorites,
}

// создание модели для супегероев
class SuperheroInfo {
  final String name;
  final String realName;
  final String imageUrl;

  const SuperheroInfo({
    required this.name,
    required this.realName,
    required this.imageUrl,
  });

  @override
  String toString() {
    return 'SuperheroInfo{name: $name, realName: $realName, imageUrl: $imageUrl}';
  }

  // переопределение, сравнивание объектов по контенту(поиск)

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuperheroInfo &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          realName == other.realName &&
          imageUrl == other.imageUrl;

  @override
  int get hashCode => name.hashCode ^ realName.hashCode ^ imageUrl.hashCode;

  // для получения данных из API, коллекция супергероев
  static const mocked = [
    SuperheroInfo(
      name: "Batman",
      realName: "Bruce Wayne",
      imageUrl:
          "https://www.superherodb.com/pictures2/portraits/10/100/639.jpg",
    ),
    SuperheroInfo(
      name: "Ironman",
      realName: "Tony Stark",
      imageUrl: "https://www.superherodb.com/pictures2/portraits/10/100/85.jpg",
    ),
    SuperheroInfo(
      name: "Venom",
      realName: "Eddie Brock",
      imageUrl: "https://www.superherodb.com/pictures2/portraits/10/100/22.jpg",
    ),
  ];
}

class MainPageStateInfo {
  final String searchText;
  final bool haveFavorites;

  const MainPageStateInfo(this.searchText, this.haveFavorites);

  @override
  String toString() {
    return 'MainPageStateInfo{searchText: $searchText, haveFavorites: $haveFavorites}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MainPageStateInfo &&
          runtimeType == other.runtimeType &&
          searchText == other.searchText &&
          haveFavorites == other.haveFavorites;

  @override
  int get hashCode => searchText.hashCode ^ haveFavorites.hashCode;
}
