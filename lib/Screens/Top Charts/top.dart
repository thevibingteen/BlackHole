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
import 'package:blackhole/CustomWidgets/custom_physics.dart';
import 'package:blackhole/CustomWidgets/empty_screen.dart';
import 'package:blackhole/Services/player_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

List localSongs = [];
List globalSongs = [];
bool localFetched = false;
bool globalFetched = false;
final ValueNotifier<bool> localFetchFinished = ValueNotifier<bool>(false);
final ValueNotifier<bool> globalFetchFinished = ValueNotifier<bool>(false);

const Map<String, String> jioSaavnCharts = {
  'India Superhits Top 50': '1134548194',
  'Trending Today': '110858205',
  'Hindi: India Superhits Top 50': '1134543272',
  'International : India Superhits Top 50': '1134595537',
  'Punjabi: India Superhits Top 50': '1134543511',
};

class TopCharts extends StatefulWidget {
  final PageController pageController;
  const TopCharts({super.key, required this.pageController});

  @override
  _TopChartsState createState() => _TopChartsState();
}

class _TopChartsState extends State<TopCharts>
    with AutomaticKeepAliveClientMixin<TopCharts> {
  final ValueNotifier<bool> localFetchFinished = ValueNotifier<bool>(false);

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext cntxt) {
    super.build(context);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool rotated = MediaQuery.of(context).size.height < screenWidth;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: IconButton(
                icon: const Icon(Icons.my_location_rounded),
                tooltip: 'Select Chart',
                onPressed: () async {
                  final String current = Hive.box('settings')
                      .get('region', defaultValue: 'India Superhits Top 50')
                      .toString();
                  await showDialog(
                    context: context,
                    builder: (BuildContext ctx) {
                      return SimpleDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15.0),
                        ),
                        title: const Text('Select JioSaavn Chart'),
                        children: jioSaavnCharts.keys.map((String name) {
                          final bool isSelected = current == name ||
                              (current == 'India' &&
                                  name == 'India Superhits Top 50');
                          return SimpleDialogOption(
                            onPressed: () {
                              final String id = jioSaavnCharts[name]!;
                              Hive.box('settings').put('saavn_chart_id', id);
                              Hive.box('settings').put('region', name);
                              Navigator.pop(ctx);
                              localFetchFinished.value = false;
                              scrapData(name);
                              setState(() {});
                            },
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.secondary
                                      : null,
                                ),
                                const SizedBox(width: 12.0),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  );
                },
              ),
            ),
          ],
          bottom: TabBar(
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(
                child: Text(
                  AppLocalizations.of(context)!.local,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                ),
              ),
              Tab(
                child: Text(
                  AppLocalizations.of(context)!.global,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                ),
              ),
            ],
          ),
          title: Text(
            'JioSaavn Charts',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).textTheme.bodyLarge!.color,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: rotated
              ? null
              : Builder(
                  builder: (BuildContext context) {
                    return Transform.rotate(
                      angle: 22 / 7 * 2,
                      child: IconButton(
                        color: Theme.of(context).iconTheme.color,
                        icon: const Icon(
                          Icons.horizontal_split_rounded,
                        ),
                        onPressed: () {
                          Scaffold.of(cntxt).openDrawer();
                        },
                        tooltip: MaterialLocalizations.of(cntxt)
                            .openAppDrawerTooltip,
                      ),
                    );
                  },
                ),
        ),
        body: NotificationListener(
          onNotification: (overscroll) {
            if (overscroll is OverscrollNotification &&
                overscroll.overscroll != 0 &&
                overscroll.dragDetails != null) {
              widget.pageController.animateToPage(
                overscroll.overscroll < 0 ? 0 : 2,
                curve: Curves.ease,
                duration: const Duration(milliseconds: 150),
              );
            }
            return true;
          },
          child: TabBarView(
            physics: const CustomPhysics(),
            children: [
              ValueListenableBuilder(
                valueListenable: Hive.box('settings').listenable(),
                builder: (BuildContext context, Box box, Widget? widget) {
                  return TopPage(
                    type: box
                        .get('region',
                            defaultValue: 'India Superhits Top 50')
                        .toString(),
                  );
                },
              ),
              const TopPage(type: 'Global'),
            ],
          ),
        ),
      ),
    );
  }
}

Future<List> getChartDetails(String type) async {
  String playlistId;
  if (type == 'Global') {
    playlistId = '1134595537'; // International : India Superhits Top 50
  } else {
    playlistId = jioSaavnCharts[type] ??
        (Hive.isBoxOpen('settings')
            ? Hive.box('settings')
                .get('saavn_chart_id', defaultValue: '1134548194')
                .toString()
            : '1134548194');
  }
  try {
    final Map res = await SaavnAPI().fetchPlaylistSongs(playlistId);
    final List songs = (res['songs'] as List? ?? []);
    final List data = [];
    for (final song in songs) {
      if (song is Map) {
        final Map item = Map.from(song);
        item['name'] = item['title'] ?? '';
        item['image_url_small'] = item['image'] ?? '';
        item['image_url_big'] = item['image'] ?? '';
        item['spotifyUrl'] = item['perma_url'] ?? '';
        data.add(item);
      }
    }
    return data;
  } catch (e) {
    Logger.root.severe('Error in getChartDetails ($type, id: $playlistId): $e');
    return [];
  }
}

Future<void> scrapData(String type, {bool signIn = false}) async {
  final temp = await getChartDetails(type);
  if (temp.isNotEmpty) {
    await Hive.box('cache').put('${type}_chart', temp);
    if (type == 'Global') {
      globalSongs = temp;
    } else {
      localSongs = temp;
    }
  }
  if (type == 'Global') {
    globalFetchFinished.value = true;
  } else {
    localFetchFinished.value = true;
  }
}

class TopPage extends StatefulWidget {
  final String type;
  const TopPage({super.key, required this.type});
  @override
  _TopPageState createState() => _TopPageState();
}

class _TopPageState extends State<TopPage>
    with AutomaticKeepAliveClientMixin<TopPage> {
  Future<void> getCachedData(String type) async {
    if (type == 'Global') {
      globalFetched = true;
    } else {
      localFetched = true;
    }
    if (type == 'Global') {
      globalSongs = await Hive.box('cache')
          .get('${type}_chart', defaultValue: []) as List;
    } else {
      localSongs = await Hive.box('cache')
          .get('${type}_chart', defaultValue: []) as List;
    }
    setState(() {});
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    getCachedData(widget.type);
    scrapData(widget.type);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bool isGlobal = widget.type == 'Global';
    if ((isGlobal && !globalFetched) || (!isGlobal && !localFetched)) {
      getCachedData(widget.type);
      scrapData(widget.type);
    }
    return ValueListenableBuilder(
      valueListenable: isGlobal ? globalFetchFinished : localFetchFinished,
      builder: (BuildContext context, bool value, Widget? child) {
        final List showList = isGlobal ? globalSongs : localSongs;
        return Column(
          children: [
            if (showList.isEmpty)
              Expanded(
                child: value
                    ? emptyScreen(
                        context,
                        0,
                        ':( ',
                        100,
                        'ERROR',
                        60,
                        'Service Unavailable',
                        20,
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                        ],
                      ),
              )
            else
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: showList.length,
                  itemExtent: 70.0,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: Card(
                        margin: EdgeInsets.zero,
                        elevation: 5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7.0),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            const Image(
                              image: AssetImage('assets/cover.jpg'),
                            ),
                            if (showList[index]['image_url_small'] != '')
                              CachedNetworkImage(
                                fit: BoxFit.cover,
                                imageUrl: showList[index]['image_url_small']
                                    .toString(),
                                errorWidget: (context, _, __) => const Image(
                                  fit: BoxFit.cover,
                                  image: AssetImage('assets/cover.jpg'),
                                ),
                                placeholder: (context, url) => const Image(
                                  fit: BoxFit.cover,
                                  image: AssetImage('assets/cover.jpg'),
                                ),
                              ),
                          ],
                        ),
                      ),
                      title: Text(
                        '${index + 1}. ${showList[index]["name"]}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        showList[index]['artist'].toString(),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: PopupMenuButton(
                        icon: const Icon(Icons.more_vert_rounded),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(15.0),
                          ),
                        ),
                        onSelected: (int? value) async {
                          if (value == 0) {
                            await launchUrl(
                              Uri.parse(
                                showList[index]['spotifyUrl'].toString(),
                              ),
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 0,
                            child: Row(
                              children: [
                                Icon(Icons.open_in_new_rounded),
                                SizedBox(width: 10.0),
                                Text(
                                  'Open in JioSaavn',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        PlayerInvoke.init(
                          songsList: showList,
                          index: index,
                          isOffline: false,
                        );
                        Navigator.pushNamed(
                          context,
                          '/player',
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
