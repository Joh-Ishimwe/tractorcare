class SyncData {
  final String deviceId;
  final String? lastSyncTimestamp;
  final Map<String, List<Map<String, dynamic>>> dataToUpload;
  
  SyncData({
    required this.deviceId,
    this.lastSyncTimestamp,
    required this.dataToUpload,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'last_sync_timestamp': lastSyncTimestamp,
      'data_to_upload': dataToUpload,
    };
  }
}