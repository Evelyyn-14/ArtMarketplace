import 'dart:convert';
import 'package:http/http.dart' as http;

class Apiservices {
  static const _pixabayApiKey = '50052284-620711da59bb21a30582b5739';

  static const _currencyKey = '21db296095bb4a34df90d0b65e1edc9b';

  Future<List<dynamic>> getImages(String query) async {
    final url =
        'https://pixabay.com/api/?key=$_pixabayApiKey&q=$query&image_type=photo&pretty=true';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['hits'];
    } else {
      throw Exception('Failed to load images');
    }
  }
  Future<Map<String, dynamic>> getCurrencyData() async {
    final url =
        'https://api.apilayer.com/exchangerates_data/latest?base=USD&apikey=$_currencyKey';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load currency data');
    }
  } 
}