import 'package:flutter/material.dart';
import '../../config/theme.dart';

class MembersScreen extends StatelessWidget {
  const MembersScreen({Key? key}) : super(key: key);

  // Mock members data
  final List<Map<String, dynamic>> members = const [
    {
      'member_id': 'MEM001',
      'name': 'Jean Baptiste Mukiza',
      'phone': '+250788123456',
      'email': 'jean.mukiza@gmail.com',
      'is_premium': true,
      'status': 'active',
      'join_date': '2023-01-15',
      'total_bookings': 45,
    },
    {
      'member_id': 'MEM002',
      'name': 'Marie Claire Uwase',
      'phone': '+250788234567',
      'email': 'marie.uwase@gmail.com',
      'is_premium': false,
      'status': 'active',
      'join_date': '2023-03-20',
      'total_bookings': 23,
    },
    {
      'member_id': 'MEM003',
      'name': 'Emmanuel Nkusi',
      'phone': '+250788345678',
      'email': 'emmanuel.nkusi@gmail.com',
      'is_premium': true,
      'status': 'active',
      'join_date': '2022-11-10',
      'total_bookings': 67,
    },
    {
      'member_id': 'MEM004',
      'name': 'Grace Umutoni',
      'phone': '+250788456789',
      'email': 'grace.umutoni@gmail.com',
      'is_premium': false,
      'status': 'inactive',
      'join_date': '2024-01-05',
      'total_bookings': 8,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cooperative Members'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary cards
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.lightGray,
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Members',
                    '60',
                    Icons.people,
                    AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Leaders',
                    '5',
                    Icons.star,
                    AppTheme.accentOrange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Active',
                    '58',
                    Icons.check_circle,
                    AppTheme.successGreen,
                  ),
                ),
              ],
            ),
          ),

          // Members list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      radius: 30,
                      backgroundColor: AppTheme.primaryGreen,
                      child: Text(
                        member['name'].split(' ')[0][0] +
                            member['name'].split(' ')[1][0],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            member['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (member['is_premium'])
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentOrange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 12,
                                  color: AppTheme.accentOrange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Leader',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accentOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.phone,
                                size: 14, color: AppTheme.neutralGray),
                            const SizedBox(width: 4),
                            Text(member['phone']),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.email,
                                size: 14, color: AppTheme.neutralGray),
                            const SizedBox(width: 4),
                            Expanded(child: Text(member['email'])),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${member['total_bookings']} bookings • Joined ${member['join_date']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.neutralGray,
                          ),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      icon: const Icon(Icons.more_vert),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(Icons.visibility, size: 20),
                              SizedBox(width: 8),
                              Text('View Details'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'view') {
                          _showMemberDetails(context, member);
                        } else if (value == 'edit') {
                          _showEditDialog(context, member);
                        } else if (value == 'delete') {
                          _showDeleteConfirmation(context, member);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMemberDialog(context),
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Member'),
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showMemberDetails(BuildContext context, Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(member['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('ID', member['member_id']),
            _buildDetailRow('Phone', member['phone']),
            _buildDetailRow('Email', member['email']),
            _buildDetailRow('Status', member['status'].toUpperCase()),
            _buildDetailRow('Member Since', member['join_date']),
            _buildDetailRow('Total Bookings', member['total_bookings'].toString()),
            _buildDetailRow('Type', member['is_premium'] ? 'Premium' : 'Standard'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Member'),
        content: const Text('Edit member form would go here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Member updated successfully')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Member'),
        content: Text('Are you sure you want to delete ${member['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${member['name']} deleted'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Member'),
        content: const Text('Add member form would go here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Member added successfully')),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}