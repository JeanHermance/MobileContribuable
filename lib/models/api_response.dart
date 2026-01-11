class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.error,
    this.statusCode,
  });

  bool get isSuccess => success;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json, 
    T Function(Map<String, dynamic>) fromJsonT
  ) {
    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      data: json['data'] != null ? fromJsonT(json['data']) : null,
      error: json['error'] as String?,
      statusCode: json['statusCode'] as int?,
    );
  }

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) toJsonT) {
    return {
      'success': success,
      if (data != null) 'data': toJsonT(data as T),
      if (error != null) 'error': error,
      if (statusCode != null) 'statusCode': statusCode,
    };
  }
}
