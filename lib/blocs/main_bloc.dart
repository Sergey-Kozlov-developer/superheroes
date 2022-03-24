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
    // подписываемся на что происходит в currentTextSubject
    // и исходя что ввели будем менять состояние экрана
    textSubscription = currentTextSubject.listen((value) {
      // отменить предыдущий запрос поиска, отменой подписки
      searchSubscription?.cancel();
      if (value.isEmpty) {
        // если пустое значение показываем экран favorites
        stateSubject.add(MainPageState.favorites);
      } else if (value.length < minSymbols) {
        // если длина меньше трех показываем экран minSymbols
        stateSubject.add(MainPageState.minSymbols);
      } else {
        // в остальных случаях выполнить поиск на сервере
        searchForSuperheroes(value);
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
    }, onError: (error, stackTrace){
      stateSubject.add(MainPageState.loadingError);
    });
  }
  // методы для подписки из UI
  Stream<List<SuperheroInfo>> observeFavoritesSuperheroes() => favoriteSuperheroesSubject;

  Stream<List<SuperheroInfo>> observeSearchedSuperheroes() => searchedSuperheroesSubject;



  Future<List<SuperheroInfo>> search(final String text) async {
    // вывод loading индикатором перед отображением результата поиска
    await Future.delayed(Duration(seconds: 1));
    // возвращаем список по введенному запросу
    return SuperheroInfo.mocked;
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
