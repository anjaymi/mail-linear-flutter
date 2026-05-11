import 'package:flutter_test/flutter_test.dart';
import 'package:mail_linear_flutter/core/api/mail_api.dart';
import 'package:mail_linear_flutter/core/models/mail_item.dart';

void main() {
  group('MailFetchResult.sourceLabel', () {
    test('cache protocol displays local cache label', () {
      const result = MailFetchResult(
        mails: <MailItem>[],
        protocol: 'cache',
        cached: true,
        partialCached: false,
        warning: '',
        newCount: 0,
      );

      expect(result.sourceLabel, '本地缓存');
    });

    test('outlook protocol with partial cached displays mixed label', () {
      const result = MailFetchResult(
        mails: <MailItem>[],
        protocol: 'outlook',
        cached: true,
        partialCached: true,
        warning: '',
        newCount: 0,
      );

      expect(result.sourceLabel, 'Outlook 实时/缓存混合');
    });

    test('imap protocol with cached displays cache label', () {
      const result = MailFetchResult(
        mails: <MailItem>[],
        protocol: 'imap',
        cached: true,
        partialCached: false,
        warning: '',
        newCount: 0,
      );

      expect(result.sourceLabel, 'IMAP 缓存');
    });

    test('graph protocol without cached displays realtime label', () {
      const result = MailFetchResult(
        mails: <MailItem>[],
        protocol: 'graph',
        cached: false,
        partialCached: false,
        warning: '',
        newCount: 0,
      );

      expect(result.sourceLabel, 'Graph 实时');
    });

    test('traceSummary reports cache mismatch and empty bodies', () {
      const result = MailFetchResult(
        mails: <MailItem>[],
        protocol: 'imap',
        cached: false,
        partialCached: false,
        warning: '',
        newCount: 1,
        trace: <String, dynamic>{
          'source': 'imap',
          'selectedMailbox': 'INBOX',
          'resultCount': 3,
          'cacheBefore': 10,
          'cacheAfter': 11,
          'cacheContainsNewest': false,
          'bodylessCacheCount': 2,
        },
      );

      expect(
        result.traceSummary,
        '诊断：imap / INBOX，返回 3 封，缓存 10->11，新增 1 封，最新邮件未进入缓存，空正文 2 封',
      );
    });
  });

  group('MailItem.fromJson', () {
    test(
      'uses fallback subject, derives text from html, and reads received_at',
      () {
        final item = MailItem.fromJson(<String, dynamic>{
          'id': 42,
          'account_id': 7,
          'subject': '   ',
          'sender': 'sender@example.com',
          'sender_name': 'Sender Name',
          'mailbox_email': 'inbox@example.com',
          'mailbox': 'inbox',
          'html_content': '<div>Hello&nbsp;<b>World</b>&Friends</div>',
          'received_at': '2026-05-09T12:34:56Z',
        });

        expect(item.id, 42);
        expect(item.accountId, 7);
        expect(item.subject, '(无主题)');
        expect(item.sender, 'sender@example.com');
        expect(item.senderName, 'Sender Name');
        expect(item.mailboxEmail, 'inbox@example.com');
        expect(item.mailbox, 'inbox');
        expect(item.htmlContent, '<div>Hello&nbsp;<b>World</b>&Friends</div>');
        expect(item.preview, 'Hello World &Friends');
        expect(item.bodyText, 'Hello World &Friends');
        expect(item.date, '2026-05-09T12:34:56Z');
      },
    );
  });
}
