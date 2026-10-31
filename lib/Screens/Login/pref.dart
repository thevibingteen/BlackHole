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

import 'package:blackhole/APIs/api.dart';
import 'package:blackhole/CustomWidgets/gradient_containers.dart';
import 'package:blackhole/CustomWidgets/snackbar.dart';
import 'package:blackhole/Helpers/backup_restore.dart';
import 'package:blackhole/Helpers/config.dart';
import 'package:blackhole/Helpers/countrycodes.dart';
import 'package:blackhole/Screens/Home/saavn.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';

class PrefScreen extends StatefulWidget {
  const PrefScreen({super.key});

  @override
  _PrefScreenState createState() => _PrefScreenState();
}

class _PrefScreenState extends State<PrefScreen> {
  List<String> languages = [
    'Hindi',
    'English',
    'Punjabi',
    'Tamil',
    'Telugu',
    'Marathi',
    'Gujarati',
    'Bengali',
    'Kannada',
    'Bhojpuri',
    'Malayalam',
    'Urdu',
    'Haryanvi',
    'Rajasthani',
    'Odia',
    'Assamese'
  ];
  List<bool> isSelected = [true, false];
  List preferredLanguage = Hive.box('settings')
      .get('preferredLanguage', defaultValue: ['Hindi'])?.toList() as List;
  String region =
      Hive.box('settings').get('region', defaultValue: 'India') as String;

  Widget _buildPrefSelector({
    required BuildContext context,
    required String title,
    required String value,
    required VoidCallback onTap,
    required bool isNarrow,
  }) {
    final bool stackVertical = isNarrow || MediaQuery.textScalerOf(context).scale(1.0) > 1.35;
    if (stackVertical) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6.0),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14.0,
                  vertical: 12.0,
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
                child: Text(
                  value.isEmpty ? 'None' : value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      trailing: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10.0,
          vertical: 6.0,
        ),
        constraints: const BoxConstraints(
          minHeight: 48.0,
          maxWidth: 160.0,
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
          child: Text(
            value.isEmpty ? 'None' : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ),
      dense: true,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final bool isLandscape = screenHeight < screenWidth;

    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
                                      Navigator.popAndPushNamed(context, '/');
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
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12.0),
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
                                          text: '${AppLocalizations.of(context)!.welcome}\n',
                                          style: TextStyle(
                                            fontSize: isNarrow ? 48 : 65,
                                            height: 1.0,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.secondary,
                                          ),
                                          children: <TextSpan>[
                                            TextSpan(
                                              text: AppLocalizations.of(context)!.aboard,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: isNarrow ? 54 : 75,
                                                color: Colors.white,
                                              ),
                                            ),
                                            TextSpan(
                                              text: '!\n',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: isNarrow ? 50 : 70,
                                                color: Theme.of(context).colorScheme.secondary,
                                              ),
                                            ),
                                            TextSpan(
                                              text: AppLocalizations.of(context)!.prefReq,
                                              style: const TextStyle(
                                                height: 1.5,
                                                fontWeight: FontWeight.w300,
                                                fontSize: 18,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: isLandscape ? 16.0 : 28.0),
                                  _buildPrefSelector(
                                    context: context,
                                    title: AppLocalizations.of(context)!.langQue,
                                    value: preferredLanguage.join(', '),
                                    isNarrow: isNarrow,
                                    onTap: () {
                                      showModalBottomSheet(
                                        isDismissible: true,
                                        backgroundColor: Colors.transparent,
                                        context: context,
                                        builder: (BuildContext context) {
                                          final List checked = List.from(preferredLanguage);
                                          return StatefulBuilder(
                                            builder: (BuildContext context, StateSetter setStt) {
                                              return BottomGradientContainer(
                                                borderRadius: BorderRadius.circular(20.0),
                                                child: Column(
                                                  children: [
                                                    Expanded(
                                                      child: ListView.builder(
                                                        physics: const BouncingScrollPhysics(),
                                                        shrinkWrap: true,
                                                        padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                                                        itemCount: languages.length,
                                                        itemBuilder: (context, idx) {
                                                          return CheckboxListTile(
                                                            activeColor: Theme.of(context).colorScheme.secondary,
                                                            value: checked.contains(languages[idx]),
                                                            title: Text(languages[idx]),
                                                            onChanged: (bool? value) {
                                                              value!
                                                                  ? checked.add(languages[idx])
                                                                  : checked.remove(languages[idx]);
                                                              setStt(() {});
                                                            },
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      children: [
                                                        TextButton(
                                                          style: TextButton.styleFrom(
                                                            foregroundColor: Theme.of(context).colorScheme.secondary,
                                                          ),
                                                          onPressed: () {
                                                            Navigator.pop(context);
                                                          },
                                                          child: Text(
                                                            AppLocalizations.of(context)!.cancel,
                                                          ),
                                                        ),
                                                        TextButton(
                                                          style: TextButton.styleFrom(
                                                            foregroundColor: Theme.of(context).colorScheme.secondary,
                                                          ),
                                                          onPressed: () async {
                                                            Navigator.pop(context);
                                                            final selected = List<String>.from(checked);
                                                            final validation = await SaavnAPI().validateLanguages(selected);
                                                            final unavailable = <String>[];
                                                            final finalChecked = <String>[];
                                                            for (final lang in selected) {
                                                              if (validation[lang] == LanguageAvailability.unavailable) {
                                                                unavailable.add(lang);
                                                              } else {
                                                                finalChecked.add(lang);
                                                              }
                                                            }

                                                            if (unavailable.isNotEmpty && mounted) {
                                                              ShowSnackBar().showSnackBar(
                                                                context,
                                                                'Unavailable on JioSaavn: ' + unavailable.join(', ') + '. Deselected.',
                                                                duration: const Duration(seconds: 4),
                                                              );
                                                            }

                                                            if (mounted) {
                                                              setState(() {
                                                                preferredLanguage = finalChecked;
                                                              });
                                                            }
                                                            Hive.box('settings').put(
                                                              'preferredLanguage',
                                                              finalChecked,
                                                            );
                                                            SaavnHomePage.resetHomeFeed();

                                                            if (finalChecked.isEmpty && mounted) {
                                                              ShowSnackBar().showSnackBar(
                                                                context,
                                                                AppLocalizations.of(context)!.noLangSelected,
                                                              );
                                                            }
                                                          },
                                                          child: Text(
                                                            AppLocalizations.of(context)!.ok,
                                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12.0),
                                  _buildPrefSelector(
                                    context: context,
                                    title: AppLocalizations.of(context)!.countryQue,
                                    value: region,
                                    isNarrow: isNarrow,
                                    onTap: () {
                                      showModalBottomSheet(
                                        isDismissible: true,
                                        backgroundColor: Colors.transparent,
                                        context: context,
                                        builder: (BuildContext context) {
                                          const Map<String, String> codes = ConstantCodes.localChartCodes;
                                          final List<String> countries = codes.keys.toList();
                                          return BottomGradientContainer(
                                            borderRadius: BorderRadius.circular(20.0),
                                            child: ListView.builder(
                                              physics: const BouncingScrollPhysics(),
                                              shrinkWrap: true,
                                              padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                                              itemCount: countries.length,
                                              itemBuilder: (context, idx) {
                                                return ListTileTheme(
                                                  selectedColor: Theme.of(context).colorScheme.secondary,
                                                  child: ListTile(
                                                    contentPadding: const EdgeInsets.only(left: 25.0, right: 25.0),
                                                    title: Text(countries[idx]),
                                                    trailing: region == countries[idx]
                                                        ? const Icon(Icons.check_rounded)
                                                        : const SizedBox(),
                                                    selected: region == countries[idx],
                                                    onTap: () {
                                                      region = countries[idx];
                                                      Hive.box('settings').put('region', region);
                                                      Navigator.pop(context);
                                                      setState(() {});
                                                    },
                                                  ),
                                                );
                                              },
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 18.0),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.popAndPushNamed(context, '/');
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
                                            AppLocalizations.of(context)!.finish,
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
