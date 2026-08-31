import 'package:flutter/material.dart';

import '../../models/community_models.dart';
import '../../services/community_service.dart';
import 'community_detail_screen.dart';

class CommunityInvitationsScreen extends StatefulWidget {
  const CommunityInvitationsScreen({super.key});

  @override
  State<CommunityInvitationsScreen> createState() =>
      _CommunityInvitationsScreenState();
}

class _CommunityInvitationsScreenState
    extends State<CommunityInvitationsScreen> {
  final CommunityService _service = CommunityService();
  List<CommunityInvitationModel> _invitations = [];
  final Set<int> _responding = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _service.getMyInvitations();
      if (!mounted) return;
      setState(() {
        _invitations = page.items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _respond(
    CommunityInvitationModel invitation,
    String action,
  ) async {
    if (_responding.contains(invitation.id)) return;
    setState(() => _responding.add(invitation.id));
    try {
      await _service.respondToInvitation(
        invitation.communityId,
        invitation.id,
        action,
      );
      if (!mounted) return;
      setState(() => _invitations.removeWhere((item) => item.id == invitation.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'accept' ? 'Invitation accepted' : 'Invitation declined',
          ),
        ),
      );
      if (action == 'accept' && invitation.community != null) {
        final details = await _service.getCommunityDetails(invitation.communityId);
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommunityDetailScreen(community: details),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _responding.remove(invitation.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community Invitations')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : _invitations.isEmpty
          ? const Center(child: Text('No pending invitations'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _invitations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final invitation = _invitations[index];
                  final community = invitation.community;
                  final busy = _responding.contains(invitation.id);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            community?.name ?? 'Community invitation',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (invitation.inviterName != null)
                            Text('Invited by ${invitation.inviterName}'),
                          if (community?.description?.isNotEmpty == true) ...[
                            const SizedBox(height: 6),
                            Text(
                              community!.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => _respond(invitation, 'decline'),
                                child: const Text('Decline'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: busy
                                    ? null
                                    : () => _respond(invitation, 'accept'),
                                child: busy
                                    ? const SizedBox.square(
                                        dimension: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Accept'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
