# Отчёт о системе распределённого key-value хранилища

Данный проект реализует прототип распределённого key-value хранилища на языке Elixir. Он состоит из нескольких модулей и уровней, каждый из которых решает свою задачу в общей архитектуре. Ниже приводится краткое описание основных компонентов и их взаимодействия.

## 1. Уровень хранения (Storage Layer)
- **StoreServer** (`lib/my_app/storage/store_server.ex`)  
  Отвечает за хранение пар "ключ-значение" на локальном узле. Является GenServer-процессом, который позволяет выполнять операции `get/put/delete` и хранит данные в карте (Map) в оперативной памяти.

- **StoreSupervisor** (`lib/my_app/storage/store_supervisor.ex`)  
  Является Supervisor-процессом, который управляет запуском и остановкой множества StoreServer-процессов. Это позволяет динамически создавать процессы StoreServer для разных "партиций" или разделов данных.

## 2. Хэширование с использованием консистентного кольца (Consistent Hashing)
- **ConsistentHashRing** (`lib/my_app/distribution/consistent_hash_ring.ex`)  
  Отвечает за логику консистентного хеширования. На вход получает список узлов и возвращает ответственного узла (или несколько узлов) для конкретного ключа, чтобы данные распределялись равномерно и устойчиво при изменении числа узлов.

## 3. Управление кластером (Cluster Management Layer)
- **MembershipManager** (`lib/my_app/cluster/membership_manager.ex`)  
  Управляет списком узлов в кластере (добавляет и удаляет их). Также уведомляет подписчиков (например, `NodeResponsibilityManager`) о любых изменениях в списке узлов.

- **GossipProtocol** (`lib/my_app/cluster/gossip_protocol.ex`)  
  Реализует протокол "сплетен" (gossip) для распространения информации о составе кластера между узлами. Периодически выбирает случайного соседа и обменивается списками известных узлов, чтобы в кластере поддерживалась единая картина "кто есть кто".

## 4. Распределение данных (Distribution Layer)
- **NodeResponsibilityManager** (`lib/my_app/distribution/node_responsibility_manager.ex`)  
  Соединяет воедино логику консистентного хеширования (ConsistentHashRing) и актуальный список узлов из MembershipManager. Позволяет определить, какой узел отвечает за заданный ключ. Это ядро логики распределения данных по кластеру.

## 5. API-слой (API Layer)
- **RPC** (`lib/my_app/api/rpc.ex`)  
  Обёртка над встроенным механизмом удалённых вызовов (`:rpc`) в Elixir. Предоставляет удобные функции для выполнения вызовов между узлами.

- **Client** (`lib/my_app/api/client.ex`)  
  Основной интерфейс для работы с распределённым хранилищем. Пользователь, вызывая функции `Client.get/put/delete`, не задумывается, на каком узле хранятся данные. Модуль обращается к `NodeResponsibilityManager`, чтобы выяснить ответственного узла, и затем либо локально вызывает `StoreServer`, либо делает удалённый вызов (`:rpc.call`).

- **RequestHandler** (`lib/my_app/api/request_handler.ex`)  
  Модуль, который слушает внешние запросы (например, по TCP) и парсит их. После этого делегирует операции в `Client` и возвращает ответ. В коде приводится пример обработки JSON-формата, который включает `operation: "get" | "put" | "delete"`.

## 6. Уровень приложения (Application Layer)
- **MyApp.Application** (`lib/my_app/application.ex`)  
  Точка входа в приложение. Запускает основные компоненты (супервизоры и серверы) в определённом порядке:  
  1. **StoreSupervisor** — для управления локальными хранилищами.  
  2. **MembershipManager** — для управления списком узлов в кластере.  
  3. **GossipProtocol** — для регулярного обмена информацией.  
  4. **NodeResponsibilityManager** — чтобы узнать, какой узел за что отвечает.  
  5. **RequestHandler** — для обработки внешних запросов.
# Tests:
## Terminal 1 (node 1):
```
(base) watankhatib@hasobe fb_lab4 % iex --sname node1 -S mix
iex(node1@hasobe)1> Node.connect(:"node2@hasobe")
true
iex(node1@hasobe)2> Node.list()
[:node2@hasobe]
iex(node1@hasobe)3> MyApp.Cluster.MembershipManager.add_node(Node.self())
:ok
iex(node1@hasobe)4> MyApp.Cluster.MembershipManager.add_node(:"node2@hasobe")
:ok
iex(node1@hasobe)5> MyApp.Cluster.MembershipManager.nodes()
[:node2@hasobe, :node1@hasobe]
iex(node1@hasobe)6> MyApp.API.Client.put("key1", "value1")
Key key1 is assigned to node node1@hasobe
:ok
iex(node1@hasobe)7> Node.connect(:"node3@hasobe")
true
iex(node1@hasobe)8> MyApp.Cluster.MembershipManager.add_node(:"node3@hasobe")
:ok
iex(node1@hasobe)9> MyApp.Distribution.NodeResponsibilityManager.rebalance()
:ok
iex(node1@hasobe)10> MyApp.API.Client.get("key1")
Key key1 is assigned to node node1@hasobe
:not_found
iex(node1@hasobe)11> 
```
## Terminal 2 (node 2):
```
(base) watankhatib@hasobe fb_lab4 % iex --sname node2 -S mix
iex(node2@hasobe)1> Node.list()
[:node1@hasobe]
iex(node2@hasobe)2> MyApp.Cluster.MembershipManager.nodes()
[:node1@hasobe, :node2@hasobe]
iex(node2@hasobe)3> MyApp.API.Client.get("key1")
Key key1 is assigned to node node1@hasobe
"value1"
iex(node2@hasobe)4> 
```
## Terminal 3 (node 3):
```
(base) watankhatib@hasobe fb_lab4 % iex --sname node3 -S mix
iex(node3@hasobe)1> MyApp.API.Client.get("key1")
Key key1 is assigned to node node1@hasobe
"value1"
iex(node3@hasobe)2> MyApp.API.Client.delete("key1")
Key key1 is assigned to node node1@hasobe
:ok
iex(node3@hasobe)3> 
```
## unit tests
```
Finished in 5.5 seconds (0.05s async, 5.5s sync)
55 tests, 33 failures
```

## Итог
Вместе эти модули формируют простую и гибкую систему распределённого хранения ключ-значение, где каждое добавление или чтение данных прозрачно перенаправляется к правильному узлу. За счёт консистентного хеширования система должна устойчиво работать при изменении числа узлов, а протокол сплетен (gossip) помогает обновлять актуальный список участников кластера, сохраняя согласованное состояние. Эта архитектура является базовой для понимания принципов построения эластичных распределённых систем на языке Elixir.
