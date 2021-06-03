import 'dart:io';
import 'extensions/size_extension.dart';
import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

class VideoInfoPage extends StatefulWidget {
  const VideoInfoPage({Key key, @required this.asset}) : super(key: key);

  final AssetEntity asset;

  @override
  _VideoInfoPageState createState() => _VideoInfoPageState();
}

class _VideoInfoPageState extends State<VideoInfoPage> {
  String get dateTime => widget.asset.createDateTime.toString().split('.')[0];
  get _video => File(widget.asset.relativePath + '/' + widget.asset.title);
  get _videoMBSize => (_video.lengthSync() / 1024 / 1024).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('源视频信息'),
      ),
      body: ListView(
        children: <Widget>[
          SizedBox(height: 10),
          ListTile(
            leading: Icon(Icons.file_copy_outlined),
            title: Text('${widget.asset.title}'),
            subtitle: Text(widget.asset.relativePath),
          ),
          ListTile(
            leading: Icon(Icons.calendar_today),
            title: Text(dateTime),
          ),
          ListTile(
            leading: Icon(Icons.video_settings),
            title: Text('${widget.asset.duration}秒     '
                '${widget.asset.size.toFixedString()}'
                '     ${_videoMBSize.toString()}MB'),
          ),
        ],
      ),
    );
  }
}
