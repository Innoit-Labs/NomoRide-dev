import 'package:flutter_test/flutter_test.dart';
import 'package:nomoride/features/home/data/models/dp_order_product.dart';

void main() {
  test('kit selectedItems drive garment name, image, size, qty, qr and price', () {
    final product = DpOrderProduct.fromJson({
      'productName': "Men's classic shirts",
      'imageUrl': 'https://cdn.example.com/kit_cover.png',
      'quantity': 1,
      'cart_section': 'non_subscription',
      'kitDetails': {
        'kit_type': '1-Day wardrobe Kit',
        'kit_name': '1-Daywardrobe Kit',
        'selectedItems': [
          {
            'productId': '9d7f8860-219d-4d6e-975c-4ad98b3e878a',
            'quantity': 1,
            'variantId': '33b5e774-8c7d-4d90-b37c-96b87ab1e9f0',
            'size': 'm',
            'product_name': 'printed jacket',
            'price': 500,
            'primary_image_url':
                'https://cdn.example.com/products/printed_jacket.png',
            'qr_code': 'NOMO-QR-H6LPJMMJ',
            'qr_codes': ['NOMO-QR-H6LPJMMJ'],
          },
        ],
      },
    });

    expect(product.kitType?.toLowerCase(), contains('wardrobe kit'));
    expect(product.garments, hasLength(1));
    expect(product.garments.first.displayName, 'Printed Jacket');
    expect(product.garments.first.size, 'm');
    expect(product.garments.first.quantity, 1);
    expect(product.garments.first.qrCode, 'NOMO-QR-H6LPJMMJ');
    expect(product.garments.first.price, '500');
    expect(
      product.garments.first.imageUrl,
      'https://cdn.example.com/products/printed_jacket.png',
    );
    expect(
      product.previewImageUrls.first,
      'https://cdn.example.com/products/printed_jacket.png',
    );
    expect(product.garmentCountLabel, contains('Printed Jacket'));
    expect(product.garmentCountLabel, contains('Size: M'));
    expect(product.canExpand, isTrue);
  });
}
