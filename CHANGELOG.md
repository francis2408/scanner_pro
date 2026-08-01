# 1.0.0+1

- Initial release of Scanner Pro cross-platform Flutter application.
- Real-time OCR and Barcode detection powered by Google ML Kit.
- Dynamic REST API lookup pipeline (Open Food Facts, UPC Item DB, Open Library, OpenStreetMap Nominatim, India Post, NHTSA VIN).
- Multiformat document parsing engine:
  - Indian Aadhaar Card (Verhoeff D10 checksum + Secure XML/OCR).
  - Income Tax PAN Card (10-char classification + surname decoding + fuzzy OCR correction).
  - UPI Payment QR (GPay, PhonePe, Paytm, Amazon Pay account details).
  - Passports (ICAO Doc 9303 MRZ checksums + Country API metadata).
  - Driving Licenses (AAMVA PDF417 + US Zippopotam lookup).
  - Vehicle VIN (ISO 3779 17-char check digit + NHTSA API specs).
  - GS1 Barcodes & Retail 1D/2D Symbologies.
