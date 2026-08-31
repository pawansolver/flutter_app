import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/core/api_config.dart';
import 'package:my_first_app/models/community_models.dart';
import 'package:my_first_app/services/community_service.dart';

void main() {
  test('community model preserves pending join and normalizes media', () {
    final community = CommunityModel.fromJson({
      'communityId': 7,
      'communityName': 'Residents',
      'cover_image': '/uploads/community/cover.jpg',
      'hasPendingRequest': true,
      'created_at': '2026-08-30T10:00:00.000Z',
    });

    expect(community.id, 7);
    expect(community.joinStatus, CommunityJoinStatus.pending);
    expect(community.isMember, isFalse);
    expect(community.coverImageUrl, contains('/uploads/community/cover.jpg'));
    expect(community.createdAt, DateTime.utc(2026, 8, 30, 10));
  });

  test('API builders use nested backend community routes', () {
    expect(
      ApiConfig.communityMemberRole(4, 9),
      endsWith('/communities/4/members/9/role'),
    );
    expect(
      ApiConfig.respondCommunityInvitation(4, 12),
      endsWith('/communities/4/invitations/12/respond'),
    );
    expect(
      ApiConfig.communityEventRsvp(4, 6),
      endsWith('/communities/4/events/6/rsvp'),
    );
    expect(
      ApiConfig.myCommunityInvitations,
      endsWith('/communities/invitations'),
    );
    expect(ApiConfig.communityChat(4), endsWith('/communities/4/chat'));
  });

  test('join exposes private-community pending state', () async {
    final adapter = _QueueAdapter([
      _jsonResponse(201, {
        'success': true,
        'data': {
          'isPending': true,
          'request': {'id': 3},
        },
      }),
    ]);
    final dio = Dio()..httpClientAdapter = adapter;
    final service = CommunityService.forTesting(
      dio,
      tokenProvider: () async => 'token',
    );

    final result = await service.joinCommunity(5, note: 'Please add me');

    expect(result.isPending, isTrue);
    expect(adapter.requests.single.path, ApiConfig.joinCommunity(5));
    expect(adapter.requests.single.data, {'note': 'Please add me'});
  });

  test('feed parses cursor wrapper and exact engagement fields', () async {
    final adapter = _QueueAdapter([
      _jsonResponse(200, {
        'success': true,
        'data': {
          'posts': [
            {
              'id': 11,
              'communityId': 5,
              'content': 'Update',
              'author': {
                'userId': 42,
                'fullName': 'Asha',
                'avatarUrl': '/uploads/avatar.jpg',
              },
              'likeCount': 2,
              'commentCount': 3,
              'isLikedByMe': true,
              'createdAt': '2026-08-30T10:00:00.000Z',
            },
          ],
          'nextCursor': 'bmV4dA==',
          'hasMore': true,
        },
      }),
    ]);
    final dio = Dio()..httpClientAdapter = adapter;
    final service = CommunityService.forTesting(
      dio,
      tokenProvider: () async => null,
    );

    final page = await service.getCommunityFeedPage(5);

    expect(page.hasMore, isTrue);
    expect(page.nextCursor, 'bmV4dA==');
    expect(page.posts.single.likesCount, 2);
    expect(page.posts.single.commentsCount, 3);
    expect(page.posts.single.isLikedByMe, isTrue);
    expect(page.posts.single.communityId, 5);
    expect(page.posts.single.authorId, 42);
    expect(page.posts.single.authorName, 'Asha');
  });

  test('invitation inbox parses nested community and inviter', () async {
    final adapter = _QueueAdapter([
      _jsonResponse(200, {
        'success': true,
        'data': {
          'invitations': [
            {
              'id': 8,
              'community_id': 5,
              'invited_user_id': 42,
              'status': 'pending',
              'community': {
                'communityId': 5,
                'communityName': 'Residents',
              },
              'inviter': {'userName': 'admin'},
            },
          ],
          'total': 1,
          'page': 1,
          'totalPages': 1,
        },
      }),
    ]);
    final service = CommunityService.forTesting(
      Dio()..httpClientAdapter = adapter,
      tokenProvider: () async => 'token',
    );

    final page = await service.getMyInvitations();

    expect(page.items.single.community?.name, 'Residents');
    expect(page.items.single.inviterName, 'admin');
  });

  test('service propagates backend API errors without fake success', () async {
    final adapter = _QueueAdapter([
      _jsonResponse(403, {'success': false, 'message': 'Admin role required'}),
    ]);
    final dio = Dio()..httpClientAdapter = adapter;
    final service = CommunityService.forTesting(
      dio,
      tokenProvider: () async => 'token',
    );

    expect(
      () => service.removeMember(5, 99),
      throwsA(
        isA<CommunityServiceException>()
            .having((error) => error.statusCode, 'statusCode', 403)
            .having((error) => error.message, 'message', 'Admin role required'),
      ),
    );
  });

  test('community chat resolves backend chat ID', () async {
    final adapter = _QueueAdapter([
      _jsonResponse(200, {
        'success': true,
        'data': {'id': 321, 'chat_type': 'community'},
      }),
    ]);
    final dio = Dio()..httpClientAdapter = adapter;
    final service = CommunityService.forTesting(
      dio,
      tokenProvider: () async => 'token',
    );

    expect(await service.getCommunityChatId(5), 321);
    expect(adapter.requests.single.path, ApiConfig.communityChat(5));
  });
}

ResponseBody _jsonResponse(int statusCode, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(this._responses);

  final List<ResponseBody> _responses;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await requestStream?.drain<void>();
    return _responses.removeAt(0);
  }

  @override
  void close({bool force = false}) {}
}
