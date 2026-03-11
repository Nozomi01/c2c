import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('マイページ'),
      ),
      body: ListView(
        children: [
          if (user != null)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(user.phoneNumber ?? user.email ?? 'ゲスト'),
              subtitle: const Text('プロフィールを編集'),
              onTap: () {
                // TODO: navigate to profile edit
              },
            ),
          const Divider(),
          const ListTile(
            title: Text('ウォレット残高'),
            subtitle: Text('¥0（ストライプと連携）'),
          ),
          const ListTile(
            title: Text('出品中のサービス'),
          ),
          const ListTile(
            title: Text('購入履歴'),
          ),
          const ListTile(
            title: Text('お気に入り'),
          ),
          const Divider(),
          const ListTile(
            title: Text('設定'),
          ),
        ],
      ),
    );
  }
}

