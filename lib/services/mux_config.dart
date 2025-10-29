import 'dart:convert';

class MuxConfig {
  static const String apiToken = 'b40e9785-4b91-42d3-bc97-2c3028685e18';
  static const String secretKey =
      'IxFF2a5OCka4tqBClQFiQjZfAwBb4Bt/+1U5GZ05d0o3sYRIjAboR01NSaKindp/+7T7YXlT4hK';

  static const String videoApiUrl = 'https://api.mux.com/video/v1';

  static Map<String, String> get headers => {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$apiToken:$secretKey'))}',
        'Content-Type': 'application/json',
      };
}
