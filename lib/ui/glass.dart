import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../api/bili.dart';
import '../api/models.dart';
import 'theme.dart';

/// Liquid Glass 材质：背景模糊 + 顶部高光 + 细亮边。blur=0 时为无模糊的轻量版本（用于大量卡片）。
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 26,
    this.padding = EdgeInsets.zero,
    this.clear = false,
    this.blur = 28,
    this.tint,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool clear;
  final double blur;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = tint ??
        (clear
            ? Colors.white.withValues(alpha: dark ? .06 : .14)
            : (dark
                ? const Color(0xFF1C1C1E).withValues(alpha: blur > 0 ? .55 : .92)
                : Colors.white.withValues(alpha: blur > 0 ? .62 : .9)));
    final hi = Colors.white.withValues(alpha: clear ? .10 : (dark ? .08 : .45));
    final br = BorderRadius.circular(radius);
    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.alphaBlend(hi, base), base],
          stops: const [0, .55],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: clear ? .22 : (dark ? .14 : .75)),
          width: .8,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (blur > 0) {
      body = BackdropFilter(filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: body);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .35 : .08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: br, child: body),
    );
  }
}

/// 玻璃圆形按钮
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({super.key, required this.icon, required this.onTap, this.size = 44, this.clear = false, this.color});
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool clear;
  final Color? color;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Glass(
          radius: size / 2,
          clear: clear,
          child: SizedBox(width: size, height: size, child: Icon(icon, size: size * .45, color: color)),
        ),
      );
}

/// 胶囊按钮
class CapsuleButton extends StatelessWidget {
  const CapsuleButton({super.key, required this.label, required this.onTap, this.filled = true, this.icon});
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: iosDur,
          curve: iosCurve,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: filled ? kPink : fillColor(context),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: filled ? Colors.white : null),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: filled ? Colors.white : secondaryLabel(context))),
          ]),
        ),
      );
}

/// 环境背景：柔和彩色光斑，让玻璃材质有可折射的内容
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget blob(Color c, double size) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [c.withValues(alpha: dark ? .22 : .28), c.withValues(alpha: 0)]),
          ),
        );
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(children: [
        Positioned(top: -160, left: -120, child: blob(kPink, 520)),
        Positioned(top: 120, right: -180, child: blob(const Color(0xFF5AC8FA), 560)),
        Positioned(bottom: -200, left: 80, child: blob(const Color(0xFFAF52DE), 600)),
      ]),
    );
  }
}

/// 大标题导航
class LargeTitle extends StatelessWidget {
  const LargeTitle(this.title, {super.key, this.actions = const []});
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 10),
      child: Row(children: [
        if (canPop) ...[
          GlassCircleButton(icon: CupertinoIcons.chevron_left, onTap: () => Navigator.of(context).maybePop()),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: canPop ? 26 : 34, fontWeight: FontWeight.w700, letterSpacing: -.6)),
        ),
        ...actions,
      ]),
    );
  }
}

/// 带环境背景的页面容器
class GlassScaffold extends StatelessWidget {
  const GlassScaffold({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          const Positioned.fill(child: AmbientBackground()),
          Positioned.fill(child: SafeArea(bottom: false, child: child)),
        ]),
      );
}

/// Inset Grouped 列表分组
class GlassSection extends StatelessWidget {
  const GlassSection({super.key, required this.children, this.header});
  final List<Widget> children;
  final String? header;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(Padding(
          padding: const EdgeInsets.only(left: 56),
          child: Divider(height: .5, thickness: .5, color: secondaryLabel(context).withValues(alpha: .25)),
        ));
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Text(header!, style: TextStyle(fontSize: 13, color: secondaryLabel(context))),
          ),
        Glass(radius: 22, child: Column(children: rows)),
      ]),
    );
  }
}

class GlassTile extends StatelessWidget {
  const GlassTile({super.key, required this.icon, required this.title, this.trailing, this.onTap, this.iconColor = kPink, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: iconColor, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 16)),
                if (subtitle != null)
                  Text(subtitle!, style: TextStyle(fontSize: 12, color: secondaryLabel(context))),
              ]),
            ),
            trailing ??
                (onTap != null
                    ? Icon(CupertinoIcons.chevron_right, size: 16, color: secondaryLabel(context))
                    : const SizedBox()),
          ]),
        ),
      );
}

class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover, this.width, this.height});
  final String url;
  final BoxFit fit;
  final double? width, height;

  @override
  Widget build(BuildContext context) {
    final ph = Container(width: width, height: height, color: fillColor(context));
    if (url.isEmpty) return ph;
    return Image.network(
      url,
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true,
      headers: const {'Referer': kReferer},
      errorBuilder: (_, __, ___) => ph,
      frameBuilder: (c, child, frame, sync) =>
          sync || frame != null ? child : ph,
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar(this.url, {super.key, this.size = 36});
  final String url;
  final double size;

  @override
  Widget build(BuildContext context) => ClipOval(
        child: NetImage(thumb(url, w: 96, h: 96), width: size, height: size),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Glass(
            radius: 26,
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(CupertinoIcons.exclamationmark_triangle, size: 32, color: secondaryLabel(context)),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                CapsuleButton(label: '重试', onTap: onRetry),
              ],
            ]),
          ),
        ),
      );
}

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CupertinoActivityIndicator(radius: 13));
}
