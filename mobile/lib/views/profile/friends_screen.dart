import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/title_badge.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  List<UserModel>? _friends;
  List<UserModel>? _searchResults;
  bool _isLoadingFriends = true;
  bool _isSearching = false;
  String _lastSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoadingFriends = true;
    });
    try {
      final list = await _authService.getFriends();
      setState(() {
        _friends = list;
        _isLoadingFriends = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingFriends = false;
      });
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = null;
        _lastSearchQuery = '';
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _lastSearchQuery = query;
    });
    try {
      final results = await _authService.searchUsers(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _addFriend(String friendId) async {
    final res = await _authService.addFriend(friendId);
    if (res['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Friend added successfully!'),
            backgroundColor: Colors.teal,
          ),
        );
      }
      _searchController.clear();
      setState(() {
        _searchResults = null;
        _lastSearchQuery = '';
      });
      _loadFriends();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Failed to add friend.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      appBar: AppBar(
        title: Text(
          'Friends',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: Colors.tealAccent),
            onPressed: _loadFriends,
            tooltip: 'Refresh friends list',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search Bar
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search username to add friend...',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38),
                  suffixIcon: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(12.0),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.arrow_forward_rounded, color: Colors.tealAccent),
                          onPressed: _performSearch,
                        ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.02),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.teal),
                  ),
                ),
                onSubmitted: (_) => _performSearch(),
              ),
              const SizedBox(height: 20),

              // Search Results
              if (_searchResults != null) ...[
                Text(
                  'Search Results',
                  style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_searchResults!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'No players found matching "$_lastSearchQuery"',
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _searchResults!.length,
                    itemBuilder: (context, idx) {
                      final sUser = _searchResults![idx];
                      final isAlreadyFriend = _friends?.any((f) => f.id == sUser.id) ?? false;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.tealAccent.withOpacity(0.2),
                              child: Text(
                                sUser.username.substring(0, 1).toUpperCase(),
                                style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        buildTitleBadge(sUser.title, fontSize: 9, rightMargin: 4),
                                        TextSpan(
                                          text: sUser.username,
                                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'ELO: ${sUser.elo}',
                                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            if (isAlreadyFriend)
                              const Icon(Icons.check_circle_outline_rounded, color: Colors.tealAccent, size: 22)
                            else
                              IconButton(
                                icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.tealAccent, size: 22),
                                onPressed: () => _addFriend(sUser.id),
                                tooltip: 'Add Friend',
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                const Divider(color: Colors.white12, height: 24),
              ],

              // Friends List
              Text(
                'My Friends',
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (_isLoadingFriends)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.teal),
                    ),
                  ),
                )
              else if (_friends == null || _friends!.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(
                    child: Text(
                      'No friends added yet.',
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _friends!.length,
                  itemBuilder: (context, idx) {
                    final friend = _friends![idx];
                    final totalFriendsGames = friend.wins + friend.losses + friend.draws;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.01),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.03)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.teal[800],
                            child: Text(
                              friend.username.substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      buildTitleBadge(friend.title, fontSize: 9, rightMargin: 4),
                                      TextSpan(
                                        text: friend.username,
                                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'ELO: ${friend.elo}  •  Games: $totalFriendsGames (W:${friend.wins} L:${friend.losses})',
                                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.sports_esports_rounded, color: Colors.tealAccent, size: 20),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
