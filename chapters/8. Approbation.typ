#import "../thesis-base.typ": *
#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.1": *
#import "@preview/curryst:0.5.1": rule, prooftree
#import "@preview/diagraph:0.3.3": *

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

#chapter(4, "Апробация полученных инструментов")

Данная глава содержит результаты апробации DSL и его транслятора в низкоуровневый код расширений PT JSA.

== Подход к апробации

Основной зоной применения PT JSA является анализ кода web-приложений на безопасность. Так как прототипы DSL и его транслятора предназначены для описания библиотек и фреймворков на языка Python, проекты, приведённые в этой главе, также написаны на этом языке. Они показывают реальные способы написания кода бэкэнда. 

В Главе рассмотрено несколько проектов. Каждый из них показывает пример использования библиотеки или фреймворка наиболее популярными способами, а также код для расширения PT JSA с поддержкой их. Список компонентов для демонстрации был составлен с учётом их популярности. Стоит отметить, что целью данной Главы не является проверка и демонстрация функциональных возможностей самого анализатора. По этому, примеры содержат простой код, целью которого является демонстрация сценариев использования внешних компонентов. Проекты не содержат намеренно сложный код, который мог бы привести к ложным срабатываниям анализатора. 

Для апробации код на DSL транслируется в низкоуровневый код для расширений, анализатор PT JSA запускается из терминала. Он пишет в журнал запись о каждой найденной уязвимости. Для краткости, пояснительная информация содержит только основные значения из срабатываний анализатора.

== Библиотека для HTTP запросов

Одной из популярных операций в бэкэнд приложениях является отправка HTTP запросов. Она необходима как для интеграции со внешними сервисами, так и для коммуникациями между микросервисами одной системы. 

Библиотека urllib3 предоставляет возможности для отправки HTTP запросов с различными опциями и получения ответа. Листинг @urllib3-app содержит пример кода обработки запроса с использованием фреймворка Flask. 

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
    # Server-Side Request Forgery
    response = urllib3.request('GET', url, { 'auth_token': token }) 

    with open(filename, 'wb') as f:
        f.write(response.data)

    print(f"Image saved as {filename}")
  ```
) <urllib3-app>

В Листинге @urllib3-app описана функция-обработчик HTTP GET запроса по относительному адресу _/save_profile_image_. Можно считать, что она позволяет сохранить фотографию пользователя после её загрузки на сервер. Обработчик принимает аргумент с именем _image_url_, содержащий адрес загруженного изображения и загружает его с использованием системного токена для идентификации и аутентификации. Для упрощения, последующая обработка данных, не относящаяся к демонстрации, была опущена. Так как в коде отсутствует проверка URL фотографии, клиент может совершить атаку, отправив произвольный адрес. Это может привести к:

- Отправке запросов с системным токеном на произвольный сервер;
- Загрузке файла с произвольным содержимым.

Первый пункт приведёт к раскрытию чувствительной информации, в то время как второй позволит атакующему загрузить файл с вредоносным кодом на сервер. Возможна также загрузка большого файла, что приведёт к отказу в обслуживании (_DOS_). Данная уязвимость называется "подделка запросов со стороны сервера" (_Server-side request forgery_) [TODO: https://owasp.org/www-community/attacks/Server_Side_Request_Forgery]. 

Для добавления поддержки библиотеки urllib3 в PT JSA был написан код на DSL, фрагмент которого приведён в Листинге @urllib3-descr. Он состоит из трёх файлов, которые подписаны комментариями. [TODO: ссылка на файл в репо]

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

В Листинге @urllib3-descr объект _HTTPResponse_ описывает для PT JSA одноимённый класс библиотеки urllib3. Он содержит несколько полей, содержащие потенциально заражённые данные, такие, как _status_ и _data_. Он содержит объект типа _HTTPConnection_, представленный в Листинге ниже, а также несколько функций. К примеру, функция _json_ в urllib3 возвращает тело ответа на запрос, десериализованное из JSON в произвольный объект. С точки зрения taint-анализа, она является источником заражённых данных, по этому, в коде её результатом является результат вызова функции _CreateTaintedDataOfType\<any>_, которая создаёт такой объект произвольного типа. 

Функции _request_ объекта _HTTPConnection_ и одноимённая функция пакета _urllib3_ отправляют HTTP запрос по указанному URL. Они содержат большое количество аргументов по-умолчанию. Каждая из них запускает операцию определения на аргументах _url_ и _headers_. В проверке для URL содержится уязвимость SSRF, в проверке для заголовков SSRF и Information Exposure (утечка чувствительной информации). 

Информация об уязвимости, найденной в коде в Листинге @urllib3-app с расширением из Листинга @urllib3-descr приведена в Таблице @urllib3-res. В ней видно, что найдена уязвимость указанного в коде на DSL типа на строке 13 в Листинге @urllib3-app. Можно заметить, что трасса данных приведена также корректно. 

#figure(
  caption: "Информация об уязвимости",
  table(
  columns: 2*(auto,),
  table.header("Параметр", "Значение"),
  "Тип", "Server-Side Request Forgery",
  "Уязвимое выражение", "response = urllib3.request('GET', url, { '...",
  "Точка входа", "def download_image(url, filename):",
  "Трасса данных", [
    image_url = request.args.get('image_url') #linebreak()
    download_image(image_url, temp_file) #linebreak()
    response = urllib3.request('GET', url, { 'auth_token': token })
  ]
)
) <urllib3-res>

Этот пример показывает, что разработанный DSL позволяет расширять базу знаний PT JSA элементарными библиотеками и позволяет описывать их с точки зрения анализа потока данных с достаточной для анализа точностью.

== 

