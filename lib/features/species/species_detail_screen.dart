import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class SpeciesDetailScreen extends StatefulWidget {
  const SpeciesDetailScreen({super.key});

  @override
  State<SpeciesDetailScreen> createState() => _SpeciesDetailScreenState();
}

class _SpeciesDetailScreenState extends State<SpeciesDetailScreen> {
  List<dynamic> _speciesList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSpecies();
  }

  Future<void> _loadSpecies() async {
    try {
      final data = await rootBundle.loadString('assets/species.json');
      setState(() {
        _speciesList = jsonDecode(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Bird Species Catalog (27 Species)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F1A15), Color(0xFF132B20)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2ECC71)))
            : _speciesList.isEmpty
                ? const Center(child: Text('No data available', style: TextStyle(color: Colors.white)))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 40),
                    itemCount: _speciesList.length,
                    itemBuilder: (context, index) {
                      final species = _speciesList[index];
                      final hasImage = species['imageUrl'] != null && species['imageUrl'].toString().isNotEmpty;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF183226),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // High-Resolution Large Bird Visual Display
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: SizedBox(
                                height: 160,
                                width: double.infinity,
                                child: Stack(
                                  children: [
                                    hasImage
                                        ? Image.asset(
                                            species['imageUrl'],
                                            width: double.infinity,
                                            height: 160,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              color: const Color(0xFF1E3D30),
                                              child: const Center(
                                                child: Icon(Icons.eco_rounded, color: Color(0xFF2ECC71), size: 48),
                                              ),
                                            ),
                                          )
                                        : Container(
                                            color: const Color(0xFF1E3D30),
                                            child: const Center(
                                              child: Icon(Icons.eco_rounded, color: Color(0xFF2ECC71), size: 48),
                                            ),
                                          ),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withValues(alpha: 0.8),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 12,
                                      left: 16,
                                      right: 16,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            species['english'] ?? species['commonName'] ?? 'Unknown Species',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            species['scientific'] ?? species['scientificName'] ?? '',
                                            style: const TextStyle(
                                              color: Color(0xFF2ECC71),
                                              fontSize: 14,
                                              fontStyle: FontStyle.italic,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Local Names & Identification Metadata
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (species['malay'] != null)
                                          Text(
                                            "🇲🇾 ${species['malay']}",
                                            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                                          ),
                                        if (species['french'] != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            "🇫🇷 ${species['french']}",
                                            style: const TextStyle(color: Colors.white60, fontSize: 13),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2ECC71).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF2ECC71).withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      "ID: #${species['id'] ?? index}",
                                      style: const TextStyle(color: Color(0xFF2ECC71), fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
