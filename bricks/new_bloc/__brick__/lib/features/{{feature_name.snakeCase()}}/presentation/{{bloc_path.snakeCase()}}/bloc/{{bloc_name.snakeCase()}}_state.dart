part of '{{bloc_name.snakeCase()}}_bloc.dart';

sealed
class {{bloc_name.pascalCase()}}State extends Equatable {
const {{bloc_name.pascalCase()}}State();

@override
List<Object?> get props => [];
}

class {{bloc_name.pascalCase()}}Loading extends {{bloc_name.pascalCase()}}State {}

class {{bloc_name.pascalCase()}}Success extends {{bloc_name.pascalCase()}}State {
const {{bloc_name.pascalCase()}}Success();

@override
List<Object?> get props => [];
}

class {{bloc_name.pascalCase()}}Error extends {{bloc_name.pascalCase()}}State {
final Exception exception;

const {{bloc_name.pascalCase()}}Error(this.exception);

@override
List<Object?> get props => [exception];
}
