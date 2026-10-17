import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/bili.dart';
import '../ui/glass.dart';
import '../ui/theme.dart';

Future<void> showLogin(BuildContext context) => showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (_) => const _LoginDialog(),
    );

class _LoginDialog extends StatefulWidget {
  const _LoginDialog();
  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<_LoginDialog> {
  String? _url, _key, _error;
  String _status = '请使用哔哩哔哩 App 扫码登录';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _gen();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _gen() async {
    _timer?.cancel();
    setState(() {
      _url = null;
      _error = null;
      _status = '请使用哔哩哔哩 App 扫码登录';
    });
    try {
      final (url, key) = await Bili.instance.qrGenerate();
      if (!mounted) return;
      setState(() {
        _url = url;
        _key = key;
      });
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  bool _polling = false;
  Future<void> _poll() async {
    if (_polling || _key == null) return;
    _polling = true;
    try {
      final code = await Bili.instance.qrPoll(_key!);
      if (!mounted) return;
      switch (code) {
        case 0:
          _timer?.cancel();
          Navigator.of(context).pop();
          toast(context, '登录成功');
        case 86090:
          setState(() => _status = '已扫码，请在手机上确认');
        case 86038:
          _timer?.cancel();
          setState(() => _status = '二维码已过期');
      }
    } catch (_) {
    } finally {
      _polling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired = _status == '二维码已过期';
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Glass(
          radius: 34,
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 300,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Text('扫码登录', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const Spacer(),
                GlassCircleButton(
                    icon: CupertinoIcons.xmark, size: 34, onTap: () => Navigator.of(context).pop()),
              ]),
              const SizedBox(height: 18),
              Container(
                width: 220,
                height: 220,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                child: _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.black)))
                    : _url == null
                        ? const CupertinoActivityIndicator()
                        : Opacity(
                            opacity: expired ? .2 : 1,
                            child: QrImageView(data: _url!, padding: EdgeInsets.zero),
                          ),
              ),
              const SizedBox(height: 16),
              Text(_status, style: TextStyle(color: secondaryLabel(context))),
              if (expired || _error != null) ...[
                const SizedBox(height: 12),
                CapsuleButton(label: '刷新二维码', onTap: _gen),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class LoginPrompt extends StatelessWidget {
  const LoginPrompt({super.key, this.text = '登录后查看关注的 UP 主更新'});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Glass(
          radius: 30,
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(CupertinoIcons.person_crop_circle, size: 56, color: kPink),
            const SizedBox(height: 12),
            Text(text, style: TextStyle(color: secondaryLabel(context))),
            const SizedBox(height: 16),
            CapsuleButton(label: '扫码登录', onTap: () => showLogin(context)),
          ]),
        ),
      );
}
