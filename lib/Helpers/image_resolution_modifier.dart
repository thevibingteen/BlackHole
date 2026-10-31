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

String getImageUrl(String? imageUrl, {String quality = 'high'}) {
  if (imageUrl == null) return '';
  String url = imageUrl.trim();
  if (url.isEmpty) return '';
  if (url.startsWith('//')) {
    url = 'https:$url';
  } else if (url.startsWith('http:')) {
    url = url.replaceFirst('http:', 'https:');
  }

  // Handle YouTube / Google CDN images (e.g. lh3.googleusercontent.com, yt3.ggpht.com)
  if (url.contains('googleusercontent.com') || url.contains('ggpht.com')) {
    switch (quality) {
      case 'high':
        url = url
            .replaceAll(RegExp(r'=w\d+-h\d+'), '=w544-h544')
            .replaceAll(RegExp(r'=s\d+'), '=s544');
        break;
      case 'medium':
        url = url
            .replaceAll(RegExp(r'=w\d+-h\d+'), '=w226-h226')
            .replaceAll(RegExp(r'=s\d+'), '=s226');
        break;
      case 'low':
        url = url
            .replaceAll(RegExp(r'=w\d+-h\d+'), '=w120-h120')
            .replaceAll(RegExp(r'=s\d+'), '=s120');
        break;
      default:
        url = url
            .replaceAll(RegExp(r'=w\d+-h\d+'), '=w544-h544')
            .replaceAll(RegExp(r'=s\d+'), '=s544');
    }
  }

  // Handle YouTube standard video thumbnails (i.ytimg.com / img.youtube.com)
  if (url.contains('ytimg.com') || url.contains('youtube.com')) {
    switch (quality) {
      case 'high':
        url = url
            .replaceAll('/default.jpg', '/hqdefault.jpg')
            .replaceAll('/mqdefault.jpg', '/hqdefault.jpg');
        break;
      case 'medium':
        url = url
            .replaceAll('/default.jpg', '/mqdefault.jpg')
            .replaceAll('/hqdefault.jpg', '/mqdefault.jpg')
            .replaceAll('/maxresdefault.jpg', '/mqdefault.jpg');
        break;
      case 'low':
        url = url
            .replaceAll('/hqdefault.jpg', '/default.jpg')
            .replaceAll('/mqdefault.jpg', '/default.jpg')
            .replaceAll('/maxresdefault.jpg', '/default.jpg');
        break;
      default:
        url = url
            .replaceAll('/default.jpg', '/hqdefault.jpg')
            .replaceAll('/mqdefault.jpg', '/hqdefault.jpg');
    }
  }

  // Handle JioSaavn and generic dimensions (e.g. 50x50, 150x150, 500x500)
  switch (quality) {
    case 'high':
      return url
          .replaceAll('50x50', '500x500')
          .replaceAll('150x150', '500x500');
    case 'medium':
      return url
          .replaceAll('50x50', '150x150')
          .replaceAll('500x500', '150x150');
    case 'low':
      return url
          .replaceAll('150x150', '50x50')
          .replaceAll('500x500', '50x50');
    default:
      return url
          .replaceAll('50x50', '500x500')
          .replaceAll('150x150', '500x500');
  }
}

