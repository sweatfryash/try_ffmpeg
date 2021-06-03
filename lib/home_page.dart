import 'dart:io';
import 'package:flutter_ffmpeg/media_information.dart';
import 'package:flutter_ffmpeg/statistics.dart';
import 'package:flutter_ffmpeg/stream_information.dart';
import 'package:open_file/open_file.dart';
import 'package:try_ffmpeg/editable_process_bar.dart';
import 'package:video_player/video_player.dart';
import 'extensions/size_extension.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:try_ffmpeg/settings_page.dart';
import 'package:try_ffmpeg/video_info_page.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

enum MySheet { cut, setting, none }

const Duration _bottomSheetEnterDuration = Duration(milliseconds: 250);
const Duration _bottomSheetExitDuration = Duration(milliseconds: 200);
const double minExportDurationInSecond = 1; // 秒
const String _targetDir = '/storage/emulated/0/Pictures/ToGif/';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ValueNotifier<bool> _isEditing = ValueNotifier<bool>(false);
  List<AssetEntity> _assets = <AssetEntity>[]; //
  final GlobalKey<ScaffoldState> _scaffold = GlobalKey<ScaffoldState>();
  //FFmpeg相关
  final FlutterFFmpeg _ffmpeg = FlutterFFmpeg();
  final FlutterFFprobe _ffprobe = FlutterFFprobe();
  final FlutterFFmpegConfig _ffmpegConfig = FlutterFFmpegConfig();

  final ValueNotifier<double> _fps = ValueNotifier<double>(15.0);
  final ValueNotifier<double> _videoSizeScale = ValueNotifier<double>(0.7);
  Size _exportFileSize = Size.zero;

  final ValueNotifier<double> _executeProgress = ValueNotifier<double>(0.0);
  String _exportFileName;
  final ValueNotifier<MySheet> _bottomSheet = ValueNotifier(MySheet.none);
  VideoPlayerController _playerController;
  final ValueNotifier<RangeValues> _exportRange =
      ValueNotifier(RangeValues(0, 0));
  double get _exportDuration =>
      _exportRange.value.end - _exportRange.value.start; // 秒
  Duration get _startPosition =>
      Duration(milliseconds: (_exportRange.value.start * 1000).toInt());
  Duration get _endPosition =>
      Duration(milliseconds: (_exportRange.value.end * 1000).toInt());
  double _minExportDuration;
  double _videoDuration;
  Size _sliderThumbSize = Size(18, 45);
  List<String> _frames = <String>[];
  bool _isNewerVideo = false;
  bool _isNeedStatistic = false;
  @override
  void initState() {
    //_ffmpegConfig.disableLogs();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _ffmpegConfig.enableStatisticsCallback(_statisticsCallback);
    });
    super.initState();
  }

  @override
  void dispose() {
    _playerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          bottom: 50,
          left: 0,
          right: 0,
          top: 0,
          child: Scaffold(
            key: _scaffold,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: _title(),
              actions: <Widget>[_infoButton(), _menuButton()],
              elevation: 0,
            ),
            body: ValueListenableBuilder(
              valueListenable: _isEditing,
              builder: (BuildContext context, bool value, Widget child) {
                if (value) {
                  return _editingBody(context);
                }
                return _addImageButton();
              },
            ),
          ),
        ),
        ValueListenableBuilder(
            valueListenable: _isEditing,
            builder: (BuildContext context, bool value, Widget child) {
              return value
                  ? Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _bottomBar(),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: 50,
                          color: Theme.of(context).scaffoldBackgroundColor,
                        )
                      ],
                    );
            })
      ],
    );
  }

  Widget _playButton() {
    return ValueListenableBuilder(
      valueListenable: _playerController,
      builder: (BuildContext context, VideoPlayerValue value, Widget child) {
        return FloatingActionButton(
          backgroundColor: Colors.white30,
          onPressed: _onPlayButtonPressed,
          child: Icon(
            _playerController.value.isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
          ),
        );
      },
    );
  }

  Widget _title() {
    return InkWell(
      child: Container(
        padding: EdgeInsets.all(6),
        child: Text(
          '打开',
          style: TextStyle(fontSize: 16),
        ),
      ),
      onTap: () {
        if (_assets.isEmpty) {
          _selectVideo();
        } else {
          showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('舍弃已打开的视频吗？'),
                  actions: <Widget>[
                    TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text('取消')),
                    TextButton(
                        onPressed: () {
                          _isEditing.value = false;
                          _assets.clear();
                          _frames.clear();
                          Navigator.pop(context);
                          _selectVideo();
                        },
                        child: Text('确定')),
                  ],
                );
              });
        }
      },
    );
  }

  Widget _editingBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Spacer(),
              Flexible(
                flex: 18,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: AspectRatio(
                    aspectRatio: _exportFileSize.aspectRatio,
                    child: Stack(
                      children: [
                        VideoPlayer(_playerController),
                        Positioned(right: 5, bottom: 5, child: _playButton()),
                      ],
                    ),
                  ),
                ),
              ),
              Spacer(),
            ],
          ),
        ),
        ValueListenableBuilder(
          valueListenable: _bottomSheet,
          builder: (BuildContext context, MySheet value, Widget child) {
            switch (value) {
              case MySheet.none:
                return Container();
              case MySheet.cut:
                return _cutSheet(context);
              case MySheet.setting:
                return _settingsSheet(context);
              default:
                return null;
            }
          },
        ),
      ],
    );
  }

  Widget _bottomBar() {
    return Card(
        margin: EdgeInsets.all(0),
        shape: ContinuousRectangleBorder(),
        child: Container(
          height: 50,
          child: Row(
            children: <Widget>[
              Expanded(
                child: InkWell(
                  child: Center(child: Text('剪切')),
                  onTap: () {
                    if (_bottomSheet.value == MySheet.cut) {
                      _bottomSheet.value = MySheet.none;
                    } else {
                      _bottomSheet.value = MySheet.cut;
                    }
                  },
                ),
              ),
              Expanded(
                child: InkWell(
                  child: Center(
                    child: Text('配置'),
                  ),
                  onTap: () {
                    if (_bottomSheet.value == MySheet.setting) {
                      _bottomSheet.value = MySheet.none;
                    } else {
                      _bottomSheet.value = MySheet.setting;
                    }
                  },
                ),
              ),
              Expanded(
                child: InkWell(
                  child: Center(
                    child: Text('导出'),
                  ),
                  onTap: _onExportButtonTap,
                ),
              ),
            ],
          ),
        ));
  }

  Widget _addImageButton() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.video_collection_rounded),
            iconSize: 99,
            color: Colors.grey,
            onPressed: () {
              _selectVideo();
            },
          ),
          Text('选择视频以开始')
        ],
      ),
    );
  }

  Future<void> _selectVideo() async {
    List<AssetEntity> assets = await AssetPicker.pickAssets(context,
        maxAssets: 1, requestType: RequestType.video);
    if (assets != null) {
      _assets = assets;
      AssetEntity asset = _assets[0];
      MediaInformation info = await _ffprobe
          .getMediaInformation("${asset.relativePath}/${asset.title}");
      double duration =
          double.parse(info.getMediaProperties()['duration'].toString());
      _exportRange.value = RangeValues(0, duration);
      _minExportDuration = duration < minExportDurationInSecond
          ? duration
          : minExportDurationInSecond;
      _videoDuration = duration;
      if (info.getStreams() != null) {
        List<StreamInformation> streams = info.getStreams();
        if (streams.length > 0) {
          StreamInformation firstStream = streams[0];
          int streamWidth = firstStream.getAllProperties()['width'];
          int streamHeight = firstStream.getAllProperties()['height'];
          //print("Bitrate: ${firstStream.getAllProperties()['bit_rate']}");
          if (streamWidth == null || streamHeight == null) {
            _exportFileSize = asset.size;
          } else {
            Map<dynamic, dynamic> tags = firstStream.getAllProperties()['tags'];
            if (tags.containsKey('rotate')) {
              //TODO(hch): 根据rotate做出正确的处理
              int rotate = int.parse(tags['rotate']);
              print('旋转 rotate： $rotate');
              _exportFileSize =
                  Size(streamHeight.toDouble(), streamWidth.toDouble());
            } else {
              _exportFileSize =
                  Size(streamWidth.toDouble(), streamHeight.toDouble());
            }
          }
          _playerController = VideoPlayerController.file(await asset.file);
          await _playerController.initialize();
          _playerController.addListener(_playerListener);
          _isEditing.value = true;
          WidgetsBinding.instance.addPostFrameCallback(_afterSelectVideo);
        }
      }
    }
  }

  void _afterSelectVideo(Duration timeStamp) {
    _isNewerVideo = true;
    _bottomSheet.value = MySheet.cut;
  }

  Widget _cutSheet(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(0),
      shape: ContinuousRectangleBorder(),
      child: Column(
        children: [
          ValueListenableBuilder(
            valueListenable: _exportRange,
            builder:
                (BuildContext context, RangeValues rangeValue, Widget child) {
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 25),
                child: EditableProcessBar(
                  values: rangeValue,
                  onChanged: _onRangeChanged,
                  max: _videoDuration,
                  thumbSize: _sliderThumbSize,
                  frames: _frames,
                  onVideoChanged: _onVideoChanged,
                ),
              );
            },
          ),
          const Divider(height: 1)
        ],
      ),
    );
  }

  void _onVideoChanged(double width) {
    if (_isNewerVideo) {
      double previewWidth =
          (_sliderThumbSize.height - 4) * _exportFileSize.aspectRatio;
      int framesCount = (width / previewWidth).round();
      _getVideoFrames(framesCount);
      _isNewerVideo = false;
    }
  }

  Future<void> _getVideoFrames(int count) async {
    Directory temp = Directory('${_targetDir}temp/');
    if (temp.existsSync()) {
      await temp.delete(recursive: true);
    }
    temp.createSync(recursive: true);
    AssetEntity asset = _assets[0];
    String time = DateTime.now().millisecondsSinceEpoch.toString();
    _isNeedStatistic = false;
    _ffmpeg
        .execute('-i ${asset.relativePath}/${asset.title}'
            ' -s ${(_exportFileSize * 0.2).toFixedString()}'
            ' -vf "fps = 1/${(_videoDuration / count)}"'
            ' ${_targetDir}temp/\%d$time.jpg')
        .then((value) {
      for (int i = 1; i <= count; i++) {
        File file = File('${_targetDir}temp/$i$time.jpg');
        if (file.existsSync()) {
          _frames.add('${_targetDir}temp/$i$time.jpg');
          setState(() {});
        }
      }
    });
  }

  Widget _settingsSheet(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(0),
      shape: ContinuousRectangleBorder(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(height: 10),
          ListTile(
            leading: ValueListenableBuilder(
              valueListenable: _videoSizeScale,
              builder: (BuildContext context, double value, Widget child) {
                return Container(
                    width: 75,
                    child: Text((_exportFileSize * value).toFixedString()));
              },
            ),
            title: ValueListenableBuilder(
              valueListenable: _videoSizeScale,
              builder: (BuildContext context, double value, Widget child) {
                return Slider(
                  value: value,
                  min: 0.05,
                  divisions: 15,
                  label: (_exportFileSize * value).toFixedString(),
                  onChanged: (value) {
                    _videoSizeScale.value = value;
                  },
                );
              },
            ),
          ),
          ListTile(
            leading: Container(
              width: 75,
              child: ValueListenableBuilder(
                valueListenable: _fps,
                builder: (BuildContext context, double value, Widget child) {
                  return Text('${value.round().toString()}帧/秒');
                },
              ),
            ),
            title: ValueListenableBuilder(
              valueListenable: _fps,
              builder: (BuildContext context, double value, Widget child) {
                return Slider(
                  value: value,
                  min: 1,
                  max: 60,
                  divisions: 59,
                  label: value.round().toString(),
                  onChanged: (double value) {
                    _fps.value = value;
                  },
                );
              },
            ),
          ),
          const Divider(height: 1)
        ],
      ),
    );
  }

  Widget _menuButton() {
    return PopupMenuButton(
      padding: EdgeInsets.all(0),
      itemBuilder: (BuildContext context) {
        return <PopupMenuItem<Widget>>[
          PopupMenuItem<Widget>(value: SettingsPage(), child: Text('设置')),
          PopupMenuItem<Widget>(child: Text('帮助')),
        ];
      },
      onSelected: (widget) {
        Navigator.push(context,
            MaterialPageRoute(builder: (BuildContext context) => widget));
      },
    );
  }

  Widget _infoButton() {
    return ValueListenableBuilder(
      builder: (BuildContext context, bool value, Widget child) {
        return IconButton(
          icon: Icon(Icons.info),
          onPressed: value ? _openInfoPage : null,
        );
      },
      valueListenable: _isEditing,
    );
  }

  Future<void> _openInfoPage() async {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (BuildContext context) => VideoInfoPage(
            asset: _assets[0],
          ),
        ));
  }

  void _onExportButtonTap() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.file_copy_outlined),
              title: Text('路径:$_targetDir'),
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.gif),
              title: Text('导出'),
              subtitle: Text('按照配置参数导出到路径下'),
              onTap: _exeExport,
            )
          ],
        );
      },
    );
  }

  Future<void> _exeExport() async {
    AssetEntity asset = _assets[0];
    if (!Directory(_targetDir).existsSync()) {
      Directory(_targetDir).createSync();
    }
    _ffmpegConfig.resetStatistics(); //清除上次执行的数据
    _executeProgress.value = 0; //清除进度
    Navigator.pop(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: _exeProgressDialog,
    );
    _exportFileName = 'ToGif-${DateTime.now().millisecondsSinceEpoch}.gif';
    _isNeedStatistic = true;
    _ffmpeg.execute('-ss ${_exportRange.value.start} '
        '-t $_exportDuration '
        '-i ${asset.relativePath}/${asset.title} '
        '-s ${(_exportFileSize * _videoSizeScale.value).toFixedString()} '
        '-b 1000k -minrate 1000k -maxrate 1000k -bufsize 1835k '
        '$_targetDir$_exportFileName');
  }

  Widget _exeProgressDialog(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _executeProgress,
      builder: (BuildContext context, double value, Widget child) {
        return SimpleDialog(
          contentPadding: EdgeInsets.all(10),
          children: [
            ListTile(
              leading: CircularProgressIndicator(
                value: value,
              ),
              title: Text((value * 100).toStringAsFixed(1) + '%'),
            )
          ],
        );
      },
    );
  }

  void _statisticsCallback(Statistics statistics) {
    if (_isNeedStatistic && statistics != null) {
      double progress = statistics.time / (_exportDuration * 1000);
      if (progress >= 0.995) {
        progress = 1.0;
        Navigator.pop(context);
        _scaffold.currentState.showSnackBar(_afterExportSnackBar());
      }
      _executeProgress.value = progress;
    }
  }

  Widget _afterExportSnackBar() {
    return SnackBar(
      content: Text('导出成功'),
      action: SnackBarAction(
        label: '查看',
        onPressed: () {
          OpenFile.open('$_targetDir$_exportFileName');
        },
      ),
    );
  }

  void _onRangeChanged(RangeValues values) {
    _playerController.pause();
    if (values.end - values.start >= _minExportDuration) {
      _playerController.seekTo(values.start != _exportRange.value.start
          ? Duration(milliseconds: (values.start * 1000).toInt())
          : Duration(milliseconds: (values.end * 1000).toInt()));
      _exportRange.value = values;
    }
  }

  //暂停||播放按钮
  Future<void> _onPlayButtonPressed() async {
    if (_playerController.value.isPlaying) {
      _playerController.pause();
    } else {
      if (_playerController.value.position >= _endPosition) {
        await _playerController.seekTo(_startPosition);
        _playerController.play();
      } else {
        _playerController.play();
      }
    }
  }

  void _playerListener() {
    if (_playerController.value.isPlaying &&
        _playerController.value.position >= _endPosition) {
      _playerController.pause();
    }
  }
}
