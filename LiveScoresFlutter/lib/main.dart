import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.汇';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

void main() {
  runApp(const LiveScoresApp());
}

class LiveScoresApp extends StatelessWidget {
  const LiveScoresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Football Scores',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A192F),
        primaryColor: const Color(0xFF64FFDA),
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF64FFDA),
          secondary: Color(0xFF64FFDA),
          surface: Color(0xFF112240),
        ),
      ),
      home: const DashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final String _apiKey = 'ae33e14a2cd1415089d79e1edfbc4d8d';
  final String _baseUrl = 'https://api.football-data.org/v4';
  
  List<dynamic> _matches = [];
  bool _isLoading = true;
  String _error = '';
  Timer? _pollingTimer;
  
  String _currentFilter = 'CL'; // 'CL' or 'RMA'
  DateTime _currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchMatches();
    // Poll every 15 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _fetchMatches(isPolling: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchMatches({bool isPolling = false}) async {
    if (!isPolling) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }

    try {
      String endpoint = '';
      if (_currentFilter == 'CL') {
        endpoint = '/competitions/CL/matches';
      } else {
        endpoint = '/teams/86/matches';
      }
      
      final dateStr = DateFormat('yyyy-MM-dd').format(_currentDate);
      final url = Uri.parse('$_baseUrl$endpoint?dateFrom=$dateStr&dateTo=$dateStr');
      
      final response = await http.get(
        url,
        headers: {'X-Auth-Token': _apiKey},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _matches = data['matches'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load matches: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  void _changeDate(int days) {
    setState(() {
      _currentDate = _currentDate.add(Duration(days: days));
    });
    _fetchMatches();
  }

  void _setFilter(String filter) {
    if (_currentFilter == filter) return;
    setState(() {
      _currentFilter = filter;
    });
    _fetchMatches();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Live Football Scores', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Filter Badges
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFilterBadge('CL', 'Champions League', 'https://crests.football-data.org/CL.png'),
                const SizedBox(width: 16),
                _buildFilterBadge('RMA', 'Real Madrid', 'https://crests.football-data.org/86.png'),
              ],
            ),
            const SizedBox(height: 24),
            
            // Date Scroller
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_left),
                  onPressed: () => _changeDate(-1),
                  color: Theme.of(context).primaryColor,
                  iconSize: 32,
                ),
                Text(
                  DateFormat('EEE, MMM d, yyyy').format(_currentDate),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_right),
                  onPressed: () => _changeDate(1),
                  color: Theme.of(context).primaryColor,
                  iconSize: 32,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Main Content
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                  ? Center(child: Text(_error, style: const TextStyle(color: Colors.redAccent)))
                  : _matches.isEmpty
                    ? const Center(child: Text('No matches scheduled for this date.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _matches.length,
                        itemBuilder: (context, index) {
                          final match = _matches[index];
                          return _buildMatchCard(match);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBadge(String id, String tooltip, String imageUrl) {
    final isSelected = _currentFilter == id;
    return GestureDetector(
      onTap: () => _setFilter(id),
      child: Tooltip(
        message: tooltip,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
              width: 3,
            ),
            color: Colors.white,
          ),
          child: ClipOval(
            child: Image.network(
              imageUrl,
              width: 50,
              height: 50,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.sports_soccer, size: 50, color: Colors.black),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match) {
    final homeTeam = match['homeTeam']['name'] ?? 'Home';
    final awayTeam = match['awayTeam']['name'] ?? 'Away';
    final status = match['status'] ?? 'UNKNOWN';
    final score = match['score']['fullTime'];
    final homeScore = score['home'] ?? 0;
    final awayScore = score['away'] ?? 0;
    
    final isLive = status == 'IN_PLAY' || status == 'PAUSED';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            match['competition']['name'] ?? '',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  homeTeam,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    Text(
                      status == 'SCHEDULED' ? 'v' : '$homeScore - $awayScore',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    if (isLive)
                      Container(
                        margin: const EdgeInsets.top(4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Colors.redAccent, size: 8),
                            SizedBox(width: 4),
                            Text('LIVE', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    else
                      Text(
                        status,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  awayTeam,
                  textAlign: TextAlign.left,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
