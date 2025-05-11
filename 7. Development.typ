#import "thesis-base.typ": *
#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.1": *
#import "@preview/curryst:0.5.1": rule, prooftree

#show: codly-init.with()
#codly(languages: codly-languages, breakable: true)

#show figure.where(kind: raw): it => [
  #show raw.where(lang: "DSL"): it_r => [
    #show regex("\b(object|func|var|return|if|else|intrinsic|new|true|false|package|import|)\b") : keyword => text(weight: "bold", fill: blue, keyword)
    #show regex("\".+\"") : keyword => text(fill: rgb("#067D17"), keyword)
    #show regex("/\*.+\*/") : keyword => text(fill: rgb("#6d6d6d"), keyword)
    #it_r
  ]

  #it
]

#chapter(3, "Разработка и реализация языка и транслятора")

== Синтаксис и семантика

Данный раздел содержит описание синтаксиса и семантики разрабатываемого языка. Каждый из подразделов посвящён конкретной языковой возможности и приводит, при необходимости, синтаксическое, семантическое описание, а также правила типизации. 

Правила описания синтаксиса представлены с помощью текста, похожего на BNF. В них в угловых скобках указаны имена правил, знак `?` указывает на опциональность терма, `*` указывает произвольное количество повторений терма, `+` указывает, что терм может повторяться больше одного раза, а `|` используется как разделитель между правилами в слечае, когда применимо любое из списка. Идентификаторы, указанные без угловых скобок или в двойных кавычках, обозначают сам идентификатор.



=== Объявления верхнего уровня

Объявления верхнего уровня описывают структуру файла с кодом на разрабатываемом языке. Он состоит из опционального указания имени пакета, за которым идёт произвольное число верхоуровневых объявлений. Соответствующие синтаксические правила приведены на Рисунке @syntax-top-level.

#syntax-rule(
  "Синтаксические правила структуры файла",
  "syntax-top-level"
)[
```
<file>         ::= 
                <packageDecl>? <topLevelDecl>*;

<topLevelDecl> ::=
                ...
```
]

Правило _\<file\>_ описывает структуру всего файла с кодом на разрабатываемом DSL. Правило _\<topLevelDecl\>_ содержит с себе все определения для верхоуровневых сущностей. Они будут рассмотрены далее.

=== Пакеты

Пакеты (ключевое слово _package_) позволяют определить имя пакета в описываемой библиотеке. Они задают имя пакета, которое также может быть использовано для импортирования (ключевое слово _import_). Соответствующие синтаксические правила приведены на Рисунке @syntax-packages.

#syntax-rule(
  "Синтаксические правила объявления и подклчения пакетов",
  "syntax-packages"
)[
```
<packageDecl>  ::=
                package <string> ";";
       
<topLevelDecl> ::=
                ...
                | import <string> ";"   
                ...
```
]

Объявление пакета является опциональным. Если оно не указано, будет использовано имя пакета из имени файла. Это поведение было оставлено для сохранения совместимости со старым механизмом модулей в расширениях PT JSA. Из синтаксических правил на Рисунке @syntax-packages следует, что не допускается больше одного такого объявление, а также то что оно должно быть первым. 

=== Объекты

Объекты используются для моделирования таких сущностей библиотек как классы, объекты и структуры. Синтаксические правила приведены на Рисунке @syntax-obj.

#syntax-rule(
  "Синтаксические правила для функций",
  "syntax-obj"
)[
```
<topLevelDecl> ::=
                ...
                | <objectDecl>
                ...
         
<objectDecl>   ::= 
             <annotation>* 'object' <ID> '{' <objectBody> '}';

<objectBody>   ::= 
                <objectBodyStatement>*;

<objectBodyStatement> ::=
                       ...
```
]

Объекты являются контейнерами для функций и полей, которые будут рассмотрены далее.

=== Функции

Функции в DSL позволяют описывать сигнатуру и поведение функций из описываемого кода. Их синтаксические правила представлены на Рисунке @syntax-func.

#syntax-rule(
  "Синтаксические правила для функций",
  "syntax-func"
)[
```
<topLevelDecl> ::=
                ...
                | <funcDecl>
                ...

                
<funcDecl>   ::=
              <annotation>* 
              'intrinsic'? 'func' <ID> '(' <args> ')' (':' <ID>)? 
              ('{' <statementsBlock> '}')?

<args>       ::=
              <arg>? (',' <arg>)* ','?;

<arg>        ::=
              <ID> (':' <ID>) ('=' <expression>)?;

              
<statementsBlock> ::=
                   <statement>*;

<statement>       ::=
                   ...
                
```
]

Определение функции содержит её имя, список аргументов (возможно, пустой), опциональный возвращаемый тип и тело. В случае отсутствия указания возвращаемого типа, предполагается неявный тип _None_, обозначающий, что функция не возвращает значение.

Модификатор `intrinsic` позволяет опускать тело функции. Это необходимо для:
- специальной поддержки некоторых функций в трансляторе;
- возможности реализации функций на языке C\# Scripting.

Правила типизации приведены на Рисунке @types-func-decl.

#type-rule(
  "Некоторые правила типизации объявлений функции",
  "types-func-decl"
)[
  #prooftree([])
  #prooftree(
    rule(
      name: "T-FuncDecl",
      [$Gamma tack (f(a_1: T_1, ... a_n:T_n): T_r) => Gamma, f : (T_1, ..., T_n) -> T_r $],

    )
  )
  #prooftree([])
  #prooftree(
    rule(
      name: "T-FuncDeclImplicitNone",
      [$Gamma tack (f(a_1: T_1, ... a_n:T_n)) => Gamma, f : (T_1, ..., T_n) -> "None" $],

    )
  )
]

Поддерживается указание значений по-умолчанию у аргументов. Правила типизации для этого случая приведены на Рисунке @types-func-decl-args.

#type-rule(
  "Правила типизации для значений аргументов функции по-умолчанию",
  "types-func-decl-args"
)[
  #prooftree([])
  #prooftree(
    rule(
      name: "T-FuncArgDefaultValue",
      [$Gamma tack a:T = v$],
      [$Gamma tack v : T$]
    )
  )
]


Возврат значения из функции осуществаляется оператором `return`. Допускается наличие нескольких операторов возврата в одной функции. Пример такой функции приведён в Листинге @exaple-return

#figure(
  caption: "Пример функции с возвращением результата",
```DSL
func minOf(a: int, b: int): int {
  if (a < b) {
    return a;
  }
  return b;
}
```
) <exaple-return>

[TODO: описать фичи для интеропа]

[TODO: конструкторы через init]

== Объявление переменных

Синтаксис для определения новой переменной приведён на Рисунке @syntax-vars.

#syntax-rule(
  "Синтаксические правила для объявления переменной",
  "syntax-vars"
)[
```
<topLevelDecl>  ::=
                 ...
                 | <varDecl> ';'
                 ...

<objectBodyStatement> ::=
                       ...
                       | <varDecl> ';'
                       ...

<statement> ::=
             ...
             | <varDecl> ';'
             ...

<varDecl>   ::=
             'var' ID (':' ID)? ('=' expression);
```
]

Из этих правил следует, что объявления переменных могут быть на верхнем уровне, на уровне объекта (поля) и внутри тел функций. Правила типизации приведены на Рисунке @types-var. Допускается отсутствие указания типа. В этом случае оно будет выведено на основании типа инициализирующего выражения. Допускается отсутствие этого выражения, в этом случае переменная будет непроинициализирована при объявлении. Отсутствие типа и значения при инициализации не допускается.

#type-rule(
  "Правила типизации объявления переменной",
  "types-var"
)[
  #prooftree(
    rule(
      name: "T-VarExplicit",
      [$Gamma tack ("var" x : T = "expr") => Gamma union x : T$],
      [$Gamma tack "expr" : T'$],
      [$Gamma tack T' <: T$]
    )
  )

  #prooftree([])
  
  #prooftree(
    rule(
      name: "T-VarImplicit",
      [$Gamma tack ("var" x = "expr") => Gamma union x : T$],
      [$Gamma tack "expr" : T$]
    )
  )
  #prooftree([])
  #prooftree(
    rule(
      name: "T-VarNoInit",
      [$Gamma tack ("var" x: T) => Gamma union x : T$],
    )
  )
]

[TODO: добавить правило для declaration sequencing куда-нибудь, $Gamma tack (D_1 D_2) => Gamma' '$ when $Gamma tack D_1 => Gamma'$ and $Gamma' tack D_2 => Gamma' '$]

Запрещается переопределять переменные (_variables shadownig_), неизменяемые переменные отсутствуют. 

=== Выражения 

Разрабатываемый DSL поддерживает арифметические и булевы выражения. Также поддерживается конкатенация строк, вызов функций, инстанциирование экземпляров класса, использование переменных и чтение значений полей. Синтаксические правила для выражений приведены на Рисунке @syntax-expr.

#syntax-rule(
  "Синтаксические правила для выражений",
  "syntax-expr"
)[
```
<expression> ::=
        <functionCall>
      | '(' <expression> ')'
      | <expression> ('*' | '/') <expression>
      | <expression> '%' <expression>
      | <expression> ('+' | '-') <expression>
      | ('-' | '+') <expression>
      | <expression>('=='|'!='|'<='|'<'|'>='|'>') <expression>
      | <expressionAtomic>
      ;

<expressionAtomic> ::=
        <primitiveLiteral>
      | <newExpression>
      | <variableExpression>
      | <qualifiedExpression>
      ;

<primitiveLiteral> ::=
        <intLiteral>
      | <floatLiteral>
      | <stringLiteral>
      | <boolLiteral>

newExpression ::=
    'new' <ID> '(' <expression>? (',' <expression>)+ ','? ')';

variableExpression ::=
    <ID>;

qualifiedAccess ::=
    (<ID> '.')* <ID>;
```
]

В Листинге @example-expressions приведен пример использования выражений.

#show figure: set block(breakable: false)
#figure(
  caption: "Пример использования выражений",
```DSL
func buildClient(host: string, port: int): HttpClient {
  var hostWithSchema = "https://" + host;
  return new HttpClient(
    /*port*/ minOf(1024, port),
    /*host*/ hostWithSchema,
  )
}
```
) <example-expressions>
#show figure: set block(breakable: true)


Некоторые правила типизации приведены на Рисунке @types-expr.
#show figure: set block(breakable: false)
#type-rule(
  "Некоторые правила типизации выражений",
  "types-expr"
)[
  #prooftree(
    rule(
      name: "T-BinExpr",
      [$Gamma tack v_1 plus.circle v_2 : T$],
      [$Gamma tack v_1 : T$],
      [$Gamma tack v_2 : T$]
    )
  )
  #prooftree([])
  #prooftree(
    rule(
      name: "T-Not",
      [$Gamma tack !v : "Bool"$],
      [$Gamma tack v : "Bool"$],
    )
  )
  #prooftree([])
  #prooftree(
    rule(
      name: "T-Rel",
      [$Gamma tack v_1 space R space v_2 : "Bool", "где" R in {"==", "!=", ">", "<", ">=", "<="} $],
      [$Gamma tack v_1 : T$],
      [$Gamma tack v_2 : T$],
    )
  )
  #prooftree([])
  #prooftree(
    rule(
      name: "T-Var",
      [$Gamma tack v : T$],
      [$v : T in Gamma$],
    )
  )

  #prooftree([])
  #prooftree(
    rule(
      name: "T-FuncApp",
      [$Gamma tack (f(v_1, ..., v_n)) : T$],
      [$Gamma tack f : (T_1, ... T_n) -> T$],
      [$Gamma tack v_1 : T_1$],
      [...],
      [$Gamma tack v_n : T_n$]
    )
  )
]

#show figure: set block(breakable: false)

[TODO: добавить ссылку на TAPL]

=== Присваивание значение

Присваивание значений осуществляется с помощью оператора =. Оно позволяет присваивать значения для полей и переменных. Синтаксические правила приведены на Рисунке @syntax-assignment.

#syntax-rule(
  "Синтаксические правила присваения значения",
  "syntax-assignment"
)[
```
<statement> ::= 
             ...
             | <assignment>
             ...

<assignment> ::=
              <expression> '=' <expression>;
```
]

Можно заметить, что в правиле `<assignment>` слева от токена '=' указано правило `<expression>`. Таким образом, синтаксически верно присваивание нового значения совершенно любым выражениям, даже таким, как инстанциирование нового объекта, вызов функции. Обработка таких случаев как ошибок осуществляется на этапе семантического анализа в процессе трансляции. Такое решение позволяет значительно облегчить код грамматики языка.

В Листинге @example-assignment приведен пример использования операторов присваивания.

#figure(
  caption: "Пример использования операций присваивания",
```DSL
object HttpClient {
  var port: int;
  var base_url: string;

  func __init__(port: int, base_url: string) {
    self.port = port;
    self.base_url = base_url;
  }
}
```
) <example-assignment>

=== Оператор условного ветвления

Оператор условного ветвления позволяет описать нелинейное поведение описываемого кода. Синтаксис ветвлений приведён на Рисунке @syntax-if. У ветвления, как и во многих популярных языках программирования, есть условие, тип которого должен быть _Bool_, основное тело, а также альтернативная ветка, которая также может содержать условное ветвление.

Для упрощения языка в рамках прототипа было принято решение отказаться от концепции использование условных ветвлений в качестве выражений. [TODO: найти ссылку на статью какую-нибудь]

#syntax-rule(
  "Синтаксические правила условного ветвления",
  "syntax-if"
)[
```
<statement> ::= 
             ...
             | <ifStatement>
             ...

<ifStatement> ::=
               'if' '(' <expression> ')' 
               '{' <statementsBlock> '}' 
               (
                 ('else' <ifStatement>) 
                 | 'else' '{' <statementsBlock> '}'
               )?
```
]



=== Аннотации <chapter-anno>

Аннотации позволяют изменять поведение транслятора для некоторых сущностей в коде. Их можно применять к объявлению объекта или функции. Синтаксические правила представлены на Рисунке @syntax-annotation. 

#syntax-rule(
  "Синтаксическое правило для аннотации",
  "syntax-annotation"
)[
```
<annotation> ::=
                  '@' <ID> '(' <expressionList> ')';

<expressionList> ::=
                  <expression> (',' <expression>)* ',';
```
]

Пример использования аннотации приведён на Рисунке @example-annotation. Сейчас реализована поддержка только для одной аннотации `@GeneratedName`. Оно позволяет задать имя переменной, которая будет использована в сгенерированном коде. Это необходимо для обеспечения возможности частичного написания кода расширения на низкоуровневом коде на языке C\# Script. Дело в том, что при трансляции применяется намеренное искажение имён (`name mangling`) для избежания коллизий.

#figure(
  caption: "Пример использования аннотации @GeneratedName",
)[
```DSL
@GeneratedName
object Obj {
  ...
}
```
] <example-annotation>


=== Совместимость с кодом на C\# Script

В силу того, что уже есть набор расширений, написанных на языке C\# Script, а также ограничениями текущей версии DSL, важным аспектом разрабатываемой пары технологий (DSL и транслятор) является возможность совместимости между языком и C\# Script. На уровне языка, она обеспечивается двумя механизмами: `intrinsic`-функциями и аннотацией `@GeneratedName` (см. раздел @chapter-anno). Вторая часть поддержки реализована в трансляторе. При обнаружении им файлов с расширением `.jsa` (файлы старых расширений) с именем, совпадающим с именем файла на DSL, содержимое специальным образом будет добавлено в результирующий файл трансляции. В нём можно использовать имена сущностей из DSL с аннотацией `@GeneratedName`. Подробнее этот механизм описан в TODO.

Внутренние (`intrinsic`) функции позволяют описать сигнатуру на DSL, а её реализацию на языке C\# Script. Пример сигнатуры функции приведён в Листинге TODO, а её реализации в Листинге TODO. Она позволяет делать приведение типов. Так как с точки зрения расширений на языке C\# Script семантических типов не существует, они заменяются на тип символьного выражения `SymbolicExpression`. Таким образом, код, использующий функцию `As` в DSL остаётся типизированным, а в реализации функция превращается в функцию идентичности. По соглашению, во все функции на целевом языке добавляется аргумент типа `Location`, который повсеместно используется в PT JSA. Это значение автоматически передаётся транслятором. В дальнейшем планируется добавить специальные аннотации, которые позволят изменить это поведение.

#figure(
  caption: "Пример сигнатуры внутренней функции",
)[
  ```DSL
  intrinsic As<TResult>(expression: any): TResult
  ```
] <example-as-dsl>

#figure(
  caption: "Пример сигнатуры внутренней функции",
)[
  ```csharp
  SymbolicExpression As(
    Location location, 
    expression: SymbolicExpression)
  {
    return expression;
  }
  ```
] <example-as-dsl>

=== Стандартная библиотека

Стандартная библиотека языка содержит операции для работы с taint-данными. В настоящее время она содержит только `intrinsic`-функции, приведённые в Листинге @default-library. 

#figure(
  caption: "Код стандартной библиотеки на разрабатываемом языке"
)[
```DSL
package "Standard";

intrinsic func Detect(
  expression: any, 
  vulnerabilityType: string, 
  grammar: string)

intrinsic func WithTaintMark<T>(
  expression: T, 
  taintOrigin: string): T

intrinsic func CreateTaintedDataOfType<T>(
  taintOrigin: string): T

intrinsic func CreateDataOfType<T>(): T

intrinsic func WithoutVulnerability<T>(
  expression: T, 
  vulnerabilityType: string): T

intrinsic func GetTaintOrigin(
  expression: any): string

```
] <default-library>

Рассмотрим функцию `WithTaintMark`. Она позволяет получить копию выражения, но с добавленной taint-меткой с указанием её места происхождения (`origin`). Оно используется в PT JSA для обнаружения уязвимостей, а также генерации кода для эксплуатации уязвимости. Обычно, им является код для HTTP запроса. Реализация функции `WithTaintMark` приведена в Листинге @example-WithTaintMark.

#figure(
  caption: "Реализация функции WithTaintMark"
)[
```csharp
TExpr WithTaintMark<TExpr>(
  Location location, 
  TExpr? expression, 
  string origin) where TExpr : SymbolicExpression
{
    if (expression == null) {
		  return null;
    }
    var taintOrigin = new TaintOrigin(origin)
    return expression.With(taintOrigin);
}
```
]<example-WithTaintMark>

В Таблице @standard-lib-table приведено описание всех функций стандартной библиотеки

[TODO: нумерация сбросилась почему-то]
#show table.cell: c => {
    return align(left, text(12pt, c, hyphenate: true))
}
#figure(
  caption: "Перечень функций стандартной библиотеки"
)[
#table(
  columns: (auto, auto, auto),
  align: horizon,
  table.header(
    "Функция", "Аргументы", "Описание"
  ),
  "Detect", [
    _expression: any_ — выражение для выявления уязвимостей; #linebreak() _vulnerabilityType: string_ — тип уязвимости; #linebreak()
    _grammar: string_ — синтаксический признак данных.
  ],
  "Запускает обнаружение заражённых данных в выражении. В случае, если они будут обнаружены, анализатор вернёт уязвимость соответствующего типа. Грамматика определяет синтаксический тип данных, такой как URL, HTML текст, SQL",
  "WithTaintMark<T>", [
    _expression: any_ — выражение для добавления taint-метки; #linebreak()
    _taintOrigin_ — тип источника данных.
  ],
  "Добавляет taint-метку к копии выражения",
  "CreateTaintedDataOfType<T>", [
    _T_ — тип создаваемого объекта; #linebreak()
    _taintOrigin_ — тип источника данных.
  ],
  "Создаёт непроинициализированный объект нужного типа без вызова конструктора и с taint-меткой",
  "CreateDataOfType<T>", [
    _T_ — тип создаваемого объекта
  ], 
  "Создаёт объект нужного типа без вызова конструктора без taint-метки",
  "WithoutVulnerability<T>", [
    _expression: T_ — выражение; #linebreak()
    _vulnerabilityType: string_. — тип уязвимости для фильтрации
  ],
  "Добавляет отметку об отфильтровывании уязвимости",
  "GetTaintOrigin", [
    _expression: any_ — выражение
  ],
  "Возвращает источник taint-данных в виде строки"
)
] <standard-lib-table>


=== Система типов