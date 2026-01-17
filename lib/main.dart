import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_manager.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Esperanto Critique Tool',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Esperanto Critique Tool'),
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: Colors.green,
            child: const Center(
              child: Text(
                'Esperanto Critique Tool',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HostGameScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 60),
                        textStyle: const TextStyle(fontSize: 20),
                      ),
                      child: const Text('Host'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const JoinGameScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 60),
                        textStyle: const TextStyle(fontSize: 20),
                      ),
                      child: const Text('Join'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GameScreen(gameMode: 'solo'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 60),
                        textStyle: const TextStyle(fontSize: 20),
                      ),
                      child: const Text('Solo'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HostGameScreen extends StatefulWidget {
  const HostGameScreen({super.key});

  @override
  State<HostGameScreen> createState() => _HostGameScreenState();
}

class _HostGameScreenState extends State<HostGameScreen> {
  String? _gameCode;
  String _gameName = '';
  List<String> _connectedPlayers = [];
  final TextEditingController _nameController = TextEditingController();
  final BleManager _bleManager = BleManager();
  bool _isHosting = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _generateGameCode();
    _requestPermissions();

    // Listen for connection status
    _bleManager.connectionStatusStream.listen((status) {
      setState(() {
        _statusMessage = status;
      });
    });

    // Listen for players joining
    _bleManager.playerJoinedStream.listen((playerData) {
      setState(() {
        _connectedPlayers.add(playerData['playerName'] as String);
      });
    });
  }

  void _generateGameCode() {
    final random = Random();
    setState(() {
      _gameCode = (100000 + random.nextInt(900000)).toString();
    });
  }

  Future<void> _requestPermissions() async {
    bool granted = await _bleManager.requestPermissions();
    if (!granted) {
      setState(() {
        _statusMessage = 'Bluetooth permissions not granted';
      });
    }
  }

  Future<void> _startHosting() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a game name')),
      );
      return;
    }

    bool bleAvailable = await _bleManager.isBluetoothAvailable();
    if (!bleAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bluetooth is not available or turned off')),
      );
      return;
    }

    setState(() {
      _gameName = _nameController.text;
      _isHosting = true;
    });

    await _bleManager.startHosting(_gameName, _gameCode!);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bleManager.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Host Game'),
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: Colors.green,
            child: const Center(
              child: Text(
                'Esperanto Critique Tool',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (!_isHosting) ...[
                    const Text(
                      'Enter Game Name:',
                      style: TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 250,
                      child: TextField(
                        controller: _nameController,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20),
                        decoration: const InputDecoration(
                          hintText: 'My Game',
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _startHosting,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 60),
                        textStyle: const TextStyle(fontSize: 20),
                      ),
                      child: const Text('Start Hosting'),
                    ),
                  ] else ...[
                    Text(
                      'Game: $_gameName',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Game Code:',
                      style: TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _gameCode ?? '',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      _statusMessage.isEmpty ? 'Waiting for players to join...' : _statusMessage,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (_connectedPlayers.isNotEmpty) ...[
                      const Text(
                        'Connected Players:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      ...(_connectedPlayers.map((player) => Text(player))),
                    ],
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GameScreen(
                              gameMode: 'host',
                              gameCode: _gameCode,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 60),
                        textStyle: const TextStyle(fontSize: 20),
                      ),
                      child: const Text('Start Game'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class JoinGameScreen extends StatefulWidget {
  const JoinGameScreen({super.key});

  @override
  State<JoinGameScreen> createState() => _JoinGameScreenState();
}

class _JoinGameScreenState extends State<JoinGameScreen> {
  final TextEditingController _codeController = TextEditingController();
  final BleManager _bleManager = BleManager();
  bool _searching = false;
  List<ScanResult> _foundGames = [];
  BluetoothDevice? _selectedDevice;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _requestPermissions();

    // Listen for connection status
    _bleManager.connectionStatusStream.listen((status) {
      setState(() {
        _statusMessage = status;
      });
    });
  }

  Future<void> _requestPermissions() async {
    bool granted = await _bleManager.requestPermissions();
    if (!granted) {
      setState(() {
        _statusMessage = 'Bluetooth permissions not granted';
      });
    }
  }

  Future<void> _searchForGames() async {
    bool bleAvailable = await _bleManager.isBluetoothAvailable();
    if (!bleAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bluetooth is not available or turned off')),
      );
      return;
    }

    setState(() {
      _searching = true;
      _foundGames = [];
      _statusMessage = 'Scanning for games...';
    });

    List<ScanResult> results = await _bleManager.scanForGames();

    setState(() {
      _searching = false;
      _foundGames = results;
      _statusMessage = results.isEmpty ? 'No games found' : 'Found ${results.length} game(s)';
    });
  }

  Future<void> _joinGame() async {
    if (_codeController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a 6-digit code')),
      );
      return;
    }

    if (_selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a game to join')),
      );
      return;
    }

    setState(() {
      _statusMessage = 'Connecting...';
    });

    bool connected = await _bleManager.connectToHost(_selectedDevice!, _codeController.text);

    if (connected) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GameScreen(
              gameMode: 'join',
              gameCode: _codeController.text,
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_statusMessage.isEmpty ? 'Connection failed' : _statusMessage)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Join Game'),
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: Colors.green,
            child: const Center(
              child: Text(
                'Esperanto Critique Tool',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (_searching)
                    const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text('Searching for games...'),
                      ],
                    )
                  else
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: _searchForGames,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(200, 60),
                            textStyle: const TextStyle(fontSize: 20),
                          ),
                          child: const Text('Search for Games'),
                        ),
                        const SizedBox(height: 20),
                        if (_statusMessage.isNotEmpty)
                          Text(
                            _statusMessage,
                            style: const TextStyle(fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        const SizedBox(height: 20),
                        if (_foundGames.isNotEmpty) ...[
                          const Text(
                            'Available Games:',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 150,
                            child: ListView.builder(
                              itemCount: _foundGames.length,
                              itemBuilder: (context, index) {
                                final result = _foundGames[index];
                                final deviceName = result.device.platformName.isEmpty
                                    ? 'Unknown Device'
                                    : result.device.platformName;
                                return ListTile(
                                  title: Text(deviceName),
                                  subtitle: Text('RSSI: ${result.rssi}'),
                                  selected: _selectedDevice == result.device,
                                  onTap: () {
                                    setState(() {
                                      _selectedDevice = result.device;
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        const Text(
                          'Enter Game Code:',
                          style: TextStyle(fontSize: 20),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: 250,
                          child: TextField(
                            controller: _codeController,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            style: const TextStyle(
                              fontSize: 32,
                              letterSpacing: 8,
                            ),
                            decoration: const InputDecoration(
                              hintText: '000000',
                              counterText: '',
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _joinGame,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(200, 60),
                            textStyle: const TextStyle(fontSize: 20),
                          ),
                          child: const Text('Join Game'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _bleManager.disconnect();
    super.dispose();
  }
}

class GameScreen extends StatefulWidget {
  final String gameMode;
  final String? gameCode;

  const GameScreen({
    super.key,
    required this.gameMode,
    this.gameCode,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  void _showGameMenu() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Game Menu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.gameCode != null) ...[
                const Text('Game Code:'),
                const SizedBox(height: 10),
                Text(
                  widget.gameCode!,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Text('Mode: ${widget.gameMode}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Game'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: _showGameMenu,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: Colors.green,
            child: const Center(
              child: Text(
                'Esperanto Critique Tool',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'Mode: ${widget.gameMode}',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'You have pushed the button this many times:',
                  ),
                  Text(
                    '$_counter',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
