import 'dart:async';
import 'package:flutter/material.dart'; // Importe o pacote Flutter material
import 'package:rxdart/rxdart.dart'; // Importe o pacote rxdart

// --- 1. Serviço Mockado de Busca (Simula uma API) ---
class MockSearchService {
  final List<String> _data = [
    'apple',
    'banana',
    'apricot',
    'blueberry',
    'orange',
    'grape',
    'avocado',
    'kiwi',
    'strawberry',
    'watermelon',
    'lemon',
    'lime',
    'mango',
    'peach',
    'pear',
    'pineapple',
  ];

  /// Simula uma busca assíncrona por um termo.
  /// Retorna uma lista de frutas que contêm o termo.
  Future<List<String>> search(String query) async {
    print('>>> API: Buscando por "$query"...');
    // Simula um atraso de rede (500ms)
    await Future.delayed(Duration(milliseconds: 500));

    if (query.isEmpty) {
      return _data; // Retorna tudo se a busca for vazia
    }

    final lowerCaseQuery = query.toLowerCase();
    return _data
        .where((item) => item.toLowerCase().contains(lowerCaseQuery))
        .toList();
  }
}

// --- 2. BLoC de Busca (Lógica com RxDart) ---
class SearchBloc {
  final MockSearchService _searchService = MockSearchService();

  // Stream de entrada: Onde a UI (campo de texto) vai enviar os termos de busca
  final _searchQueryController = PublishSubject<String>();
  Sink<String> get searchQuery => _searchQueryController.sink;

  // Stream de saída: Onde a UI vai receber os resultados da busca
  final _searchResultsController = BehaviorSubject<List<String>>.seeded([]);
  Stream<List<String>> get searchResults => _searchResultsController.stream;

  SearchBloc() {
    _searchQueryController.stream
        .debounceTime(
          const Duration(milliseconds: 300),
        ) // Espera 300ms de "silêncio"
        .distinct() // Ignora termos repetidos
        .switchMap(
          (query) => Stream.fromFuture(_searchService.search(query)),
        ) // Cancela buscas antigas
        .listen(
          (results) {
            _searchResultsController.add(
              results,
            ); // Envia os resultados para a UI
          },
          onError: (error) {
            print('!!! ERRO no BLoC: $error');
            _searchResultsController.addError(error); // Encaminha o erro
          },
        );
  }

  // Método para liberar recursos (ESSENCIAL!)
  void dispose() {
    print('>>> BLoC: Fechando controladores...');
    _searchQueryController.close();
    _searchResultsController.close();
  }
}

// --- 3. Widget Principal do Aplicativo Flutter ---

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RxDart Search Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SearchScreen(),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // Instância do nosso BLoC
  late final SearchBloc _searchBloc;

  @override
  void initState() {
    super.initState();
    _searchBloc = SearchBloc();
    // Inicia a busca com um termo vazio para carregar todos os itens
    _searchBloc.searchQuery.add('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscador de Frutas com RxDart')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Digite para buscar',
                hintText: 'Ex: apple, banana, etc.',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (text) {
                // Ao digitar, adiciona o termo ao Sink de entrada do BLoC
                _searchBloc.searchQuery.add(text);
              },
            ),
            const SizedBox(height: 20),
            // StreamBuilder: Reconstrói a UI sempre que um novo resultado chega
            Expanded(
              child: StreamBuilder<List<String>>(
                stream:
                    _searchBloc
                        .searchResults, // Escuta a Stream de resultados do BLoC
                builder: (context, snapshot) {
                  // Se houver erro
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Erro: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }
                  // Se ainda não tiver dados (pode acontecer na primeira carga ou se o debounce estiver ativo)
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Se a lista de dados estiver vazia
                  final results = snapshot.data!;
                  if (results.isEmpty) {
                    return const Center(
                      child: Text('Nenhum resultado encontrado.'),
                    );
                  }

                  // Exibe os resultados em uma ListView
                  return ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ListTile(title: Text(results[index])),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // ESSENCIAL: Chamar dispose no BLoC quando o Widget é removido
    _searchBloc.dispose();
    super.dispose();
  }
}
