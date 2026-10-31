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

import 'dart:io';

import 'package:blackhole/CustomWidgets/add_playlist.dart';
import 'package:blackhole/CustomWidgets/data_search.dart';
import 'package:blackhole/CustomWidgets/empty_screen.dart';
import 'package:blackhole/CustomWidgets/gradient_containers.dart';
import 'package:blackhole/CustomWidgets/miniplayer.dart';
import 'package:blackhole/CustomWidgets/playlist_head.dart';
import 'package:blackhole/CustomWidgets/snackbar.dart';
import 'package:blackhole/Helpers/audio_query.dart';
import 'package:blackhole/Helpers/song_delete_helper.dart';
import 'package:blackhole/Screens/LocalMusic/localplaylists.dart';
import 'package:blackhole/Services/player_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

class DownloadedSongs extends StatefulWidget {
  final List<SongModel>? cachedSongs;
  final String? title;
  final int? playlistId;
  final bool showPlaylists;
  const DownloadedSongs({
    super.key,
    this.cachedSongs,
    this.title,
    this.playlistId,
    this.showPlaylists = false,
  });
  @override
  _DownloadedSongsState createState() => _DownloadedSongsState();
}

class _DownloadedSongsState extends State<DownloadedSongs>
    with TickerProviderStateMixin {
  List<SongModel> _songs = [];
  String? tempPath = Hive.box('settings').get('tempDirPath')?.toString();
  final Map<String, List<SongModel>> _albums = {};
  final Map<String, List<SongModel>> _artists = {};
  final Map<String, List<SongModel>> _genres = {};
  final Map<String, List<SongModel>> _folders = {};

  final List<String> _sortedAlbumKeysList = [];
  final List<String> _sortedArtistKeysList = [];
  final List<String> _sortedGenreKeysList = [];
  final List<String> _sortedFolderKeysList = [];
  // final List<String> _videos = [];

  bool added = false;
  int sortValue = Hive.box('settings').get('sortValue', defaultValue: 1) as int;
  int orderValue =
      Hive.box('settings').get('orderValue', defaultValue: 1) as int;
  int albumSortValue =
      Hive.box('settings').get('albumSortValue', defaultValue: 2) as int;
  List dirPaths =
      Hive.box('settings').get('searchPaths', defaultValue: []) as List;
  int minDuration =
      Hive.box('settings').get('minDuration', defaultValue: 10) as int;
  bool includeOrExclude =
      Hive.box('settings').get('includeOrExclude', defaultValue: false) as bool;
  List includedExcludedPaths = Hive.box('settings')
      .get('includedExcludedPaths', defaultValue: []) as List;
  TabController? _tcontroller;
  int _currentTabIndex = 0;
  OfflineAudioQuery offlineAudioQuery = OfflineAudioQuery();
  List<PlaylistModel> playlistDetails = [];

  final Map<int, SongSortType> songSortTypes = {
    0: SongSortType.DISPLAY_NAME,
    1: SongSortType.DATE_ADDED,
    2: SongSortType.ALBUM,
    3: SongSortType.ARTIST,
    4: SongSortType.DURATION,
    5: SongSortType.SIZE,
  };

  final Map<int, OrderType> songOrderTypes = {
    0: OrderType.ASC_OR_SMALLER,
    1: OrderType.DESC_OR_GREATER,
  };

  @override
  void initState() {
    _tcontroller =
        TabController(length: widget.showPlaylists ? 6 : 5, vsync: this);
    _tcontroller!.addListener(() {
      if ((_tcontroller!.previousIndex != 0 && _tcontroller!.index == 0) ||
          (_tcontroller!.previousIndex == 0)) {
        setState(() => _currentTabIndex = _tcontroller!.index);
      }
    });
    getData();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _tcontroller!.dispose();
  }

  bool checkIncludedOrExcluded(SongModel song) {
    for (final path in includedExcludedPaths) {
      if (song.data.contains(path.toString())) return true;
    }
    return false;
  }

  Future<void> getData() async {
    try {
      Logger.root.info('Requesting permission to access local songs');
      await offlineAudioQuery.requestPermission();
      tempPath ??= (await getTemporaryDirectory()).path;
      if (Platform.isAndroid) {
        Logger.root.info('Getting local playlists');
        playlistDetails = await offlineAudioQuery.getPlaylists();
      }
      if (widget.cachedSongs == null) {
        Logger.root.info('Cache empty, calling audioQuery');
        final receivedSongs = await offlineAudioQuery.getSongs(
          sortType: songSortTypes[sortValue],
          orderType: songOrderTypes[orderValue],
        );
        Logger.root.info('Received ${receivedSongs.length} songs, filtering');
        _songs = receivedSongs
            .where(
              (i) =>
                  (i.duration ?? 60000) > 1000 * minDuration &&
                  ((i.isMusic ?? false) ||
                      (i.isPodcast ?? false) ||
                      (i.isAudioBook ?? false) ||
                      (i.isMusic == null &&
                          i.isPodcast == null &&
                          i.isAudioBook == null)) &&
                  (includeOrExclude
                      ? checkIncludedOrExcluded(i)
                      : !checkIncludedOrExcluded(i)),
            )
            .toList();
      } else {
        Logger.root.info('Setting songs to cached songs');
        _songs = widget.cachedSongs!;
      }
      added = true;
      Logger.root.info('got ${_songs.length} songs');
      setState(() {});
      Logger.root.info('setting albums and artists');
      for (int i = 0; i < _songs.length; i++) {
        try {
          if (_albums.containsKey(_songs[i].album ?? 'Unknown')) {
            _albums[_songs[i].album ?? 'Unknown']!.add(_songs[i]);
          } else {
            _albums[_songs[i].album ?? 'Unknown'] = [_songs[i]];
            _sortedAlbumKeysList.add(_songs[i].album ?? 'Unknown');
          }

          if (_artists.containsKey(_songs[i].artist ?? 'Unknown')) {
            _artists[_songs[i].artist ?? 'Unknown']!.add(_songs[i]);
          } else {
            _artists[_songs[i].artist ?? 'Unknown'] = [_songs[i]];
            _sortedArtistKeysList.add(_songs[i].artist ?? 'Unknown');
          }

          if (_genres.containsKey(_songs[i].genre ?? 'Unknown')) {
            _genres[_songs[i].genre ?? 'Unknown']!.add(_songs[i]);
          } else {
            _genres[_songs[i].genre ?? 'Unknown'] = [_songs[i]];
            _sortedGenreKeysList.add(_songs[i].genre ?? 'Unknown');
          }

          final tempPath = _songs[i].data.split('/');
          if (tempPath.length > 1) {
            tempPath.removeLast();
          }
          final dirPath = tempPath.join('/');

          if (_folders.containsKey(dirPath)) {
            _folders[dirPath]!.add(_songs[i]);
          } else {
            _folders[dirPath] = [_songs[i]];
            _sortedFolderKeysList.add(dirPath);
          }
        } catch (e) {
          Logger.root.severe('Error in sorting songs', e);
        }
      }
      Logger.root.info('albums, artists, genre & folders set');
    } catch (e) {
      Logger.root.severe('Error in getData', e);
      added = true;
    }
  }

  Future<void> sortSongs(int sortVal, int order) async {
    Logger.root.info('Sorting songs');
    switch (sortVal) {
      case 0:
        _songs.sort(
          (a, b) => a.displayName.compareTo(b.displayName),
        );
        break;
      case 1:
        _songs.sort(
          (a, b) => a.dateAdded.toString().compareTo(b.dateAdded.toString()),
        );
        break;
      case 2:
        _songs.sort(
          (a, b) => a.album.toString().compareTo(b.album.toString()),
        );
        break;
      case 3:
        _songs.sort(
          (a, b) => a.artist.toString().compareTo(b.artist.toString()),
        );
        break;
      case 4:
        _songs.sort(
          (a, b) => a.duration.toString().compareTo(b.duration.toString()),
        );
        break;
      case 5:
        _songs.sort(
          (a, b) => a.size.toString().compareTo(b.size.toString()),
        );
        break;
      default:
        _songs.sort(
          (a, b) => a.dateAdded.toString().compareTo(b.dateAdded.toString()),
        );
        break;
    }

    if (order == 1) {
      _songs = _songs.reversed.toList();
    }
    Logger.root.info('Done Sorting songs');
  }

  @override
  Widget build(BuildContext context) {
    return GradientContainer(
      child: Column(
        children: [
          Expanded(
            child: DefaultTabController(
              length: widget.showPlaylists ? 6 : 5,
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  title: Text(
                    widget.title ?? AppLocalizations.of(context)!.myMusic,
                  ),
                  bottom: TabBar(
                    isScrollable: widget.showPlaylists,
                    controller: _tcontroller,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: [
                      Tab(
                        text: AppLocalizations.of(context)!.songs,
                      ),
                      Tab(
                        text: AppLocalizations.of(context)!.albums,
                      ),
                      Tab(
                        text: AppLocalizations.of(context)!.artists,
                      ),
                      Tab(
                        text: AppLocalizations.of(context)!.genres,
                      ),
                      Tab(
                        text: AppLocalizations.of(context)!.folders,
                      ),
                      if (widget.showPlaylists)
                        Tab(
                          text: AppLocalizations.of(context)!.playlists,
                        ),
                      //     Tab(
                      //       text: AppLocalizations.of(context)!.videos,
                      //     )
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(CupertinoIcons.search),
                      tooltip: AppLocalizations.of(context)!.search,
                      onPressed: () {
                        showSearch(
                          context: context,
                          delegate: DataSearch(
                            data: _songs,
                            tempPath: tempPath!,
                          ),
                        );
                      },
                    ),
                    if (_currentTabIndex == 0)
                      PopupMenuButton(
                        icon: const Icon(Icons.sort_rounded),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(15.0)),
                        ),
                        onSelected: (int value) async {
                          if (value < 6) {
                            sortValue = value;
                            Hive.box('settings').put('sortValue', value);
                          } else {
                            orderValue = value - 6;
                            Hive.box('settings').put('orderValue', orderValue);
                          }
                          await sortSongs(sortValue, orderValue);
                          setState(() {});
                        },
                        itemBuilder: (context) {
                          final List<String> sortTypes = [
                            AppLocalizations.of(context)!.displayName,
                            AppLocalizations.of(context)!.dateAdded,
                            AppLocalizations.of(context)!.album,
                            AppLocalizations.of(context)!.artist,
                            AppLocalizations.of(context)!.duration,
                            AppLocalizations.of(context)!.size,
                          ];
                          final List<String> orderTypes = [
                            AppLocalizations.of(context)!.inc,
                            AppLocalizations.of(context)!.dec,
                          ];
                          final menuList = <PopupMenuEntry<int>>[];
                          menuList.addAll(
                            sortTypes
                                .map(
                                  (e) => PopupMenuItem(
                                    value: sortTypes.indexOf(e),
                                    child: Row(
                                      children: [
                                        if (sortValue == sortTypes.indexOf(e))
                                          Icon(
                                            Icons.check_rounded,
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? Colors.white
                                                    : Colors.grey[700],
                                          )
                                        else
                                          const SizedBox(),
                                        const SizedBox(width: 10),
                                        Text(
                                          e,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                          menuList.add(
                            const PopupMenuDivider(
                              height: 10,
                            ),
                          );
                          menuList.addAll(
                            orderTypes
                                .map(
                                  (e) => PopupMenuItem(
                                    value: sortTypes.length +
                                        orderTypes.indexOf(e),
                                    child: Row(
                                      children: [
                                        if (orderValue == orderTypes.indexOf(e))
                                          Icon(
                                            Icons.check_rounded,
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? Colors.white
                                                    : Colors.grey[700],
                                          )
                                        else
                                          const SizedBox(),
                                        const SizedBox(width: 10),
                                        Text(
                                          e,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                          return menuList;
                        },
                      ),
                  ],
                  centerTitle: true,
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.transparent
                          : Theme.of(context).colorScheme.secondary,
                  elevation: 0,
                ),
                body: !added
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : TabBarView(
                        physics: const PageScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        controller: _tcontroller,
                        children: [
                          SongsTab(
                            key: const PageStorageKey('my_music_songs_tab'),
                            songs: _songs,
                            playlistId: widget.playlistId,
                            playlistName: widget.title,
                            tempPath: tempPath!,
                          ),
                          AlbumsTab(
                            key: const PageStorageKey('my_music_albums_tab'),
                            albums: _albums,
                            albumsList: _sortedAlbumKeysList,
                            tempPath: tempPath!,
                          ),
                          AlbumsTab(
                            key: const PageStorageKey('my_music_artists_tab'),
                            albums: _artists,
                            albumsList: _sortedArtistKeysList,
                            tempPath: tempPath!,
                          ),
                          AlbumsTab(
                            key: const PageStorageKey('my_music_genres_tab'),
                            albums: _genres,
                            albumsList: _sortedGenreKeysList,
                            tempPath: tempPath!,
                          ),
                          AlbumsTab(
                            key: const PageStorageKey('my_music_folders_tab'),
                            albums: _folders,
                            albumsList: _sortedFolderKeysList,
                            tempPath: tempPath!,
                          ),
                          if (widget.showPlaylists)
                            LocalPlaylists(
                              key: const PageStorageKey('my_music_playlists_tab'),
                              playlistDetails: playlistDetails,
                              offlineAudioQuery: offlineAudioQuery,
                            ),
                          // videosTab(),
                        ],
                      ),
              ),
            ),
          ),
          MiniPlayer(),
        ],
      ),
    );
  }

//   Widget videosTab() {
//     return _cachedVideos.isEmpty
//         ? EmptyScreen().emptyScreen(context, 3, 'Nothing to ', 15.0,
//             'Show Here', 45, 'Download Something', 23.0)
//         : ListView.builder(
//             physics: const BouncingScrollPhysics(),
//             padding: const EdgeInsets.only(top: 20, bottom: 10),
//             shrinkWrap: true,
//             itemExtent: 70.0,
//             itemCount: _cachedVideos.length,
//             itemBuilder: (context, index) {
//               return ListTile(
//                 leading: Card(
//                   elevation: 5,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(7.0),
//                   ),
//                   clipBehavior: Clip.antiAlias,
//                   child: Stack(
//                     children: [
//                       const Image(
//                         image: AssetImage('assets/cover.jpg'),
//                       ),
//                       if (_cachedVideos[index]['image'] == null)
//                         const SizedBox()
//                       else
//                         SizedBox(
//                           height: 50.0,
//                           width: 50.0,
//                           child: Image(
//                             fit: BoxFit.cover,
//                             image: MemoryImage(
//                                 _cachedVideos[index]['image'] as Uint8List),
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),
//                 title: Text(
//                   '${_cachedVideos[index]['id'].split('/').last}',
//                   overflow: TextOverflow.ellipsis,
//                   maxLines: 2,
//                 ),
//                 trailing: PopupMenuButton(
//                   icon: const Icon(Icons.more_vert_rounded),
//                   shape: const RoundedRectangleBorder(
//                       borderRadius: BorderRadius.all(Radius.circular(15.0))),
//                   onSelected: (dynamic value) async {
//                     if (value == 0) {
//                       showDialog(
//                         context: context,
//                         builder: (BuildContext context) {
//                           final String fileName = _cachedVideos[index]['id']
//                               .split('/')
//                               .last
//                               .toString();
//                           final List temp = fileName.split('.');
//                           temp.removeLast();
//                           final String videoName = temp.join('.');
//                           final controller =
//                               TextEditingController(text: videoName);
//                           return AlertDialog(
//                             content: Column(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 Row(
//                                   children: [
//                                     Text(
//                                       'Name',
//                                       style: TextStyle(
//                                           color: Theme.of(context).accentColor),
//                                     ),
//                                   ],
//                                 ),
//                                 const SizedBox(
//                                   height: 10,
//                                 ),
//                                 TextField(
//                                     autofocus: true,
//                                     controller: controller,
//                                     onSubmitted: (value) async {
//                                       try {
//                                         Navigator.pop(context);
//                                         String newName = _cachedVideos[index]
//                                                 ['id']
//                                             .toString()
//                                             .replaceFirst(videoName, value);

//                                         while (await File(newName).exists()) {
//                                           newName = newName.replaceFirst(
//                                               value, '$value (1)');
//                                         }

//                                         File(_cachedVideos[index]['id']
//                                                 .toString())
//                                             .rename(newName);
//                                         _cachedVideos[index]['id'] = newName;
//                                         ShowSnackBar().showSnackBar(
//                                           context,
//                                           'Renamed to ${_cachedVideos[index]['id'].split('/').last}',
//                                         );
//                                       } catch (e) {
//                                         ShowSnackBar().showSnackBar(
//                                           context,
//                                           'Failed to Rename ${_cachedVideos[index]['id'].split('/').last}',
//                                         );
//                                       }
//                                       setState(() {});
//                                     }),
//                               ],
//                             ),
//                             actions: [
//                               TextButton(
//                                 style: TextButton.styleFrom(
//                                   primary: Theme.of(context).brightness ==
//                                           Brightness.dark
//                                       ? Colors.white
//                                       : Colors.grey[700],
//                                   //       backgroundColor: Theme.of(context).accentColor,
//                                 ),
//                                 onPressed: () {
//                                   Navigator.pop(context);
//                                 },
//                                 child: const Text(
//                                   'Cancel',
//                                 ),
//                               ),
//                               TextButton(
//                                 style: TextButton.styleFrom(
//                                   primary: Colors.white,
//                                   backgroundColor:
//                                       Theme.of(context).accentColor,
//                                 ),
//                                 onPressed: () async {
//                                   try {
//                                     Navigator.pop(context);
//                                     String newName = _cachedVideos[index]['id']
//                                         .toString()
//                                         .replaceFirst(
//                                             videoName, controller.text);

//                                     while (await File(newName).exists()) {
//                                       newName = newName.replaceFirst(
//                                           controller.text,
//                                           '${controller.text} (1)');
//                                     }

//                                     File(_cachedVideos[index]['id'].toString())
//                                         .rename(newName);
//                                     _cachedVideos[index]['id'] = newName;
//                                     ShowSnackBar().showSnackBar(
//                                       context,
//                                       'Renamed to ${_cachedVideos[index]['id'].split('/').last}',
//                                     );
//                                   } catch (e) {
//                                     ShowSnackBar().showSnackBar(
//                                       context,
//                                       'Failed to Rename ${_cachedVideos[index]['id'].split('/').last}',
//                                     );
//                                   }
//                                   setState(() {});
//                                 },
//                                 child: const Text(
//                                   'Ok',
//                                   style: TextStyle(color: Colors.white),
//                                 ),
//                               ),
//                               const SizedBox(
//                                 width: 5,
//                               ),
//                             ],
//                           );
//                         },
//                       );
//                     }
//                     if (value == 1) {
//                       try {
//                         File(_cachedVideos[index]['id'].toString()).delete();
//                         ShowSnackBar().showSnackBar(
//                           context,
//                           'Deleted ${_cachedVideos[index]['id'].split('/').last}',
//                         );
//                         _cachedVideos.remove(_cachedVideos[index]);
//                       } catch (e) {
//                         ShowSnackBar().showSnackBar(
//                           context,
//                           'Failed to delete ${_cachedVideos[index]['id']}',
//                         );
//                       }
//                       setState(() {});
//                     }
//                   },
//                   itemBuilder: (context) => [
//                     PopupMenuItem(
//                       value: 0,
//                       child: Row(
//                         children: const [
//                           Icon(Icons.edit_rounded),
//                           const SizedBox(width: 10.0),
//                           Text('Rename'),
//                         ],
//                       ),
//                     ),
//                     PopupMenuItem(
//                       value: 1,
//                       child: Row(
//                         children: const [
//                           Icon(Icons.delete_rounded),
//                           const SizedBox(width: 10.0),
//                           Text('Delete'),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//                 onTap: () {
//                   Navigator.of(context).push(
//                     PageRouteBuilder(
//                       opaque: false, // set to false
//                       pageBuilder: (_, __, ___) => PlayScreen(
//                         data: {
//                           'response': _cachedVideos,
//                           'index': index,
//                           'offline': true
//                         },
//                         fromMiniplayer: false,
//                       ),
//                     ),
//                   );
//                 },
//               );
//             });
//   }
}

class SongsTab extends StatefulWidget {
  final List<SongModel> songs;
  final int? playlistId;
  final String? playlistName;
  final String tempPath;
  const SongsTab({
    super.key,
    required this.songs,
    required this.tempPath,
    this.playlistId,
    this.playlistName,
  });

  @override
  State<SongsTab> createState() => _SongsTabState();
}

class _SongsTabState extends State<SongsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ScrollController _scrollController = ScrollController();
  final Set<int> _selectedAudioIds = {};
  bool get _isSelectionMode => _selectedAudioIds.isNotEmpty;

  @override
  void dispose() {
    super.dispose();
    _scrollController.dispose();
  }

  Widget _buildSelectionToolbar(BuildContext context) {
    final allSelected = _selectedAudioIds.length == widget.songs.length;
    return Container(
      color: Theme.of(context).cardColor.withOpacity(0.9),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Clear Selection',
            onPressed: () {
              setState(() {
                _selectedAudioIds.clear();
              });
            },
          ),
          const SizedBox(width: 8),
          Text(
            '${_selectedAudioIds.length} Selected',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                if (allSelected) {
                  _selectedAudioIds.clear();
                } else {
                  _selectedAudioIds.addAll(widget.songs.map((s) => s.id));
                }
              });
            },
            child: Text(allSelected ? 'Clear' : 'Select All'),
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add_rounded),
            tooltip: 'Add to Playlist',
            onPressed: () {
              AddToOffPlaylist().addMultipleToOffPlaylist(
                context,
                _selectedAudioIds.toList(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded),
            tooltip: 'Delete Selected',
            onPressed: () async {
              final selectedSongs = widget.songs
                  .where((s) => _selectedAudioIds.contains(s.id))
                  .toList();
              final itemsToDelete = selectedSongs.map((s) => {
                'id': s.id.toString(),
                'title': s.title.trim().isNotEmpty
                    ? s.title
                    : s.displayNameWOExt,
                'path': s.data,
              }).toList();
              final result = await SongDeleteHelper.deleteBulkSongs(
                context: context,
                itemsToDelete: itemsToDelete,
                fromDownloads: false,
              );
              if (result.removedIds.isNotEmpty) {
                setState(() {
                  final removedSet = result.removedIds.toSet();
                  widget.songs.removeWhere(
                    (s) => removedSet.contains(s.id.toString()),
                  );
                  _selectedAudioIds.clear();
                });
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.songs.isEmpty
        ? emptyScreen(
            context,
            3,
            AppLocalizations.of(context)!.nothingTo,
            15.0,
            AppLocalizations.of(context)!.showHere,
            45,
            AppLocalizations.of(context)!.downloadSomething,
            23.0,
          )
        : Column(
            children: [
              if (_isSelectionMode)
                _buildSelectionToolbar(context)
              else
                PlaylistHead(
                  songsList: widget.songs,
                  offline: true,
                  fromDownloads: false,
                ),
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thickness: 8,
                  thumbVisibility: true,
                  radius: const Radius.circular(10),
                  interactive: true,
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 10),
                    controller: _scrollController,
                    shrinkWrap: true,
                    itemExtent: 70.0,
                    itemCount: widget.songs.length,
                    itemBuilder: (context, index) {
                      final isSelected =
                          _selectedAudioIds.contains(widget.songs[index].id);
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: Theme.of(context)
                            .colorScheme
                            .secondary
                            .withOpacity(0.15),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isSelectionMode)
                              Checkbox(
                                value: isSelected,
                                activeColor:
                                    Theme.of(context).colorScheme.secondary,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedAudioIds
                                          .add(widget.songs[index].id);
                                    } else {
                                      _selectedAudioIds
                                          .remove(widget.songs[index].id);
                                    }
                                  });
                                },
                              ),
                            OfflineAudioQuery.offlineArtworkWidget(
                              id: widget.songs[index].id,
                              type: ArtworkType.AUDIO,
                              tempPath: widget.tempPath,
                              fileName: widget.songs[index].displayNameWOExt,
                            ),
                          ],
                        ),
                        title: Text(
                          widget.songs[index].title.trim() != ''
                              ? widget.songs[index].title
                              : widget.songs[index].displayNameWOExt,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${widget.songs[index].artist?.replaceAll('<unknown>', 'Unknown') ?? AppLocalizations.of(context)!.unknown} - ${widget.songs[index].album?.replaceAll('<unknown>', 'Unknown') ?? AppLocalizations.of(context)!.unknown}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: _isSelectionMode
                            ? null
                            : PopupMenuButton(
                                icon: const Icon(Icons.more_vert_rounded),
                                shape: const RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(15.0)),
                                ),
                                onSelected: (int? value) async {
                                  if (value == 0) {
                                    AddToOffPlaylist().addToOffPlaylist(
                                      context,
                                      widget.songs[index].id,
                                    );
                                  }
                                  if (value == 1) {
                                    await OfflineAudioQuery().removeFromPlaylist(
                                      playlistId: widget.playlistId!,
                                      audioId: widget.songs[index].id,
                                    );
                                    ShowSnackBar().showSnackBar(
                                      context,
                                      '${AppLocalizations.of(context)!.removedFrom} ${widget.playlistName}',
                                    );
                                  }
                                  if (value == 2) {
                                    setState(() {
                                      _selectedAudioIds
                                          .add(widget.songs[index].id);
                                    });
                                  }
                                  if (value == 3) {
                                    final outcome =
                                        await SongDeleteHelper.deleteSingleSong(
                                      context: context,
                                      id: widget.songs[index].id.toString(),
                                      title: widget.songs[index].title.trim() != ''
                                          ? widget.songs[index].title
                                          : widget.songs[index].displayNameWOExt,
                                      filePath: widget.songs[index].data,
                                      fromDownloads: false,
                                    );
                                    if (outcome == DeleteOutcome.fileDeleted ||
                                        outcome ==
                                            DeleteOutcome.staleRecordRemoved) {
                                      setState(() {
                                        widget.songs.removeAt(index);
                                      });
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 0,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.playlist_add_rounded),
                                        const SizedBox(width: 10.0),
                                        Text(
                                          AppLocalizations.of(context)!
                                              .addToPlaylist,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (widget.playlistId != null)
                                    PopupMenuItem(
                                      value: 1,
                                      child: Row(
                                        children: [
                                          const Icon(Icons.delete_rounded),
                                          const SizedBox(width: 10.0),
                                          Text(
                                            AppLocalizations.of(context)!.remove,
                                          ),
                                        ],
                                      ),
                                    ),
                                  PopupMenuItem(
                                    value: 2,
                                    child: Row(
                                      children: const [
                                        Icon(Icons.check_box_outlined),
                                        SizedBox(width: 10.0),
                                        Text('Select'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 3,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.delete_rounded),
                                        const SizedBox(width: 10.0),
                                        Text(
                                          AppLocalizations.of(context)!.delete,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                        onTap: () {
                          if (_isSelectionMode) {
                            setState(() {
                              if (isSelected) {
                                _selectedAudioIds
                                    .remove(widget.songs[index].id);
                              } else {
                                _selectedAudioIds
                                    .add(widget.songs[index].id);
                              }
                            });
                          } else {
                            PlayerInvoke.init(
                              songsList: widget.songs,
                              index: index,
                              isOffline: true,
                              recommend: false,
                            );
                          }
                        },
                        onLongPress: () {
                          setState(() {
                            if (isSelected) {
                              _selectedAudioIds
                                  .remove(widget.songs[index].id);
                            } else {
                              _selectedAudioIds
                                  .add(widget.songs[index].id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
  }
}


class AlbumsTab extends StatefulWidget {
  final Map<String, List<SongModel>> albums;
  final List<String> albumsList;
  final String tempPath;
  const AlbumsTab({
    super.key,
    required this.albums,
    required this.albumsList,
    required this.tempPath,
  });

  @override
  State<AlbumsTab> createState() => _AlbumsTabState();
}

class _AlbumsTabState extends State<AlbumsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    super.dispose();
    _scrollController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.albumsList.isEmpty
        ? emptyScreen(
            context,
            3,
            AppLocalizations.of(context)!.nothingTo,
            15.0,
            AppLocalizations.of(context)!.showHere,
            45,
            AppLocalizations.of(context)!.downloadSomething,
            23.0,
          )
        : Scrollbar(
            controller: _scrollController,
            thickness: 8,
            thumbVisibility: true,
            radius: const Radius.circular(10),
            interactive: true,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(top: 20, bottom: 10),
              controller: _scrollController,
              shrinkWrap: true,
              itemExtent: 70.0,
              itemCount: widget.albumsList.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: OfflineAudioQuery.offlineArtworkWidget(
                    id: widget.albums[widget.albumsList[index]]![0].id,
                    type: ArtworkType.AUDIO,
                    tempPath: widget.tempPath,
                    fileName: widget
                        .albums[widget.albumsList[index]]![0].displayNameWOExt,
                  ),
                  title: Text(
                    widget.albumsList[index],
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${widget.albums[widget.albumsList[index]]!.length} ${AppLocalizations.of(context)!.songs}',
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DownloadedSongs(
                          title: widget.albumsList[index],
                          cachedSongs: widget.albums[widget.albumsList[index]],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
  }
}
