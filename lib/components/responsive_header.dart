import 'package:flutter/material.dart';

class ResponsiveHeader extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;
  final double maxWidth;

  const ResponsiveHeader({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.actions,
    this.maxWidth = 600,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: AppBar(
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: actions,
      ),
    );
  }
}

class ResponsiveHeaderWithImage extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final Widget? trailing;
  final double maxWidth;

  const ResponsiveHeaderWithImage({
    super.key,
    required this.title,
    this.imageUrl,
    this.trailing,
    this.maxWidth = 600,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (imageUrl != null)
                  Container(
                    width: 50,
                    height: 50,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(imageUrl ?? ''), // Utilisez CachedNetworkImage pour la production
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailing != null) trailing ?? const SizedBox.shrink(),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
        ],
      ),
    );
  }
}
