import 'package:supabase/supabase.dart';
void main() async {
  final client = SupabaseClient('https://khurtsgzfviteinhbgcy.supabase.co', 'sb_publishable_VdkAaVFbVyFJ2dFCw0t4pA_1qYnPiHh');
  try {
    await client.storage.createBucket('product-images', const BucketOptions(public: true));
    print('Bucket created successfully!');
  } catch (e) {
    print('Error: $e');
  }
}
