/*
 *  This file is part of BlackHole (https://github.com/Sangwan5688/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * BlackHole is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with BlackHole.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * Copyright (c) 2021-2022, Ankit Sangwan
 */

import 'package:blackhole/CustomWidgets/gradient_containers.dart';
import 'package:blackhole/Helpers/backup_restore.dart';
import 'package:blackhole/Helpers/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  TextEditingController controller = TextEditingController();
  Uuid uuid = const Uuid();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future _addUserData(String name) async {
    await Hive.box('settings').put('name', name.trim());

    final String userId = uuid.v1();
    await Hive.box('settings').put('userId', userId);
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final bool isLandscape = screenHeight < screenWidth;

    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            Positioned(
              left: isLandscape ? screenWidth * 0.65 : screenWidth / 1.85,
              top: isLandscape ? -50 : 0,
              child: IgnorePointer(
                child: SizedBox(
                  width: isLandscape ? screenHeight * 0.8 : screenWidth,
                  height: isLandscape ? screenHeight * 0.8 : screenWidth,
                  child: const Image(
                    image: AssetImage('assets/icon-white-trans.png'),
                  ),
                ),
              ),
            ),
            const GradientContainer(
              child: null,
              opacity: true,
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isNarrow = constraints.maxWidth < 360;
                  final double horizontalPadding = isNarrow ? 16.0 : (constraints.maxWidth > 600 ? (constraints.maxWidth - 500) / 2 : 30.0);

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  TextButton(
                                    onPressed: () async {
                                      await restore(context);
                                      GetIt.I<MyTheme>().refresh();
                                      Navigator.popAndPushNamed(context, '/');
                                    },
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        AppLocalizations.of(context)!.restore,
                                        style: TextStyle(
                                          color: Colors.grey.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      await _addUserData(
                                        AppLocalizations.of(context)!.guest,
                                      );
                                      Navigator.popAndPushNamed(context, '/pref');
                                    },
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        AppLocalizations.of(context)!.skip,
                                        style: TextStyle(
                                          color: Colors.grey.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12.0),
                            physics: const BouncingScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 600),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: RichText(
                                        text: TextSpan(
                                          text: 'Black\nHole\n',
                                          style: TextStyle(
                                            height: 0.97,
                                            fontSize: isNarrow ? 55 : 80,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.secondary,
                                          ),
                                          children: <TextSpan>[
                                            TextSpan(
                                              text: 'Music',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: isNarrow ? 55 : 80,
                                                color: Colors.white,
                                              ),
                                            ),
                                            TextSpan(
                                              text: '.',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: isNarrow ? 55 : 80,
                                                color: Theme.of(context).colorScheme.secondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: isLandscape ? 16.0 : 32.0),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0,
                                      vertical: 4.0,
                                    ),
                                    constraints: const BoxConstraints(
                                      minHeight: 57.0,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10.0),
                                      color: Colors.grey[900],
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 5.0,
                                          offset: Offset(0.0, 3.0),
                                        )
                                      ],
                                    ),
                                    child: Center(
                                      child: TextField(
                                        controller: controller,
                                        textAlignVertical: TextAlignVertical.center,
                                        textCapitalization: TextCapitalization.sentences,
                                        keyboardType: TextInputType.name,
                                        decoration: InputDecoration(
                                          focusedBorder: const UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              width: 1.5,
                                              color: Colors.transparent,
                                            ),
                                          ),
                                          prefixIcon: Icon(
                                            Icons.person,
                                            color: Theme.of(context).colorScheme.secondary,
                                          ),
                                          border: InputBorder.none,
                                          hintText: AppLocalizations.of(context)!.enterName,
                                          hintStyle: const TextStyle(
                                            color: Colors.white60,
                                          ),
                                        ),
                                        onSubmitted: (String value) async {
                                          if (value.trim() == '') {
                                            await _addUserData(
                                              AppLocalizations.of(context)!.guest,
                                            );
                                          } else {
                                            await _addUserData(value.trim());
                                          }
                                          Navigator.popAndPushNamed(
                                            context,
                                            '/pref',
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14.0),
                                  GestureDetector(
                                    onTap: () async {
                                      if (controller.text.trim() == '') {
                                        await _addUserData('Guest');
                                      } else {
                                        await _addUserData(
                                          controller.text.trim(),
                                        );
                                      }
                                      Navigator.popAndPushNamed(context, '/pref');
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14.0,
                                        horizontal: 16.0,
                                      ),
                                      constraints: const BoxConstraints(
                                        minHeight: 55.0,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10.0),
                                        color: Theme.of(context).colorScheme.secondary,
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 5.0,
                                            offset: Offset(0.0, 3.0),
                                          )
                                        ],
                                      ),
                                      child: Center(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            AppLocalizations.of(context)!.getStarted,
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12.0,
                                    ),
                                    child: Text(
                                      '${AppLocalizations.of(context)!.disclaimer} ${AppLocalizations.of(context)!.disclaimerText}',
                                      style: TextStyle(
                                        color: Colors.grey.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
