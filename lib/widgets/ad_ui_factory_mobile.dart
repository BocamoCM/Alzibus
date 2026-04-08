import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

Widget buildNativeAdStub({Object? ad}) {
  if (ad is NativeAd) {
    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      height: 300,
      child: AdWidget(ad: ad),
    );
  }
  return const SizedBox.shrink();
}
