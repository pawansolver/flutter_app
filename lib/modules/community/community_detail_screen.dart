import 'package:flutter/material.dart';

class CommunityDetailScreen extends StatefulWidget {
  final Map<String, dynamic> group;
  const CommunityDetailScreen({Key? key, required this.group}) : super(key: key);

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  final List<Map<String, dynamic>> _posts = [
    {
      'author': 'Rahul Singh',
      'time': '2 hrs ago',
      'content': 'Anyone up for a quick match this evening around 5 PM? The weather looks great!',
      'likes': 4,
      'comments': 2,
    },
    {
      'author': 'Vikram Patel',
      'time': 'Yesterday',
      'content': 'We need to decide on the kit colors for the upcoming friendly tournament next month. Suggestions?',
      'likes': 12,
      'comments': 8,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE1EAE4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.group['title'],
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text(
              'Invite',
              style: TextStyle(
                color: Color(0xFFFF6B00),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE5E7EB), height: 1.0),
        ),
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Center(
                    child: Icon(Icons.image_outlined, color: Colors.grey, size: 40),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.group['description'] ?? 'A community group for enthusiasts.',
                  style: const TextStyle(color: Color(0xFF4B5563), fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Row(
                      children: List.generate(4, (index) {
                        return Align(
                          widthFactor: 0.7,
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.primaries[index % Colors.primaries.length].withOpacity(0.2),
                            child: Icon(Icons.person, size: 18, color: Colors.primaries[index % Colors.primaries.length]),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.group['members']} members',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          
          // Private Feed
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Create Post Input Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.edit_outlined, color: Colors.grey, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Share with the group...',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Posts List
                ..._posts.map((post) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.blue.shade50,
                              child: Text(
                                post['author'][0],
                                style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post['author'],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827)),
                                  ),
                                  Text(
                                    post['time'],
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          post['content'],
                          style: const TextStyle(color: Color(0xFF111827), fontSize: 14, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.thumb_up_alt_outlined, size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text('${post['likes']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            const SizedBox(width: 16),
                            Icon(Icons.comment_outlined, size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text('${post['comments']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
