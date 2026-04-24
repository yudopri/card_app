import 'package:flutter/material.dart';
import 'network/network_client.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final DioClient _dioClient = DioClient();

  List<dynamic> _historyItems = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadHistory({bool isRefresh = false}) async {
    if (isRefresh) {
      _currentPage = 1;
      setState(() => _isLoading = true);
    }

    try {
      final response = await _dioClient.getHistoryLogs(page: _currentPage);
      if (response.statusCode == 200) {
        setState(() {
          if (isRefresh) {
            _historyItems = response.data['logs'] ?? [];
          } else {
            _historyItems.addAll(response.data['logs'] ?? []);
          }
          _totalPages = response.data['pages'] ?? 1;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Gagal mengambil riwayat'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _currentPage < _totalPages) {
        _loadMoreData();
      }
    }
  }

  Future<void> _loadMoreData() async {
    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _loadHistory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dimensi layar
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isTablet ? screenWidth * 0.15 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Riwayat Verifikasi',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: -0.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        foregroundColor: const Color(0xFF1E40AF),
      ),
      body: Column(
        children: [
          // Filter & Search Bar Section
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 20),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari Nama atau ID...',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6B7280)),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              ),
            ),
          ),

          // List Section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF)))
                : RefreshIndicator(
              color: const Color(0xFF1E40AF),
              backgroundColor: Colors.white,
              onRefresh: () => _loadHistory(isRefresh: true),
              child: _historyItems.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(), // Agar selalu bisa di-refresh meski item sedikit
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
                itemCount: _historyItems.length + (_isLoadingMore ? 1 : 0),
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == _historyItems.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF1E40AF)
                        ),
                      ),
                    );
                  }

                  final item = _historyItems[index];
                  return _buildHistoryCard(item);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget helper untuk Empty State
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.5,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Belum ada riwayat',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4B5563)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Data verifikasi ID akan muncul di sini.',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // Widget helper untuk History Card
  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final String status = item['status'] ?? 'Unknown';
    final String statusLower = status.toLowerCase();
    Color statusColor;
    IconData statusIcon;

    if (statusLower == 'verified' || statusLower == 'success') {
      statusColor = const Color(0xFF10B981); // Emerald Green
      statusIcon = Icons.check_circle_rounded;
    } else if (statusLower == 'failed' || statusLower == 'rejected') {
      statusColor = const Color(0xFFEF4444); // Red
      statusIcon = Icons.cancel_rounded;
    } else {
      statusColor = const Color(0xFFF59E0B); // Amber / Pending
      statusIcon = Icons.pending_actions_rounded;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // TODO: Navigasi ke detail riwayat jika diperlukan
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4)
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['id_card_fullname'] ?? 'No Name',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF111827)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${item['id_card_qr'] ?? '-'}',
                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 4),
                        Text(
                          item['created_at']?.split('.')[0] ?? '-',
                          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}