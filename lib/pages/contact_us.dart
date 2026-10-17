import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';
import '../widgets/curved_header.dart';

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  static final List<Map<String, String>> depots = [
    {'name': 'Head Office (Chandigarh)', 'phone': '0172 2704790', 'address': 'Plot No 23, Sector 17, Chandigarh'},
    {'name': 'Amritsar Depot 1', 'phone': '0183 2551734', 'address': 'General Bus Stand, Amritsar'},
    {'name': 'Amritsar Depot 2', 'phone': '0183 2551735', 'address': 'General Bus Stand, Amritsar'},
    {'name': 'Jalandhar Depot 1', 'phone': '0181 2227630', 'address': 'Shaheed-e-Azam Bhagat Singh ISBT, Jalandhar'},
    {'name': 'Jalandhar Depot 2', 'phone': '0181 2223755', 'address': 'Shaheed-e-Azam Bhagat Singh ISBT, Jalandhar'},
    {'name': 'Ludhiana Depot', 'phone': '0161 2447015', 'address': 'ISBT Link Road, Ludhiana'},
    {'name': 'Pathankot Depot', 'phone': '0186 2220084', 'address': 'Near Railway Station, Pathankot'},
    {'name': 'Hoshiarpur Depot', 'phone': '01882 222214', 'address': 'Bus Stand, Hoshiarpur'},
    {'name': 'Ferozepur Depot', 'phone': '01632 244243', 'address': 'Near Bus Stand, Ferozepur Cantt'},
    {'name': 'Bathinda Depot', 'phone': '0164 2212108', 'address': 'Near City Bus Stand, Bathinda'},
    {'name': 'Patiala Depot', 'phone': '0175 2311212', 'address': 'PRTC Head Office, Patiala'},
    {'name': 'Ropar Depot', 'phone': '01881 221183', 'address': 'Bus Stand, Rupnagar'},
    {'name': 'Nangal Depot', 'phone': '01887 220577', 'address': 'Bus Stand, Nangal'},
    {'name': 'Muktsar Depot', 'phone': '01633 262254', 'address': 'Bus Stand, Sri Muktsar Sahib'},
  ];

  Future<void> _makeCall(String number) async {
    final cleaned = number.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: CurvedHeader(
              title: 'Contact Us',
              subtitle: 'Punjab Roadways & PunBus Depots',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              height: 160,
            ),
          ),

          // Central Support Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Central Helpline & Online Portal',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.phone_in_talk_rounded, color: Colors.green),
                        ),
                        title: const Text('Toll Free Support'),
                        subtitle: const Text(AppConstants.tollFreeNumber, style: TextStyle(fontWeight: FontWeight.bold)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          onPressed: () => _makeCall(AppConstants.tollFreeNumber),
                          child: const Text('Call'),
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.language_rounded, color: Colors.blue),
                        ),
                        title: const Text('Official Website'),
                        subtitle: const Text('punbusonline.com'),
                        trailing: OutlinedButton(
                          onPressed: () => _launchUrl(AppConstants.officialWebsite),
                          child: const Text('Visit'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Depots Heading
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: const Text(
                'Punjab Roadways Depots',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
            ),
          ),

          // Depots List
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final depot = depots[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      title: Text(depot['name']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(
                        '${depot['address']}\nPhone: ${depot['phone']}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.phone_rounded, color: AppColors.primary),
                        onPressed: () => _makeCall(depot['phone']!),
                      ),
                    ),
                  ),
                );
              },
              childCount: depots.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
