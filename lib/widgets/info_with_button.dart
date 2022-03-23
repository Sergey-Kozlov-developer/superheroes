import 'package:flutter/material.dart';
import 'package:superheroes/widgets/action_button.dart';

import '../resources/superheroes_colors.dart';
import '../resources/superheroes_images.dart';

class InfoWithButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final String assetImage;
  final double imageHeight;
  final double imageWidth;
  final double imageTopPadding;

  const InfoWithButton({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.assetImage,
    required this.imageHeight,
    required this.imageWidth,
    required this.imageTopPadding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.topCenter,
          children: [
            Container(
              height: 108,
              width: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SuperheroesColors.blue,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: imageTopPadding),
              child: Image.asset(
                assetImage,
                height: imageHeight,
                width: imageWidth,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          subtitle.toUpperCase(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 30),
        ActionButton(text: buttonText, onTap: () {}),
      ],
    );
  }
}
