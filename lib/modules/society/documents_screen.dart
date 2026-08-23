import 'package:flutter/material.dart';
import '../dashboard/main_dashboard.dart';

// ─── Colors ────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFF9FAFB);
  static const text = Color(0xFF111827);
  static const sub = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const orange = Color(0xFFFF6B00);
}

// ─── Model ─────────────────────────────────────────────────────────
class DocumentItem {
  final String title;
  final String category;
  final String size;
  final String updatedOn;
  final bool isPdf;

  const DocumentItem({
    required this.title,
    required this.category,
    required this.size,
    required this.updatedOn,
    this.isPdf = true,
  });
}

// ─── Dummy Data ────────────────────────────────────────────────────
final List<DocumentItem> _allDocuments = [
  DocumentItem(
    title: 'RWA Rules & Regulations 2026',
    category: 'Bye-Laws',
    size: '2.4 MB',
    updatedOn: '1 Jun 2026',
  ),
  DocumentItem(
    title: 'Tenant Police Verification Form',
    category: 'Forms',
    size: '340 KB',
    updatedOn: '12 Mar 2026',
  ),
  DocumentItem(
    title: 'NOC for Renovation Work',
    category: 'NOC',
    size: '180 KB',
    updatedOn: '5 Apr 2026',
  ),
  DocumentItem(
    title: 'Rent Agreement Template 2026',
    category: 'Templates',
    size: '520 KB',
    updatedOn: '20 Feb 2026',
  ),
  DocumentItem(
    title: 'Society Budget Report – Q2 2026',
    category: 'Finance',
    size: '1.1 MB',
    updatedOn: '30 Jun 2026',
  ),
  DocumentItem(
    title: 'Emergency Contact Directory',
    category: 'General',
    size: '95 KB',
    updatedOn: '10 Jan 2026',
    isPdf: false,
  ),
  DocumentItem(
    title: 'Pet Policy & Guidelines',
    category: 'Bye-Laws',
    size: '210 KB',
    updatedOn: '8 May 2026',
  ),
  DocumentItem(
    title: 'Visitor Management SOP',
    category: 'Security',
    size: '430 KB',
    updatedOn: '22 Apr 2026',
  ),
  DocumentItem(
    title: 'Maintenance Charges Circular',
    category: 'Finance',
    size: '150 KB',
    updatedOn: '1 Jul 2026',
  ),
];

// ─── Screen ────────────────────────────────────────────────────────
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DocumentItem> get _filtered => _allDocuments
      .where((d) =>
          d.title.toLowerCase().contains(_query.toLowerCase()) ||
          d.category.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  // ── Category Badge
  Widget _buildCategoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _C.border),
      ),
      child: Text(
        category,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _C.sub,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ── Document Tile
  Widget _buildDocTile(DocumentItem doc) {
    final isDoc = !doc.isPdf;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          // File icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDoc
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFFFEBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDoc
                    ? const Color(0xFFBFDBFE)
                    : const Color(0xFFFFCDD2),
              ),
            ),
            child: Icon(
              isDoc
                  ? Icons.description_outlined
                  : Icons.picture_as_pdf_outlined,
              color: isDoc
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFDC2626),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _C.text,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildCategoryBadge(doc.category),
                    const SizedBox(width: 8),
                    Text(
                      doc.size,
                      style:
                          const TextStyle(fontSize: 11, color: _C.sub),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Updated ${doc.updatedOn}',
                  style:
                      const TextStyle(fontSize: 11, color: _C.sub),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Download button
          OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Downloading "${doc.title}"…'),
                  backgroundColor: _C.orange,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: _C.orange,
              side: const BorderSide(color: _C.orange),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }

  // ── Search Bar
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v),
        style: const TextStyle(fontSize: 14, color: _C.text),
        decoration: InputDecoration(
          hintText: 'Search documents…',
          hintStyle: const TextStyle(color: _C.sub, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: _C.sub, size: 20),
          suffixIcon: _query.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  child: const Icon(Icons.close, color: _C.sub, size: 18),
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ── Empty State
  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _C.bg,
                shape: BoxShape.circle,
                border: Border.all(color: _C.border),
              ),
              child: const Icon(Icons.search_off,
                  size: 34, color: _C.sub),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Documents Found',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _C.text),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try a different search term.',
              style: TextStyle(fontSize: 13, color: _C.sub),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = _filtered;

    void handleBack() {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainDashboard()),
          (route) => false,
        );
      }
    }

    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        handleBack();
      },
      child: Scaffold(
        backgroundColor: _C.bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.white,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: _C.text),
            onPressed: handleBack,
          ),
          title: const Text(
            'Society Documents',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _C.text,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _C.border),
          ),
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    '${docs.length} document${docs.length == 1 ? '' : 's'}',
                    style:
                        const TextStyle(fontSize: 13, color: _C.sub),
                  ),
                ],
              ),
            ),
            Expanded(
              child: docs.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: docs.length,
                      itemBuilder: (_, i) => _buildDocTile(docs[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
