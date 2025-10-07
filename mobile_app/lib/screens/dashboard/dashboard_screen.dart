import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../tractors/tractor_list_screen.dart';
import '../predictions/predictions_screen.dart';
import '../members/members_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome header
            const Text(
              'Welcome, Admin',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Kayonza Farmers Cooperative',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.neutralGray,
              ),
            ),
            const SizedBox(height: 22),

            // Key metrics cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Fleet Size',
                    '15',
                    Icons.agriculture,
                    AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    'Active Now',
                    '14',
                    Icons.moving,
                    AppTheme.successGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Bookings',
                    '499',
                    Icons.book_online,
                    AppTheme.accentOrange,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    'Operators',
                    '20',
                    Icons.people,
                    AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
            // const SizedBox(height: 24),

            // Fleet status section
            // const Text(
            //   'Fleet Status',
            //   style: TextStyle(
            //     fontSize: 18,
            //     fontWeight: FontWeight.bold,
            //   ),
            // ),
            // const SizedBox(height: 12),
            // Card(
            //   child: Padding(
            //     padding: const EdgeInsets.all(16),
            //     child: Column(
            //       children: [
            //         _buildStatusRow(
            //           'Available',
            //           72,
            //           AppTheme.successGreen,
            //         ),
            //         const SizedBox(height: 12),
            //         _buildStatusRow(
            //           'In Use',
            //           28,
            //           AppTheme.accentOrange,
            //         ),
            //         const SizedBox(height: 12),
            //         _buildStatusRow(
            //           'Maintenance',
            //           9,
            //           AppTheme.warningYellow,
            //         ),
            //         const SizedBox(height: 12),
            //         _buildStatusRow(
            //           'Out of Service',
            //           10,
            //           AppTheme.criticalRed,
            //         ),
            //       ],
            //     ),
            //   ),
            // ),
            const SizedBox(height: 24),

            // Maintenance alerts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Maintenance Alerts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PredictionsScreen(tractorId: 'TR001'),
                      ),
                    );
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildAlertCard(
              'Critical',
              'TR-4613',
              'Engine maintenance overdue - Plough model',
              AppTheme.criticalRed,
            ),
            _buildAlertCard(
              'Warning',
              'TR-0645',
              'Oil change due in 2 days - Reaper model',
              AppTheme.warningYellow,
            ),
            _buildAlertCard(
              'Info',
              'TR-0250',
              'Scheduled maintenance upcoming - Ridger model',
              AppTheme.primaryGreen,
            ),
            const SizedBox(height: 24),

            // Recent activity
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildActivityItem(
              'TR045 started operation',
              '2 minutes ago',
              Icons.play_circle,
              AppTheme.successGreen,
            ),
            _buildActivityItem(
              'TR023 completed booking',
              '15 minutes ago',
              Icons.check_circle,
              AppTheme.primaryGreen,
            ),
            _buildActivityItem(
              'TR089 entered maintenance',
              '1 hour ago',
              Icons.build_circle,
              AppTheme.warningYellow,
            ),
            _buildActivityItem(
              'New booking created',
              '2 hours ago',
              Icons.add_circle,
              AppTheme.accentOrange,
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: AppTheme.primaryGreen,
        unselectedItemColor: AppTheme.neutralGray,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 1) {
            // Fleet
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TractorListScreen()),
            );
          } else if (index == 2) {
            // Members (replacing Bookings)
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MembersScreen()),
            );
          } else if (index == 3) {
            // Alerts
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PredictionsScreen(tractorId: 'TR001'),
              ),
            );
          }
          // index 0 is Dashboard (current screen)
          // index 4 is Profile (not implemented yet)
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.agriculture),
            label: 'Fleet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Members',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.neutralGray,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        Container(
          height: 8,
          width: 100,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: count / 119, // Out of total 119
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertCard(
    String severity,
    String tractor,
    String message,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.warning, color: color, size: 20),
        ),
        title: Text(
          tractor,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(message),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            severity,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String time,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.neutralGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}