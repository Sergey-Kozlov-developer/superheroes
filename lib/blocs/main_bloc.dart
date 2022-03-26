import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:rxdart/subjects.dart';

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

  // общий доступ в bloc
  MainBloc() {
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

  // методы для подписки из UI
  Stream<List<SuperheroInfo>> observeFavoritesSuperheroes() =>
      favoriteSuperheroesSubject;

  Stream<List<SuperheroInfo>> observeSearchedSuperheroes() =>
      searchedSuperheroesSubject;

  Future<List<SuperheroInfo>> search(final String text) async {
    // вывод loading индикатором перед отображением результата поиска
    await Future.delayed(Duration(seconds: 1));
    // ввод без учета регистра
    // возвращаем список по введенному запросу
    return SuperheroInfo.mocked
        .where((superheroInfo) =>
            superheroInfo.name.toLowerCase().contains(text.toLowerCase()))
        .toList();
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
    favoriteSuperheroesSubject.close();
    searchedSuperheroesSubject.close();
    currentTextSubject.close();

    textSubscription?.cancel();
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
  } // переопределение, сравнивание объектов по контенту(поиск)

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
