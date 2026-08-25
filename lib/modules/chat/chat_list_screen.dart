import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/socket_service.dart';
import 'chat_window_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _chatService = ChatService();
  final _authService = AuthService();
  final _socketService = SocketService();

  List<ChatModel> _chats = [];
  final Map<int, bool> _presenceByUserId = {};
  bool _isLoading = true;
  String? _error;
  int? _currentUserId;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _currentUserId = await _authService.getUserId();
    if (_currentUserId != null) {
      // Connect socket if not already
      await _socketService.connect(_currentUserId!);
      // Listen for presence updates to refresh online status
      _socketService.addPresenceListener(_onPresenceChange);
    }
    await _loadChats();
  }

  Future<void> _loadChats() async {
    if (_currentUserId == null) {
      setState(() {
        _isLoading = false;
        _error = 'Could not identify user. Please log in again.';
      });
      return;
    }
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final chats = await _chatService.getMyChats(_currentUserId!);
      if (mounted) {
        setState(() {
          _chats = chats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _onPresenceChange(int userId, bool isOnline) {
    if (!mounted) return;
    setState(() => _presenceByUserId[userId] = isOnline);
  }

  @override
  void dispose() {
    _socketService.removePresenceListener(_onPresenceChange);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.black, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Search chats...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
              )
            : const Text(
                'Messages',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search, color: Colors.black),
              onPressed: () {
                setState(() => _isSearching = true);
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: _loadChats,
              ),
            ],
          ),
        ),
      );
    }

    final filteredChats = _chats.where((c) {
      return c.displayName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (_chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 72,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'No conversations yet',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start a chat with someone nearby!',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (filteredChats.isEmpty) {
      return Center(
        child: Text(
          'No chats found for "$_searchQuery"',
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.black,
      onRefresh: _loadChats,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: filteredChats.length,
        itemBuilder: (context, index) => _buildChatTile(filteredChats[index]),
      ),
    );
  }

  Widget _buildChatTile(ChatModel chat) {
    final isOnline = _presenceByUserId[chat.otherUserId] ?? chat.isOnline;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatWindowScreen(
              chatId: chat.id,
              chatName: chat.displayName,
              avatarUrl: chat.avatarUrl,
              isOnline: isOnline,
              currentUserId: _currentUserId ?? 0,
              recipientUserId: chat.otherUserId,
              recipientPhone: chat.otherUserPhone,
            ),
          ),
        ).then((_) => _loadChats()); // Refresh unread after returning
      },
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            CircleAvatar(
              radius: 26,
              backgroundColor: _avatarColor(chat.displayName),
              backgroundImage: chat.avatarUrl != null
                  ? NetworkImage(chat.avatarUrl!)
                  : null,
              child: chat.avatarUrl == null
                  ? Text(
                      chat.avatarInitial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            // Chat info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    chat.lastMessage ?? 'No messages yet',
                    style: const TextStyle(
                      color: Color(0xFFBAC5D0),
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Time + unread badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  chat.formattedTime,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                if (chat.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF6B00), // SmartGali Orange unread badge
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFFFF6B00),
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFFF59E0B),
    ];
    return colors[(name.isEmpty ? 0 : name.codeUnitAt(0)) % colors.length];
  }
}
