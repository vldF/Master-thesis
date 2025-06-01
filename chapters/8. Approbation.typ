#import "../thesis-base.typ": *
#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.1": *
#import "@preview/curryst:0.5.1": rule, prooftree
#import "@preview/diagraph:0.3.3": *

#show: codly-init.with()
#codly(languages: codly-languages, breakable: true)

#chapter(4, "Апробация полученных инструментов")

Данная глава содержит результаты апробации DSL и его транслятора в низкоуровневый код расширений PT JSA.

== Подход к апробации

Основной зоной применения PT JSA является анализ кода web-приложений на безопасность. Так как прототип DSL и его транслятора предназначены для описания библиотек и фреймворков на языке Python, проекты, приведённые в этой главе, также написаны на этом языке. Они показывают реальные способы написания кода серверов. 

В Главе рассмотрено несколько проектов. Каждый из них показывает пример использования библиотеки или фреймворка наиболее популярными способами, а также код для расширения JSA с поддержкой их. Список компонентов для демонстрации был составлен с учётом их популярности. Стоит отметить, что целью данной Главы не является проверка и демонстрация функциональных возможностей самого анализатора. По этому, примеры содержат простой код, целью которого является демонстрация сценариев использования внешних компонентов. Проекты не содержат намеренно сложный код, который мог бы привести к ложным срабатываниям анализатора.

Для апробации, код на DSL транслируется в низкоуровневый код для расширений, анализатор PT JSA запускается из терминала. Он сохраняет запись в журнал о каждой найденной уязвимости. Для краткости, пояснительная информация содержит только основные значения, по которым можно определить корректность написания расширения.

Исходный и сгенерированный коды проектов располагаются в поддиректории соответствующего проекта в директории `Examples`#footnote("https://github.com/vldF/Master-thesis-DSL/tree/main/Examples/"). 

== Библиотека для отправки HTTP-запросов

Одной из популярных операций в серверных web-приложениях является отправка HTTP-запросов. Она необходима как для интеграции со внешними сервисами, так и для коммуникациями между микросервисами одной системы. 

Библиотека urllib3 предоставляет возможности для отправки HTTP-запросов с различными опциями и получения ответов. Листинг @urllib3-app содержит пример кода обработки запроса с использованием фреймворка Flask. 

#show figure: set block(breakable: false)
#figure(
  caption: "Пример использования библиотеки urllib3",
  ```python
@app.route('/save_profile_image', methods=['GET'])
def save_profile_image():
  image_url = request.args.get('image_url')
  temp_file = tempfile.TemporaryFile()
  download_image(image_url, temp_file)

  process_image(temp_file)

  return

def download_image(url, filename):
  token = get_system_token()
  # уязвимость: подделка запросов со стороны сервера
  response = urllib3.request('GET', url, { 'auth_token': token }) 

  with open(filename, 'wb') as f:
    f.write(response.data)

  print(f"Image saved as {filename}")
  ```
) <urllib3-app>
#show figure: set block(breakable: true)

В Листинге @urllib3-app описана функция-обработчик HTTP GET запроса по относительному адресу _/save_profile_image_. Можно считать, что она позволяет сохранить фотографию пользователя после её загрузки на сервер. Обработчик принимает аргумент с именем _image_url_, содержащий адрес загруженного изображения и загружает его с использованием системного токена для идентификации и аутентификации. Для упрощения, последующая обработка данных, не относящаяся к демонстрации, была опущена. Так как в коде отсутствует проверка URL фотографии, клиент может совершить атаку, отправив произвольный адрес. Это может привести к:

- Отправке запросов с системным токеном на произвольный сервер;
- Загрузке файла с произвольным содержимым.

Первый пункт приведёт к раскрытию чувствительной информации, в то время как второй позволит атакующему загрузить файл с вредоносным кодом на сервер. Возможна также загрузка большого файла, что приведёт к отказу в обслуживании (_DOS_). Данная уязвимость называется "подделка запросов со стороны сервера" (_Server-side request forgery_), подробнее она описана @zeller2008cross. 

Для добавления поддержки библиотеки urllib3 в JSA был написан код на DSL, фрагмент которого приведён в Листинге @urllib3-descr. Он состоит из трёх файлов, которые подписаны комментариями. Полный текст приведён в директории `Examples/urllib3/dsl` #footnote("https://github.com/vldF/Master-thesis-DSL/tree/main/Examples/urllib3")

#figure(
  caption: "Код расширения для поддержки urllib3",
```DSL
// файл urllib3.response.jsadsl
package "urllib3.response";

import "Standard";
import "urllib3.connection";

object HTTPResponse {
  var status = CreateTaintedDataOfType<int>("Second order");
  var data = CreateTaintedDataOfType<bytes>("Second order");
  var body = CreateTaintedDataOfType<string>("Second order");
  var url = CreateTaintedDataOfType<string>("Second order");
  var request_url = CreateTaintedDataOfType<string>("Second order");

  var connection = new HTTPConnection();

  func json(): any {
    return CreateTaintedDataOfType<any>("Second order");
  }

  func readline(): string {
    return CreateTaintedDataOfType<string>("Second order");
  }

  func read(): any {
    return CreateTaintedDataOfType<any>("Second order");
  }

  func fileno(): any {
    return CreateTaintedDataOfType<any>("Second order");
  }
  // аналогичное описание ещё трёх функций
}


// файл urllib3.connection.jsadsl
package "urllib3.connection";

import "Standard";
import "urllib3.response";

object HTTPConnection {
  func getresponse(): HTTPResponse {
      return new HTTPResponse();
  }

  func request(
    method: string = "GET", 
    url: string, 
    body: any = none, 
    fields: any = none, 
    headers: any = none, 
    json: any = none
  ): HTTPResponse {
    Detect(url, "Server-Side Request Forgery", "HTTP URI");
    Detect(headers, "Server-Side Request Forgery", "HTTP URI");
    Detect(headers, "Information Exposure", "HTTP URI");

    return new HTTPResponse();
}


  func request_chunked(url: string) {
    Detect(url, "Server-Side Request Forgery", "HTTP URI");
  }
}


// файл urllib3.jsadsl
package "urllib3";

import "Standard";
import "urllib3.response";

  func request(
    method: string = "GET", 
    url: string, 
    body: any = none, 
    fields: any = none, 
    headers: any = none, 
    json: any = none
  ): HTTPResponse {
    Detect(url, "Server-Side Request Forgery", "HTTP URI");
    Detect(headers, "Server-Side Request Forgery", "HTTP URI");
    Detect(headers, "Information Exposure", "HTTP URI");

    return new HTTPResponse();
} 
```
) <urllib3-descr>

В Листинге @urllib3-descr объект _HTTPResponse_ описывает для PT JSA одноимённый класс библиотеки urllib3. Он содержит несколько полей, содержащие потенциально заражённые данные, такие, как _status_ и _data_. Листинг содержит объект типа _HTTPConnection_, а также несколько функций. К примеру, функция _json_ в urllib3 возвращает тело ответа на запрос, десериализованное из JSON в произвольный объект. С точки зрения taint-анализа, она является источником заражённых данных, по этому, в коде её результатом является результат вызова функции _CreateTaintedDataOfType\<any>_, которая создаёт такой объект произвольного типа. 

Функции _request_ объекта _HTTPConnection_ и одноимённая функция пакета _urllib3_ отправляют HTTP-запрос по указанному URL. Они содержат большое количество аргументов по-умолчанию. Каждая из них запускает операцию определения на аргументах _url_ и _headers_. В проверке для URL содержится уязвимость SSRF, в проверке для заголовков SSRF и Information Exposure (утечка чувствительной информации). 

Информация об уязвимости, найденной в коде в Листинге @urllib3-app с расширением из Листинга @urllib3-descr приведена в Таблице @urllib3-res. В ней видно, что найдена уязвимость указанного в коде на DSL типа на строке 13. Можно заметить, что трасса данных приведена также корректно. 

#figure(
  caption: "Информация об уязвимости",
  table(
  columns: 2*(auto,),
  table.header("Параметр", "Значение"),
  table.cell([Функция _save_profile_image_], colspan: 2),
  table.cell([Уязвимость "подделка запросов со стороны сервера"], colspan: 2),
  "Уязвимое выражение", "response = urllib3.request('GET', url, { '...",
  "Точка входа", "def save_profile_image():",
  "Трасса данных", [
    image_url = request.args.get('image_url') #linebreak()
    download_image(image_url, temp_file) #linebreak()
    response = urllib3.request(...{ 'auth_token': token })
  ]
)
) <urllib3-res>

Этот пример показывает, что разработанный DSL позволяет расширять базу знаний PT JSA элементарными библиотеками и позволяет описывать их с точки зрения анализа потока данных с достаточной для анализа точностью. 

== Библиотека для работы с базой данных

В Python существует несколько популярных библиотек для работы с базами данных. В рамках демонстрации была выбрана библиотека psycopg2, предоставляющая набор всех базовых операций для взаимодействия с СУБД postgres. Выбор библиотеки для взаимодействия с базой данных закономерен: по многим исследованиям (@sqli1 @sqli2), операции с ними часто приводят к уязвимостям.

Листинг @psycopg2-app содержит фрагмент web-приложения, построенного на фреймворке Flask и использующего библиотеку psycopg2. 

#figure(
  caption: "Фрагмент кода приложения с использованием psycopg2",
```python
@app.route("unsafe/users/description/<user_id>/", methods=["GET"])
def get_user_description():
  user_id = request.args.get('user_id')
  conn = connect("dbname=test user=postgres")
  cur = conn.cursor()
  # уязвимость: внедрение SQL-кода
  cur.execute("SELECT description FROM table WHERE ID = " + user_id)
  description = cur.fetchone()
  # уязвимость второго порядка: межсайтовый скриптинг
  return description

@app.route("unsafe/users/<user_id>/", methods=["GET"])
def get_user1():
  user_id = request.args.get('user_id')
  conn = connect("dbname=test user=postgres")
  cur = conn.cursor()
  # уязвимость: внедрение SQL-кода
  cur.execute("SELECT * FROM table WHERE ID = " + user_id)
  user = cur.fetchone()
  # нет уязвимости
  return jsonify(user)

@app.route("safe/users/<user_id>/", methods=["GET"])
def get_user2():
  user_id = request.args.get('user_id')
  conn = connect("dbname=test user=postgres")
  cur = conn.cursor()
  # нет уязвимости
  cur.execute("SELECT * FROM table WHERE ID = %s", (user_id, ))
  user = cur.fetchone()
  # нет уязвимости
  return jsonify(user)
```
) <psycopg2-app>

При использовании библиотеки psycopg2 используется функция _connect_, устанавливающая подключение к БД и возвращает объект типа _Connection_. Он содержит функцию _cursor_, которая возвращает объект типа _Cursor_, позволяющий обращаться к базе данных. Его функции _execute_ и _executemany_ позволяют отправить запрос, функции _fetchone_, _fetchmany_ и _fetchall_ возвращают результат запроса.

 В Листинге @psycopg2-app _get_user_description_ содержит сразу две уязвимости: внедрение SQL-кода и уязвимость второго порядка типа межсайтовый скриптинг. Уязвимостью второго порядка называется уязвимость, уязвимые данные для которой сначала сохраняются в некоторое состояние (в оперативную память, в базу данных), а затем возвращаются пользователю в результате другого запроса. Фактически, их можно описать фразой "уязвимость из-за уязвимости". В данном примере атакующий мог бы установить описание пользователя на HTML текст с скриптом на javascript (что само по себе не безопасно). Получение этого описания другим пользователем привело бы к уязвимости. В этой функции одним из способов исправления дефекта может быть экранирование данных, что демонстрируется в функции _get_user1_. В прочем, в _get_user1_ всё ещё присутствует дефект типа "внедрение SQL-кода". Её исправление приведено в функции _get_user2_, где используется механизм библиотеки psycopg2, экранирующий значения при формировании SQL-запроса по шаблону на строке 29. 

 Для расширения базы знаний PT JSA был написан код на DSL, приведённый в Листинге @psycopg2-descr. В нём приведены три файла. Файл _psycopg2.jsadsl_ содержит функцию _connect_, которая возвращает объект типа _Connection_ вне зависимости от строки подключения к БД. Объект _Connection_ содержит функцию _cursor_, возвращающую объект типа _Cursor_, который содержит функции для исполнения запросов и возврата результатов. Таким образом моделируется общая структура библиотеки. Функции _execute_ и _executemany_ содержат код, запускающий поиск уязвимых данных на их аргументах. Это позволяет, в частности, определять случаи конкатенации к SQL запросам потенциально уязвимых данных. Функции _fetchone_, _fetchmany_ и _fetchall_ возвращают данные соответствующего типа с taint-меткой и источником вида "Second Order", обозначающих, что это данные, которые могут привести к уязвимости второго порядка. 


#figure(
caption: "Код для добавления поддержки psycopg2 в PT JSA",
```DSL
// файл psycopg2.jsadsl
package "psycopg2";
import "psycopg2.Cursor";
import "psycopg2.Connection";
func connect(connection_string: any): Connection {
  return new Connection();
}

// файл psycopg2.Connection.jsadsl
package "psycopg2.Connection";
import "Standard";
import "psycopg2.Cursor";
object Connection {
  func cursor(): Cursor {
    return new Cursor();
  }
}

// файл psycopg2.Cursor.jsadsl
package "psycopg2.Cursor";
import "Standard";
object Cursor {
  func execute(
    query: string, 
    vars: list = CreateDataOfType<list>()
  ) {
    Detect(query, "SQL Injection", "SQL common");
  }
  func executemany(
    query: string, 
    vars: list = CreateDataOfType<list>()
  ) {
    Detect(query, "SQL Injection", "SQL common");
  }
  func fetchone(): any {
    return CreateTaintedDataOfType<any>(
      "Second Order");
  }
  func fetchmany(): list {
    return CreateTaintedDataOfType<list>(
      "Second Order");
  }
  // ...
}
```
) <psycopg2-descr>

Уязвимости, которые были найдены анализатором PT JSA в коде, приведённом в Листинге @psycopg2-app с помощью расширения в Листинге @psycopg2-descr, приведены в Таблице @psycopg2-res. Из неё следует, что все уязвимости в коде, описанные ранее, были обнаружены и были обнаружены только они.

#show figure: set block(sticky: true)
#figure(
  caption: "Информация об уязвимостях",
  table(
  columns: 2*(auto,),
  table.header("Параметр", "Значение"),
  table.cell([Функция _get_user_description_], colspan: 2),
  table.cell([Уязвимость "внедрение SQL-кода"], colspan: 2),
  "Уязвимое выражение", "cur.execute(\"SELECT description FROM table...",
  "Точка входа", "@app.route(\"users/description/<user_id>/\",:",
  "Трасса данных", [
    user_id = request.args.get('user_id') #linebreak()
    cur.execute(\"SELECT description FROM table...
  ],
  table.cell([Уязвимость "межсайтовый скриптинг"], colspan: 2),
  "Уязвимое выражение", "return description",
  "Точка входа", "@app.route(\"users/description/<user_id>/\", ...",
  "Трасса данных", [
    description = cur.fetchone() #linebreak()
    return description
  ],
  table.cell([Функция _get_user1_], colspan: 2),
  table.cell([Уязвимость "внедрение SQL-кода"], colspan: 2),
  "Уязвимое выражение", "cur.execute(\"SELECT * FROM table...",
  "Точка входа", "@app.route(\"users/<user_id>/\", ...",
  "Трасса данных", [
    user_id = request.args.get('user_id') #linebreak()
    cur.execute(\"SELECT \* FROM table...
  ],
)
) <psycopg2-res>
#show figure: set block(sticky: false)

Таким образом, разработанный DSL пригоден для добавления в PT JSA поддержки библиотек для работы с базами данных. 

== Фреймворк для обработки HTTP-запросов

Для Python предоставлено большое число фреймворков, позволяющих разрабатывать серверные приложения, обрабатывающие HTTP-запросы от клиентов. Одним из популярных является фреймворк Flask. Он позволяет с использованием декоратора _\@route_ объявить функцию обработчиком запроса. Эта функция может содержать аргументы, которые могут быть получены и альтернативным способом — при помощи поля _request.args_, которое является ассоциативным массивом. Flask также предоставляет большое число утилитарных функций, таких как _jsonify_, которая преобразует аргумент произвольного типа в JSON. Она позволяет экранировать данные в полях сериализуемого объекта, по этому, можно рассматривать её как фильтрующую функцию.

В Листинге @flask-app приведён код HTTP сервера с использованием этого фреймворка. Он состоит из двух обработчиков запросов: функции _auth_, имитирующей идентификацию и аутентификацию по логину и хешу пароля, а также функции _get_current_user_, возвращающей информацию о текущем пользователе. В Листинге представлены и вспомогательные функции: _validate_login_and_password_, проверяющая корректность логина и хеша пароля записи в БД, а также _get_user_by_token_, получающая из БД запись о пользователе по его токену аутентификации. 

#figure(
caption: "Фрагмент кода web-приложения на Flask",
```python
@app.route("/auth/<string:redirect_url>")
def auth(redirect_url: str):
  login = request.args["user_login"]
  pass_hash = request.args["user_login"]
  if not validate_login_and_password(login, pass_hash):
    return "Login failed", 401

  token = get_user_token(login)
  # уязвимость: подделка запросов со стороны сервера
  return redirect(f"redirect_url?token={token}")

def validate_login_and_password(login: str, pass_hash: str) -> bool:
  conn = connect("dbname=test user=postgres")
  cur = conn.cursor()
  cur.execute("SELECT * FROM users WHERE login = %s", (login, ))
  user = cur.fetchone()
  return user is not None and user.pass_hash == pass_hash

@app.route("/user/get_me/<string:token>")
def get_current_user(token: str):
  current_user = get_user_by_token(token)
  if current_user is None:
    return f"invalid token: {token}"

  return jsonify(current_user)

def get_user_by_token(token: str):
  conn = connect("dbname=test user=postgres")
  cur = conn.cursor()

  cur.execute("SELECT * FROM user_tokens WHERE token = %s", (token, ))
  token_record = cur.fetchone()
  if token_record is None:
    return None

  cur.execute("SELECT * FROM users WHERE login = %s", (token_record.login, ))
  user = cur.fetchone()

  return user
```
) <flask-app>

Функция-обработчик _auth_ в Листинге @flask-app получает от клиента логин, хеш пароля, а также адрес, на который пользователь будет перенаправлен в случае успешной аутентификации. Стоит заметить, что в коде полностью отсутствует проверка адреса для перенаправления. Так как он принимается в запросе от пользователя, атакующий может проставить туда произвольный адрес, на который при удачной аутентификации отправится токен пользователя с помощью параметра _token_. Таким образом, это пример уязвимости типа "открытое перенаправление" (_Open redirect_). 

Функция _get_current_user_ получает запись о пользователе по его токену. В случае, если она не может найти его, возвращается ошибка, которая содержит сам токен. Так как токен передаётся клиентом, атакующий может передать намеренно данные, не проходящие проверку и содержащие произвольный код. Так как этот код возвращается достоверным сервером, то у него будет доступ к механизмам браузера, которые используются для хранения настоящего токена. Так, эта информация может быть передана на внешний сервер и злоумышленник получит к ней доступ. Для исправления этой уязвимости можно воспользоваться функцией _escape_, которую предоставляет Flask. Она экранирует HTML теги, что лишает злоумышленника возможность провести такую атаку. Также, можно просто не возвращать некорректный токен. 

Flask — сложный для поддержки фреймворк. Текущих возможностей DSL не хватает для достаточной его поддержки. К примеру, во Flask применяются декораторы, которые, с точки зрения семантики python, являются синтаксическим сахаром для композиции функций. Таким образом, для описания декораторов необходима поддержка функциональных значений и типов, которая отсутствует в прототипе. Однако, так как предоставляются возможности для написания части кода расширения с использованием низкоуровневого API на C\# Script, эти ограничения можно обойти, что и было сделано для апробации. Так, расширение состоит из двух файлов. Файл _flask.jsadsl_ (см. Листинг @flask-descr), содержащий, помимо прочего, объект _Flask_, помеченный аннотацией _\@GeneratedName(''FlaskClassDescriptor'')_. Таком образом, объект _Flask_ может быть расширен из низкоуровневого API на C\# Script. Файл _flaskComplemention.jsa_ содержит такой код, с ним можно ознакомиться в файле `Examples/flask/sharp` #footnote("https://github.com/vldF/Master-thesis-DSL/blob/main/Examples/flask/sharp/flaskComplemention.jsa"). 

#figure(
  caption: "Фрагмент кода расширения для поддержки Flask",
```DSL
import "Standard";

@GeneratedName("FlaskClassDescriptor")
object Flask { }

func url_for(endpoint: any): string {
  return CreateDataOfType<string>();
}

object Request {
  var args = CreateTaintedDataOfType<dict>("Query");
  var data = CreateTaintedDataOfType<dict>("Body");
  // ...
  var blueprint = CreateDataOfType<string>();
  var endpoint = CreateDataOfType<any>();

  func get_json(): any {
      return CreateTaintedDataOfType<any>("Body");
  }
}

var request = new Request();

func escape(data: string): string {
  var escaped = WithoutVulnerability(data, "Cross-site Scripting");
  escaped = WithoutVulnerability(data, "Server-Side Template Injection");
}

func jsonify(data: any): any {
  return CreateDataOfType<any>();
}

func redirect(url: string, code: int = 302, response: any = none): any {
  Detect(url, "Open redirect", "HTTP URI");
  Detect(response, "Cross-site Scripting", "HTTP URI");

  return CreateDataOfType<any>();
}
```
) <flask-descr>

Листинг @flask-descr содержит фрагмент файла расширения. Помимо объекта _Flask_, в нём расположен объект _Request_, содержащий большое количество полей-источников taint-данных (их часть скрыта для краткости). Представлены и поля с данными без метки (_blueprint_ и _endpoint_). Обратим внимание на функцию _get_data_. В зависимости от значения аргумента _as_text_, она возвращает либо строку байт, либо обычную строку с taint-метками. Функция _escape_, располагающаяся на глобальном уровне, сообщает анализатору об отфильтровывании данных таким образом, что уязвимость типа "Cross-site Scripting" (межсайтовый скриптинг) больше не может быть обнаружена на соответствующем потоке данных. Функция _jsonify_ возвращает данные произвольного типа без taint-метки, моделируя преобразование данных в JSON с экранированием. Функция _redirect_ запускает обнаружение уязвимостей типа "Open redirect" (открытый редирект) на адресе перенаправления и "Cross-site Scripting" на аргументе ответа от сервера.

Таблица @flask-res содержит уязвимости, обнаруженные анализатором JSA на коде из Листинга @flask-app с разработанным расширением. 

#figure(
  caption: "Информация об уязвимостях",
  table(
  columns: 2*(auto,),
  table.header("Параметр", "Значение"),
  table.cell([Функция _auth_], colspan: 2),
  table.cell([Уязвимость "открытое перенаправление"], colspan: 2),
  "Уязвимое выражение", "return redirect(f\"{redirect_url}?token={token}\")",
  "Точка входа", "@app.route(\"/auth/<string:redirect_url>\")",
  "Трасса данных", [
    \@app.route(\"/auth/\<string:redirect_url>\") #linebreak()
    login = request.args[\"user_login\"]" #linebreak()
    token = get_user_token(login) #linebreak()
    return redirect(f\"{redirect_url}?token={token}\")"
  ],
  table.cell([Функция _get_current_user_], colspan: 2),
  table.cell([Уязвимость "межсайтовый скриптинг"], colspan: 2),
  "Уязвимое выражение", "return f\"invalid token: {token}\"",
  "Точка входа", "@app.route(\"/user/get_me/<string:token>\")",
  "Трасса данных", [
    \@app.route(\"/user/get_me/\<string:token>\") #linebreak()
    return f\"invalid token: {token}\"
  ],
)
) <flask-res>

В Таблице @flask-res видно, что все описанные ранее уязвимости были найдены, а все представленные значения являются корректными. Таким образом, несмотря на ограничения текущей реализации прототипа, благодаря совместимости с C\# Script можно описывать и такие сложные фреймворки как Flask.

== Пользовательская библиотека для получения информации об IP

Рассмотренные ранее библиотеки могли бы оказаться в базе знаний PT JSA благодаря его производителю, так как они являются популярными. Однако, существует большое количество компонентов, которые не могут быть добавлены производителем. Например, некоторые из компаний-пользователей PT JSA имеют собственные разработки библиотек. Одним них может являться компонент для определения информации об IP адресе. Это необходимо, в частности, для отображения данных об активности пользователя. Эта функциональная возможность предоставляется большим количеством сервисов и позволяет обнаруживать подозрительную активность на своём аккаунте. Для демонстрации была разработана библиотека, использующая API сервиса `ipgeolocation.abstractapi.com`. Исходный код клиентов может быть обнаружен в `Examples/abstractapi-ip-geolocation` #footnote("https://github.com/vldF/Master-thesis-DSL/tree/main/Examples/abstractapi-ip-geolocation/library"). Код приложения для демонстрации приведён в Листинге @ip-app. Функция 
_get_user_session_vulner_ содержит уязвимость "межсайтовый скриптинг". В функции _get_user_session_safe_ происходит экранирование ответа от удалённого сервера. Стоит отметить, что удалённый сервер возвращает единственную строку без HTML-разметки, по этому, экранирование функцией _escape_ тут возможно. 


#figure(
caption: "Код приложения, использующий библиотеку",
```python
ip_client = IpGeolocationClient(base_url="https://ipgeolocation.abstractapi.com/", token="api-token")
def get_ip_info(ip: str) -> str:
  return ip_client.get_info(ip)

@app.route('/vulnerable/ip_info/<int:user_ip>', methods=['GET'])
def get_user_session_vulner(user_ip):
  ip_info = get_ip_info(user_ip)
  escaped_ip = escape(user_ip)
  # уязвимость: межсайтовый скриптинг
  return f"""
  <html>
  <b>IP: {escaped_ip}</b>
  </br>
  <b>IP geolocation: {ip_info}</b>
  </html>
  """

@app.route('/safe/ip_info/<int:user_ip>', methods=['GET'])
def get_user_session_safe(user_ip):
  ip_info = get_ip_info(user_ip)
  escaped_ip_info = escape(ip_info)
  escaped_ip = escape(user_ip)
  # уязвимость отсутствует
  return f"""
  <html>
  <b>IP: {escaped_ip}</b>
  </br>
  <b>IP geolocation: {escaped_ip_info}</b>
  </html>
  """
```
) <ip-app>

Для добавления поддержки разработанной библиотеки в PT JSA был написан код, приведённый в Листинге @ip-descr. Он содержит единственный объект _IpGeolocationClient_, содержащий функции _\_\_init\_\__ метод (выполняющий роль конструктора) и _get_ip_info_. Последняя принимает IP в виде строки и возвращает строку с taint-меткой и происхождением типа _Body_. Они соответствуют ответу от HTTP сервиса, который используется в качестве поставщика информации. Функция _get_ip_info_ в данном примере возвращает недостоверные данные больше для демонстрационных целей. В прочем, некоторые требования к обеспечению безопасности приложений действительно могут быть установлены так, что такое поведение будет само собой разумеющимся. В самом деле, данные данные получаются со внешнего сервера, находящегося вне зоны контроля. Атакующий может получить к нему доступ и отправить из него недостоверные данные для эксплуатации уязвимости, по этому, данные нужно валидировать. 

#figure(
caption: "Код расширения для поддержки библиотеки",
```DSL 
import "Standard";

object IpGeolocationClient {
  func __init__(base_url: string, token: string) {}

  func get_ip_info(ip: string): string {
    return CreateTaintedDataOfType<string>("Body");
  }
}
```
) <ip-descr>

В Таблице @ip-res приведена информация об уязвимостях, обнаруженных в коде @ip-app при помощи разработанного расширения базы знаний анализатора. Видно, что анализатор нашёл единственную уязвимость, описанную выше, а также что представленные свойства этой уязвимости корректны.

#figure(
  caption: "Информация об уязвимостях",
  table(
  columns: 2*(auto,),
  table.header("Параметр", "Значение"),
  table.cell([Функция _get_user_session_vulner_], colspan: 2),
  table.cell([Уязвимость "межсайтовый скриптинг"], colspan: 2),
  "Уязвимое выражение", "<b>IP info: {ip_info}</b>",
  "Точка входа", "@app.route('/vulnerable/ip_info/<int:user_ip>'...",
  "Трасса данных", [
    \@app.route('/vulnerable/ip_info/\<int:user_ip>'... #linebreak()
    ip_info = get_ip_info(user_ip)... #linebreak()
    \<b>IP info: {ip_info}\</b>... #linebreak()
    return f\"\"\"
  ],
)
) <ip-res>

Таким образом, разработанный DSL позволяет описывать простые пользовательские библиотеки, которые не могут быть внесены в базу знаний анализатора при его разработке, что делает инструмент актуальным для большого количества пользователей.

== Генерируемая автоматически пользовательская библиотека

Такие инструменты как protobuf @protobuf и openAPI позволяют генерировать клиенты и сервера на основании спецификации. Это часто используется, к примеру, в подходе разработки на основе контракта (contract-first development). Она популярна при разработке web-приложений с микросервисной архитектурой, так как позволяет разрабатывать каждый из сервисов параллельно. В микросервисной архитектуре каждый из компонентов системы исполняет различные функции. Можно представить, что в некотором приложении база данных о пользователях реализована в виде выделенного сервиса. У него есть заранее известный контракт на языке protobuf, который позволяет автоматически сгенерировать код клиента для gRPC @grpc. Код клиента, сгенерированный gRPC затруднителен для автоматического анализа, так как, в частности, содержит сложную сериализацию в памяти с последующей отправкой сообщения серверу. Ответы проходят другую сложную процедуру — десериализацию. По этому, есть необходимость в добавлении поддержки этого клиента в базу знаний анализатора.

Код контрактов сервиса базы данных о пользователе приведён в Листинге @grpc-contract. Он включает в себя сервис _UserStore_, а также два сообщения — запрос данных о пользователе _UserRequest_ и ответ на него _User_. 

#figure(
caption: "Контракты базы данных о пользователе",
```protobuf
syntax = "proto3";
package userstorage;

message User {
  string id = 1;
  string username = 2;
}

message UserRequest {
  string id = 1;
}

service UserStore {
  rpc GetUser(UserRequest) returns (User);
}

```
) <grpc-contract>

В Листинге @grpc-app приведён код приложения, использующего этот сервис. Обработчике запросов _vulnerable_get_user_info_ содержится уязвимость "небезопасная прямая ссылка на объект", позволяющая атакующему получить перебором все значения из БД, если он может явно передать идентификатор каждого из них. К примеру, он может получить список всех идентификаторов пользователей другим запросом, а затем для каждого из них получить всю возможную информацию через _vulnerable_get_user_info_. Для исправления уязвимости стоит запретить явную передачу идентификатора через аргументы запроса и получать его, к примеру, из токена текущего пользователя. Этот подход демонстрируется в _safe_get_user_info_. Функция _\_get_user_id_ получает ИД текущего пользователя на основании токена из запроса, её реализация опущена. 

Обе функции используют канал (_channel_) для коммуникации с сервисом. Эту абстракцию предоставляет gRPC в своей библиотеке. Далее, они получают экземпляр "заглушки" (_stub_) для сервиса UserStore, который содержит функцию _GetUser_. Она принимает объект запроса, отправляет его на сервер, получает ответ и возвращает результат, который, затем, передаётся пользователю.

#figure(
caption: "Код приложения, использующий сервис UserStore",
```python
@app.route("/unsafe/getCurrentUserInfo/<string:user_id>")
def vulnerable_get_user_info(user_id: str):
  with grpc.insecure_channel(SERVER_URL) as channel:
    user_storage_stub = user_storage_service.UserStoreStub(channel)
    getUserRequest = user_storage_dto.UserRequest(user_id)

    # уязвимость: небезопасная прямая ссылка на объект
    user = user_storage_stub.GetUser(getUserRequest)

    return jsonify(user)

@app.route("/safe/getUserInfo/")
def safe_get_user_info():
  current_user_id = _get_user_id()
  with grpc.insecure_channel(SERVER_URL) as channel:
    user_storage_stub = user_storage_service.UserStoreStub(channel)
    # нет уязвимости
    user = user_storage_stub.GetUser(user_storage_dto.UserRequest(current_user_id))

    return jsonify(user)
```
)<grpc-app>

Инструмент для генерации кода gRPC клиента для Python генерирует раздельные файлы для моделей сообщений и кода сервисов. Каждый из них располагается в собственном пакете. По этому, это необходимо повторить и в коде расширения, см. Листинг @grpc-desc. Объект _UserRequest_ содержит поле _id_ и конструктор для его инициализации. Объект _User_ не содержит конструктора, так как он не нужен для моделирования кода. Объект _UserStoreStub_ содержит конструктор, принимающий аргумент _channel_ так как он используется для инициализации из кода приложения. Функция _GetUser_ запускает определение уязвимости типа "небезопасная прямая ссылка на объект" (Insecure Direct Object References). 

#show figure: set block(sticky: true)
#figure(
caption: "Расширение для поддержки UserStore",
```DSL
// файл userstorage.services_pb2.jsadsl
package "userstorage.services_pb2";
object UserRequest {
  var id: string;
  func __init__(id: string) {
    self.id = id;
  }
}
object User {
  var id: int;
  var username: string;
}

// файл userstorage.services_pb2_grpc.jsadsl
import "Standard";
import "userstorage.services_pb2";

object UserStoreStub {
  func __init__(channel: any) { }

  func GetUser(request: UserRequest): User {
    Detect(
      request.id, 
      "Insecure Direct Object References", 
      "Arbitrary string data");
    return CreateDataOfType<User>();
  }
}
```
) <grpc-desc>
#show figure: set block(sticky: false)

В Таблице @grpc-res приведён результат анализа кода из Листинга @grpc-app с разработанным расширением.

#figure(
  caption: "Информация об уязвимости",
  table(
  columns: 2*(auto,),
  table.header("Параметр", "Значение"),
  table.cell([Функция _vulnerable_get_user_info_], colspan: 2),
  table.cell([Уязвимость "небезопасная прямая ссылка на объект"], colspan: 2),
  "Уязвимое выражение", "user = user_storage_stub.GetUser(getUserRequest)",
  "Точка входа", "@app.route(\"/vulnerable/getCurrentUserInfo/...",
  "Трасса данных", [
    \@app.route(\"/vulnerable/getCurrentUserInfo/ #linebreak()
    getUserRequest = user_storage_dto.UserRequest(...) #linebreak()
     user = user_storage_stub.GetUser(getUserRequest)
  ]
)
) <grpc-res>

По Таблице @grpc-res видно, что описанная выше уязвимость была обнаружена и её свойства корректны. Это показывает, что разработанный DSL может быть использован для добавления поддержки автоматически генерируемых библиотек, а также показывает, как пользователь анализатора может учесть архитектуру конкретного проекта для уточнения результатов анализа. 

== Сравнение с существующим способом расширения базы знаний

Важным аспектом для апробации является проверка того, насколько разработанный DSL эффективнее существующего способа расширения базы знаний PT JSA на языка C\# Script. Одним из показателей эффективности является объём исходного кода. Для такого сравнения для нескольких библиотеки, представленных в этой Главе были дополнительно реализованы расширения в старом формате. Они эквивалентны рассмотренным ранее. Это показывается абсолютно одинаковыми результатами срабатываний анализатора на тестовых проектах, а также обеспечивается по построению. Исходные коды расширений на C\# Script приведены в директории `Examples`#footnote("https://github.com/vldF/Master-thesis-DSL/tree/main/Examples/").

Результаты сравнения расширений на DSL и на C\# Script приведены в Таблице @dsl-sharp-compare. Для расчётов игнорировались все пустые строки, а также пробельные символы и комментарии.

#figure(
  caption: "Сравнение объёмов кода расширений на DSL и C# Script",
  table(
    columns: 5 * (auto,),

    table.header(table.cell("Библиотека", stroke: (bottom: 0pt)), table.cell("DSL", colspan: 2, align: center), table.cell("C# Script", colspan: 2, align: center)),
    table.cell("", stroke: (left: 1pt)), [*Строки*], [*Символы*], [*Строки*], [*Символы*],
    "Urllib3", "58", "1848", "328", "9936",
    "Psycopg2", "33", "790", "176", "5323",
    "Flask", [DSL: 71 #linebreak() C\# Script: 111], [DSL: 2793 #linebreak() C\# Script: 3993],
    "487", "16642"
  )
)<dsl-sharp-compare>

Таким образом, объём кода расширений на разработанном DSL меньше в 5-6 раз по сравнению с аналогичным на C\# Script, что указывает на выразительные способности языка.

== Резюме 

В данной главе демонстрируются возможности разработанного DSL на примере пяти проектов. Каждый из них демонстрирует различные аспекты языка: возможность описания источников, стоков и фильтрующих функций, возможность описания поведения кода, сохранение информации в поля объектов, совместное написание расширений на DSL и C\# Script. Выразительные способности языка подкрепляются численным сравнением объёма кода расширений на разработанном языке и на C\# Script.

Расширения получились читаемыми и их было легко писать. Значит, DSL пригоден к использованию программистом. Он предоставляет возможность описания функций и фреймворков с различной степенью детализации поведения и потоков данных. Решение позволяет переиспользовать код за счёт выделения функций и объектов. Оно совместимо с PT JSA, как было показано для различных проектов. Основным аспектом является то, что оно предоставляет абстракции от внутренних особенностей анализатора. Несмотря на то что от пользователя всё ещё требуются компетенции аналитика безопасной разработки приложений, разрабатывать расширения стало существенно проще. Таким образом, требования, поставленные в рамках Работы, были выполнены.
