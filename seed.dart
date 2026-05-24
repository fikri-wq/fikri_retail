import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('Starting to fetch categories via REST API...');
  
  const supabaseUrl = 'https://kboyrjpizxbdudglcwcd.supabase.co';
  const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtib3lyanBpenhiZHVkZ2xjd2NkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk1NTkxMTMsImV4cCI6MjA5NTEzNTExM30.3SvYpWFJPRI2rxeeoWRwiXo_tZxXAIZHSD9hUvaDAvo';
  
  final headers = {
    'apikey': anonKey,
    'Authorization': 'Bearer $anonKey',
    'Content-Type': 'application/json',
  };

  print('Fetching categories...');
  var res = await http.get(Uri.parse('$supabaseUrl/rest/v1/categories'), headers: headers);
  List<dynamic> existingCategories = jsonDecode(res.body);
  
  Map<String, String> categoryMap = {};
  for (var cat in existingCategories) {
    categoryMap[cat['name']] = cat['id'];
  }

  final neededCats = ['Minyak', 'Mie Instan', 'Bumbu', 'Susu', 'Snack', 'Sembako', 'Minuman', 'Kebut. Rumah', 'Lainnya'];
  for (var cat in neededCats) {
    if (!categoryMap.containsKey(cat)) {
      print('Creating category: $cat');
      final postRes = await http.post(
        Uri.parse('$supabaseUrl/rest/v1/categories'),
        headers: {...headers, 'Prefer': 'return=representation'},
        body: jsonEncode({'name': cat}),
      );
      if (postRes.statusCode >= 200 && postRes.statusCode < 300) {
        final newCat = jsonDecode(postRes.body)[0];
        categoryMap[cat] = newCat['id'];
      }
    }
  }

  print('Reading assets directory...');
  final dir = Directory('assets');
  if (!dir.existsSync()) {
    print('Assets directory not found!');
    return;
  }

  final files = dir.listSync();
  final productsToInsert = [];

  for (var file in files) {
    if (file is File) {
      final fileName = file.path.split(Platform.pathSeparator).last;
      final nameWithoutExt = fileName.split('.').first;
      
      if (fileName.startsWith('iklan') || 
          fileName.startsWith('logo') || 
          ['bca.jpg', 'bni.png', 'bri.png', 'dana.png', 'mandiri.png', 'sea.jpg', 'AN', 'AN1', 'AN2'].any((e) => fileName.startsWith(e))) {
        continue;
      }
      
      String categoryName = 'Lainnya';
      double price = 15000;
      
      if (nameWithoutExt.toLowerCase().contains('bimoli') || nameWithoutExt.toLowerCase().contains('filma') || nameWithoutExt.toLowerCase().contains('minyak')) {
        categoryName = 'Minyak';
        price = 35000;
      } else if (nameWithoutExt.toLowerCase().contains('indomie') || nameWithoutExt.toLowerCase().contains('sarimi') || nameWithoutExt.toLowerCase().contains('pop mie') || nameWithoutExt.toLowerCase().contains('supermi')) {
        categoryName = 'Mie Instan';
        price = 3500;
      } else if (nameWithoutExt.toLowerCase().contains('bumbu') || nameWithoutExt.toLowerCase().contains('sambal') || nameWithoutExt.toLowerCase().contains('kecap')) {
        categoryName = 'Bumbu';
        price = 6000;
      } else if (nameWithoutExt.toLowerCase().contains('susu') || nameWithoutExt.toLowerCase().contains('indomilk') || nameWithoutExt.toLowerCase().contains('kremer') || nameWithoutExt.toLowerCase().contains('enaak')) {
        categoryName = 'Susu';
        price = 12000;
      } else if (nameWithoutExt.toLowerCase().contains('chitato') || nameWithoutExt.toLowerCase().contains('lays') || nameWithoutExt.toLowerCase().contains('qtela') || nameWithoutExt.toLowerCase().contains('cheetos') || nameWithoutExt.toLowerCase().contains('trenz')) {
        categoryName = 'Snack';
        price = 8500;
      } else if (nameWithoutExt.toLowerCase().contains('beras') || nameWithoutExt.toLowerCase().contains('gula') || nameWithoutExt.toLowerCase().contains('tepung')) {
        categoryName = 'Sembako';
        price = 65000;
        if (nameWithoutExt.toLowerCase().contains('gula')) price = 16000;
        if (nameWithoutExt.toLowerCase().contains('tepung')) price = 12000;
      } else if (nameWithoutExt.toLowerCase().contains('air') || nameWithoutExt.toLowerCase().contains('syrup') || nameWithoutExt.toLowerCase().contains('ocha') || nameWithoutExt.toLowerCase().contains('tekita') || nameWithoutExt.toLowerCase().contains('club')) {
        categoryName = 'Minuman';
        price = 5000;
        if (nameWithoutExt.toLowerCase().contains('syrup')) price = 22000;
      } else if (nameWithoutExt.toLowerCase().contains('tissue')) {
        categoryName = 'Kebut. Rumah';
        price = 18000;
      }

      final catId = categoryMap[categoryName];

      productsToInsert.add('''
  {
    'name': '$nameWithoutExt',
    'description': 'Produk $nameWithoutExt berkualitas tinggi, siap memenuhi kebutuhan harian Anda.',
    'price': $price,
    'stock': 100,
    'image_url': 'assets/$fileName',
    'category_id': '$catId', 
  }''');
    }
  }

  final dartFile = File('lib/seed_data.dart');
  await dartFile.writeAsString('''
final List<Map<String, dynamic>> seedProducts = [
${productsToInsert.join(',\n')}
];
''');

  print('Generated lib/seed_data.dart with ${productsToInsert.length} products.');
}
