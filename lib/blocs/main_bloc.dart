import 'dart:async';

import 'package:rxdart/rxdart.dart';

class MainBloc {
  // передавать данные с одного метода в другой
  // BehaviorSubject из библиотеки rxDart
  final BehaviorSubject<MainPageState> stateSubject = BehaviorSubject();

  Stream<MainPageState> observeMainPageState() => stateSubject;

  MainBloc() {
    stateSubject.add(MainPageState.noFavorites);
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

  // освобождение ресурсов, закрыть контроллер
  void dispose() {
    stateSubject.close();
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
