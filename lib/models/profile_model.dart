/// Profile Response Data Model
class ProfileResponse {
  final bool status;
  final String message;
  final ProfileData? data;

  ProfileResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory ProfileResponse.fromJson(Map<String, dynamic> json) {
    dynamic rawData = json['data'] ?? json['user'] ?? json['profile'] ?? json;
    ProfileData? parsedData;

    if (rawData is Map<String, dynamic>) {
      parsedData = ProfileData.fromJson(rawData);
    } else if (rawData is Map) {
      parsedData = ProfileData.fromJson(Map<String, dynamic>.from(rawData));
    }

    bool isStatusTrue = json['status'] == true ||
        json['status'] == 'true' ||
        json['status'] == 1 ||
        json['status'] == 'success' ||
        json['success'] == true;

    return ProfileResponse(
      status: isStatusTrue,
      message: json['message']?.toString() ?? json['msg']?.toString() ?? '',
      data: parsedData,
    );
  }
}

class ProfileData {
  final String id;
  final String name;
  final String mobile;
  final String email;
  final String city;
  final String address;

  ProfileData({
    required this.id,
    required this.name,
    required this.mobile,
    required this.email,
    required this.city,
    required this.address,
  });

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      id: (json['id'] ?? json['user_id'] ?? '').toString(),
      name: (json['name'] ?? json['username'] ?? json['full_name'] ?? json['user_name'] ?? '').toString(),
      mobile: (json['mobile'] ?? json['mobile_no'] ?? json['phone'] ?? json['phone_no'] ?? '').toString(),
      email: (json['email'] ?? json['email_id'] ?? '').toString(),
      city: json['city'] != null && json['city'].toString().toLowerCase() != 'null'
          ? json['city'].toString()
          : '',
      address: json['address'] != null && json['address'].toString().toLowerCase() != 'null'
          ? json['address'].toString()
          : '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobile': mobile,
      'email': email,
      'city': city,
      'address': address,
    };
  }
}
