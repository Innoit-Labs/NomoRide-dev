import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/features/profile/data/content_repository.dart';
import 'package:nomoride/features/profile/data/models/app_content.dart';
import '../../../../core/utils/size_utils.dart';
import '../../../../theme/theme_helper.dart';

class ContentKeyScreen extends StatefulWidget {
  const ContentKeyScreen({
    super.key,
    required this.contentKey,
    required this.title,
  });

  final String contentKey;
  final String title;

  @override
  State<ContentKeyScreen> createState() => _ContentKeyScreenState();
}

class _ContentKeyScreenState extends State<ContentKeyScreen> {
  final ContentRepository _repository = ContentRepository();

  bool _isLoading = true;
  String? _errorMessage;
  AppContent? _content;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final content = await _repository.getContentByKey(
        widget.contentKey,
        fallbackTitle: widget.title,
      );
      if (!mounted) return;
      setState(() => _content = content);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            error is ApiException ? error.message : error.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _displayTitle {
    final apiTitle = _content?.title.trim();
    if (apiTitle != null && apiTitle.isNotEmpty) return apiTitle;
    return widget.title;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColours.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColours.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _displayTitle,
          style: CustomTextStyles.montserratBold.copyWith(
            color: AppColours.primary,
            fontSize: 18.fSize,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
            height: 2,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  const Color(0xFFE6C27A).withValues(alpha: 0.15),
                  const Color(0xFFE6C27A),
                  const Color(0xFFE6C27A).withValues(alpha: 0.15),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColours.primary,
            onRefresh: _loadContent,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(24.w),
              child: _buildBody(),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: const Center(
                child: CircularProgressIndicator(color: AppColours.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _content == null) {
      return SizedBox(height: 320.h);
    }

    if (_errorMessage != null && _content == null) {
      return SizedBox(
        height: 320.h,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: CustomTextStyles.openSansRegular.copyWith(
                  color: AppColours.hintcolor,
                ),
              ),
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: _loadContent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColours.primary,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final body = _content?.body.trim() ?? '';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColours.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _displayTitle,
            style: CustomTextStyles.montserratBold.copyWith(
              fontSize: 14.fSize,
              color: AppColours.primary,
            ),
          ),
          SizedBox(height: 16.h),
          if (!_isLoading) _buildContentBody(body),
        ],
      ),
    );
  }

  Widget _buildContentBody(String body) {
    if (body.isEmpty) {
      return Text(
        'Content is not available right now. Please try again later.',
        style: CustomTextStyles.openSansRegular.copyWith(
          fontSize: 13.fSize,
          height: 1.6,
        ),
      );
    }

    if (_content?.isHtml ?? _looksLikeHtml(body)) {
      return Html(
        data: body,
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            fontSize: FontSize(13.fSize),
            lineHeight: const LineHeight(1.6),
            color: AppColours.secondary,
          ),
          'h1': Style(
            color: AppColours.primary,
            fontSize: FontSize(16.fSize),
            fontWeight: FontWeight.w700,
            margin: Margins.only(bottom: 12),
          ),
          'h2': Style(
            color: AppColours.primary,
            fontSize: FontSize(14.fSize),
            fontWeight: FontWeight.w600,
            margin: Margins.only(top: 8, bottom: 8),
          ),
          'h3': Style(
            color: AppColours.primary,
            fontSize: FontSize(13.fSize),
            fontWeight: FontWeight.w600,
            margin: Margins.only(top: 8, bottom: 6),
          ),
          'p': Style(
            margin: Margins.only(bottom: 12),
          ),
          'ul': Style(
            margin: Margins.only(bottom: 12),
            padding: HtmlPaddings.only(left: 18),
          ),
          'ol': Style(
            margin: Margins.only(bottom: 12),
            padding: HtmlPaddings.only(left: 18),
          ),
          'li': Style(
            margin: Margins.only(bottom: 6),
          ),
          'a': Style(
            color: AppColours.primary,
            textDecoration: TextDecoration.underline,
          ),
          'strong': Style(
            color: AppColours.secondary,
            fontWeight: FontWeight.w600,
          ),
        },
      );
    }

    return Text(
      body,
      style: CustomTextStyles.openSansRegular.copyWith(
        fontSize: 13.fSize,
        height: 1.6,
      ),
    );
  }

  bool _looksLikeHtml(String value) {
    return RegExp(r'<[^>]+>').hasMatch(value);
  }
}
