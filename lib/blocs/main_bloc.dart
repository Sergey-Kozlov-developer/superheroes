import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rxdart/rxdart.dart';
import 'package:rxdart/subjects.dart';
import 'package:http/http.dart' as http;
import 'package:superheroes/exception/api_exception.dart';
import 'package:superheroes/favorite_superheroes_storage.dart';
import 'package:superheroes/model/alignment_info.dart';
import 'package:superheroes/model/superhero.dart';

class MainBloc {
  // минимальное кол-во введенных символов в поиске
  static const minSymbols = 3;

  // передавать данные с одного метода в другой
  // BehaviorSubject из библиотеки rxDart
  final BehaviorSubject<MainPageState> stateSubject = BehaviorSubject();

  // инфа о героях, котороя будет передаваться в UI
  // для поиска
  final searchedSuperheroesSubject = BehaviorSubject<List<SuperheroInfo>>();

  // что происходит в поисковой строке
  final currentTextSubject = BehaviorSubject<String>.seeded("");

  // чтобы слушать что происходит в currentTextSubject
  StreamSubscription? textSubscription;

  // слушатель поиска с сервера, вход в сеть
  StreamSubscription? searchSubscription;

  // удаление в избранном
  StreamSubscription? removeFromFavoriteSubscription;

  // HTTP
  http.Client? client;

  // общий доступ в bloc
  MainBloc({this.client}) {
    //1 подписываемся на что происходит в currentTextSubject
    // и исходя что ввели будем менять состояние экрана
    // distinct() чтобы при выборе тапом поиск лишний раз не передавалось
    // печатание и также при нажатии на крестик
    //2 комбинируем два стрима
    textSubscription =
        Rx.combineLatest2<String, List<Superhero>, MainPageStateInfo>(
      currentTextSubject.distinct().debounceTime(Duration(milliseconds: 500)),
      FavoriteSuperheroesStorage.getInstance().observeFavoriteSuperheroes(),
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

  // удаление из избранного через Dismissible
  void removeFromFavorites(final String id) {
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

  void retry() {
    final currentText = currentTextSubject.value;
    searchForSuperheroes(currentText);
  }

  // методы для подписки из UI
  /*
  обсервим в реальности супергероев которые сохраненны
  */
  Stream<List<SuperheroInfo>> observeFavoritesSuperheroes() {
    return FavoriteSuperheroesStorage.getInstance()
        .observeFavoriteSuperheroes()
        .map((superheroes) => superheroes
            .map((superhero) => SuperheroInfo.fromSuperhero(superhero))
            .toList());
  }

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
      throw ApiException("Server error happened");
    }
    if (response.statusCode >= 400 && response.statusCode <= 499) {
      throw ApiException("Client error happened");
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
        return SuperheroInfo.fromSuperhero(superhero);
      }).toList();
      return found;
    } else if (decoded['response'] == 'error') {
      if (decoded['error'] == 'character with given name not found') {
        return [];
      }
      throw ApiException("Client error happened");
    }
    // при ошибке выводим ошибку
    throw Exception("Unknown error happened");
  }

  // подписка на главный слушатель(используется везде)
  // с помощью него делаем подписки и выводы
  Stream<MainPageState> observeMainPageState() => stateSubject;

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
    searchedSuperheroesSubject.close();
    currentTextSubject.close();

    textSubscription?.cancel();
    searchSubscription?.cancel();

    removeFromFavoriteSubscription?.cancel();


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
  final String id;
  final String name;
  final String realName;
  final String imageUrl;
  final AlignmentInfo? alignmentInfo;

  const SuperheroInfo({
    required this.id,
    required this.name,
    required this.realName,
    required this.imageUrl,
    this.alignmentInfo,
  });

  factory SuperheroInfo.fromSuperhero(final Superhero superhero) {
    return SuperheroInfo(
      id: superhero.id,
      name: superhero.name,
      realName: superhero.biography.fullName,
      imageUrl: superhero.image.url,
      alignmentInfo: superhero.biography.alignmentInfo,
    );
  }

  @override
  String toString() {
    return 'SuperheroInfo{id: $id, name: $name, realName: $realName, imageUrl: $imageUrl}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuperheroInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          realName == other.realName &&
          imageUrl == other.imageUrl;

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ realName.hashCode ^ imageUrl.hashCode;

  // для получения данных из API, коллекция супергероев
  static const mocked = [
    SuperheroInfo(
      id: "70",
      name: "Batman",
      realName: "Bruce Wayne",
      imageUrl:
          "https://www.superherodb.com/pictures2/portraits/10/100/639.jpg",
    ),
    SuperheroInfo(
      id: "732",
      name: "Ironman",
      realName: "Tony Stark",
      imageUrl: "https://www.superherodb.com/pictures2/portraits/10/100/85.jpg",
    ),
    SuperheroInfo(
      id: "687",
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
