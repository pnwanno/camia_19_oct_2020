import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_xlider/flutter_xlider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:path_provider/path_provider.dart';

import './theme_data.dart' as pageTheme;
import '../globals.dart' as globals;

class AddVideo extends StatefulWidget{
  _AddVideo createState(){
    return _AddVideo();
  }

  final String channelID;
  AddVideo(this.channelID);
}

class _AddVideo extends State<AddVideo>{

  @override
  initState(){
    super.initState();
    initDir();
  }//route's init state

  Stream _globalStream;
  Directory _appDir;
  initDir()async{
    if(_appDir == null){
      _appDir=await getApplicationDocumentsDirectory();
    }

    if(_globalStream == null){
      _globalStream=globals.globalTVPostCtr.stream;
      _globalStream.listen((event) {
        if(globals.tvPostData["status"] == "passive"){
          _showToast=false;
          _toastCtr.add("kjut");
        }
        else{
          _showToast=true;
          _toastText=globals.tvPostData["title"];
          _toastCtr.add("kjut");
        }
      });
      if(globals.tvPostData["status"] == "active"){
        _showToast=true;
        _toastText=globals.tvPostData["title"];
        _toastCtr.add("kjut");
      }
    }
  }//do basic initialization here

  File _selectedVid;
  List<VideoPlayerController> _vplayer= List<VideoPlayerController>();
  double _vidAR;
  StreamController _selectionChangeNotifier= StreamController.broadcast();

  double _playIconOpacity=0;
  StreamController _playIconOpacitCtr= StreamController.broadcast();

  RangeValues _selectedPortion=RangeValues(0, 100);
  RangeValues _videoRange=RangeValues(0, 100);
  bool _cutVideo=false;
  StreamController _cutVideoCtr= StreamController.broadcast();

  bool _cutWallVideo=false;
  StreamController _cutWallVideoCtr= StreamController.broadcast();
  RangeValues _wallRange=RangeValues(0, 15);

  bool _customPoster=false;
  StreamController _customPosterCtr= StreamController.broadcast();
  int _posterFrame= 0;

  bool _playRange=false;
  RangeValues _playRangeVals= RangeValues(0, 100);

  String _deviceTheme;
  int _curPlayerPos=0;
  BuildContext _pageContext;
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext= context;
    _screenSize=MediaQuery.of(_pageContext).size;
    _toastTop=_screenSize.height * .6;
    return WillPopScope(
      child: Scaffold(
        backgroundColor: pageTheme.bgColor,
        body: FocusScope(
          child: Container(
            child: Stack(
              children: [
                Container(
                  width: _screenSize.width,
                  height: _screenSize.height,
                  padding: EdgeInsets.only(bottom: 32),
                  child: ListView(
                    physics: BouncingScrollPhysics(),
                    children: [
                      StreamBuilder(
                        stream:_selectionChangeNotifier.stream,
                        builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                          return Container(
                            child: Container(
                              decoration: BoxDecoration(
                                  color: Color.fromRGBO(28, 28, 28, 1)
                              ),
                              width: _screenSize.width, height: _screenSize.height * .4,
                              alignment: Alignment.center,
                              child: _vplayer.length==0 ? Container(
                                alignment: Alignment.center,
                                height:_screenSize.height * .4,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    highlightColor: Colors.transparent,
                                    onTap:(){
                                      pickVideo();
                                    },
                                    child: Ink(
                                      width:_screenSize.width,height:_screenSize.height * .4,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            FlutterIcons.file_video_mco,
                                            color: Color.fromRGBO(62, 62, 62, 1),
                                            size: 120,
                                          ),
                                          Container(
                                            child: Text(
                                              "Select a video file",
                                              style: TextStyle(
                                                  color: Colors.grey
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ): Container(
                                child: Stack(
                                  children: [
                                    Container(
                                      alignment: Alignment.center,
                                      child: AspectRatio(
                                        aspectRatio: _vidAR,
                                        child: VideoPlayer(
                                            _vplayer.last
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: Container(
                                        alignment: Alignment.center,
                                        child: Material(
                                          color: Colors.transparent,
                                          child: StreamBuilder(
                                            stream: _playIconOpacitCtr.stream,
                                            builder: (BuildContext _ctx, AsyncSnapshot _playIconShot){
                                              return GestureDetector(
                                                onTapDown: (_){
                                                  _playIconOpacity=1;
                                                  _playIconOpacitCtr.add("kjut");
                                                },
                                                child: Container(
                                                  width: _screenSize.width,
                                                  height: double.infinity,
                                                  child: AnimatedOpacity(
                                                    opacity: _playIconOpacity,
                                                    duration: Duration(milliseconds: 300),
                                                    onEnd: (){
                                                      if(_playIconOpacity == 1){
                                                        Future.delayed(
                                                            Duration(milliseconds: 1500),
                                                                (){
                                                              _playIconOpacity=0;
                                                              _playIconOpacitCtr.add("kjut");
                                                            }
                                                        );
                                                      }
                                                    },
                                                    child: InkWell(
                                                      onTap: (){
                                                        VideoPlayerController _focplayer= _vplayer.last;
                                                        _playRange=false;
                                                        if(_focplayer.value.isPlaying){
                                                          _focplayer.pause();
                                                          _playIconOpacitCtr.add("kjut");
                                                        }
                                                        else{
                                                          _focplayer.play();
                                                          _playIconOpacitCtr.add("kjut");
                                                        }
                                                      },
                                                      child: Ink(
                                                        child: Icon(
                                                          _vplayer.last.value.isPlaying ? FlutterIcons.pause_faw : FlutterIcons.play_faw,
                                                          color: Colors.grey,
                                                          size: 48,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 32, left: 32,
                                      width: _screenSize.width - 64,
                                      child: Container(
                                        child: StreamBuilder(
                                          stream: _playerPosChangeNotifier.stream,
                                          builder: (BuildContext _ctx, AsyncSnapshot _tlineshot){
                                            return FlutterSlider(
                                              values: [_curPlayerPos/1],
                                              min: 0,
                                              max: _vplayer.last.value.duration.inSeconds/1,
                                              onDragCompleted: (int _targHandler, _lowerVal, _upperVal){
                                                if(_targHandler ==  1){
                                                  double _lowerValu=_lowerVal;
                                                  _vplayer.last.seekTo(Duration(seconds: _lowerValu.toInt()));
                                                }
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ), //selected video player

                      Container(
                        padding: EdgeInsets.only(left: 16, right: 16, top: 9, bottom: 9),
                        decoration: BoxDecoration(
                        ),
                        child: Row(
                          children: [
                            Container(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey,
                                  borderRadius: BorderRadius.circular(32),
                                ),
                                padding: EdgeInsets.all(7),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: (){
                                      pickVideo();
                                    },
                                    child: Ink(
                                      child: Icon(
                                        FlutterIcons.file_video_mco,
                                        color: Color.fromRGBO(110, 110, 110, 1)
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                margin: EdgeInsets.only(left: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    StreamBuilder(
                                      stream: _cutVideoCtr.stream,
                                      builder: (BuildContext _ctx, AsyncSnapshot _cutVidShot){
                                        return Container(
                                          child: CheckboxListTile(
                                            title: Text(
                                              "Select a video portion (optional)",
                                              style: TextStyle(
                                                color: pageTheme.fontColor,
                                                fontSize: 12,
                                              ),
                                              textAlign: TextAlign.left,
                                            ),
                                            onChanged: (bool _curVal){
                                              _cutVideo= !_cutVideo;
                                              _cutVideoCtr.add("kjut");
                                            },
                                            contentPadding: EdgeInsets.only(left: 0, bottom: 0),
                                            controlAffinity: ListTileControlAffinity.leading,
                                            value: _cutVideo,
                                            subtitle: Text(
                                              "Not selecting means full length will be used",
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: pageTheme.fontColor
                                              ),
                                            ),
                                            secondary: StreamBuilder(
                                              stream: _playIconOpacitCtr.stream,
                                              builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                                return Material(
                                                  color: Colors.transparent,
                                                  child: Container(
                                                    child: InkWell(
                                                      onTap: (){
                                                        if(_vplayer.length>0 && _cutVideo){
                                                          _playRange=true;
                                                          _playRangeVals=_selectedPortion;
                                                          VideoPlayerController _focPlayer=_vplayer.last;
                                                          if(_focPlayer.value.isPlaying){
                                                            _focPlayer.pause();
                                                          }
                                                          else{
                                                            _focPlayer.play();
                                                          }
                                                          _playIconOpacitCtr.add("kjut");
                                                        }
                                                      },
                                                      child: Ink(
                                                        child: Icon(
                                                            (_vplayer.length>0 && _vplayer.last.value.isPlaying) ? FlutterIcons.pause_faw : FlutterIcons.play_faw,
                                                          color: pageTheme.profileIcons,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                    ),//label
                                    Container(
                                      child: StreamBuilder(
                                        stream: _selectionChangeNotifier.stream,
                                        builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                          return FlutterSlider(
                                            rangeSlider: true,
                                            tooltip: FlutterSliderTooltip(
                                              boxStyle: FlutterSliderTooltipBox(
                                                decoration: BoxDecoration(
                                                  color: pageTheme.bgColor
                                                )
                                              ),
                                              textStyle: TextStyle(
                                                color: pageTheme.fontColor
                                              ),
                                              leftSuffix: Text(
                                                " S",
                                                style: TextStyle(
                                                  color: pageTheme.fontColor
                                                ),
                                              ),
                                                rightSuffix: Text(
                                                  " S",
                                                  style: TextStyle(
                                                      color: pageTheme.fontColor
                                                  ),
                                                )
                                            ),
                                            values: [_selectedPortion.start, _selectedPortion.end],
                                            min: 0, max: _videoRange.end,
                                            hatchMark: FlutterSliderHatchMark(
                                              density: .5,
                                                linesDistanceFromTrackBar: -32,
                                              displayLines: true,
                                              linesAlignment: FlutterSliderHatchMarkAlignment.left,
                                              smallLine: FlutterSliderSizedBox(
                                                width: 1, height: 16,
                                                decoration: BoxDecoration(
                                                  color: pageTheme.fontColor
                                                )
                                              ),
                                              bigLine: FlutterSliderSizedBox(
                                                width: 2, height: 10,
                                                decoration: BoxDecoration(
                                                  color: pageTheme.profileIcons
                                                )
                                              ),
                                              labelsDistanceFromTrackBar: 60,
                                            ),
                                            onDragCompleted: (int _targhandler, _lowerval, _upperval){
                                              if(_vplayer.length>0 && _cutVideo){
                                                _selectedPortion=RangeValues(_lowerval, _upperval);
                                                VideoPlayerController _focplayer=_vplayer.last;
                                                if(_focplayer.value.isPlaying) {
                                                  _focplayer.pause();
                                                  _playIconOpacitCtr.add("kjut");
                                                }
                                                if(_targhandler == 0){
                                                  double _lowervalu=_lowerval;
                                                  _focplayer.seekTo(Duration(seconds: _lowervalu.toInt()));
                                                }
                                                else if(_targhandler == 1){
                                                  double _uppervalu=_upperval;
                                                  _focplayer.seekTo(Duration(seconds: _uppervalu.toInt()));
                                                }
                                                _playRangeVals=_selectedPortion;
                                              }
                                            },
                                            decoration: BoxDecoration(
                                              color: pageTheme.bgColorVar1
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      ),//filepicker and first range selected

                      Container(
                        margin: EdgeInsets.only(top: 16),
                        padding: EdgeInsets.only(left: 16,right: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              child: StreamBuilder(
                                stream:_cutWallVideoCtr.stream,
                                builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                  return CheckboxListTile(
                                    onChanged: (bool _curval){
                                      _cutWallVideo= !_cutWallVideo;
                                      _cutWallVideoCtr.add("kjut");
                                    },
                                    value: _cutWallVideo,
                                    title: Text(
                                      "Select a portion for your wall - 15 secs. max (optional)",
                                      style: TextStyle(
                                        color: pageTheme.fontColor,
                                        fontSize: 12
                                      ),
                                    ),
                                    controlAffinity: ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.only(left: 0),
                                    subtitle: Text(
                                        "Not selecting, means no wall post will be made",
                                      style: TextStyle(
                                        color: pageTheme.profileIcons,
                                        fontSize: 11
                                      ),
                                    ),
                                    secondary: Container(
                                      child: StreamBuilder(
                                        stream: _playIconOpacitCtr.stream,
                                        builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                          return InkWell(
                                            onTap: (){
                                              if(_vplayer.length>0 && _cutWallVideo){
                                                _playRange=true;
                                                _playRangeVals=_wallRange;
                                                if(_vplayer.last.value.isPlaying){
                                                  _vplayer.last.pause();
                                                }
                                                else{
                                                  _vplayer.last.play();
                                                }
                                                _playIconOpacitCtr.add("kjut");
                                              }
                                            },
                                            child: Ink(
                                              child: Icon(
                                                  (_vplayer.length > 0 && _vplayer.last.value.isPlaying) ? FlutterIcons.pause_faw : FlutterIcons.play_faw,
                                                color: pageTheme.profileIcons,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Container(
                              child: Container(
                                child: StreamBuilder(
                                  stream: _selectionChangeNotifier.stream,
                                  builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                    return StreamBuilder(
                                      stream: _wallRangeDragNotifier.stream,
                                      builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                        return FlutterSlider(
                                          rangeSlider: true,
                                          tooltip: FlutterSliderTooltip(
                                              textStyle: TextStyle(
                                                  color: pageTheme.fontColor
                                              ),
                                              boxStyle: FlutterSliderTooltipBox(
                                                  decoration: BoxDecoration(
                                                      color: pageTheme.bgColor
                                                  )
                                              ),
                                              leftSuffix: Text(
                                                " S",
                                                style: TextStyle(
                                                    color: pageTheme.fontColor
                                                ),
                                              ),
                                              rightSuffix: Text(
                                                " S",
                                                style: TextStyle(
                                                    color: pageTheme.fontColor
                                                ),
                                              )
                                          ),
                                          values: [_wallRange.start, _wallRange.end],
                                          min: 0, max: _videoRange.end,
                                          hatchMark: FlutterSliderHatchMark(
                                            density: .5,
                                            linesDistanceFromTrackBar: -32,
                                            displayLines: true,
                                            linesAlignment: FlutterSliderHatchMarkAlignment.left,
                                            smallLine: FlutterSliderSizedBox(
                                                width: 1, height: 16,
                                                decoration: BoxDecoration(
                                                    color: pageTheme.fontColor
                                                )
                                            ),
                                            bigLine: FlutterSliderSizedBox(
                                                width: 2, height: 10,
                                                decoration: BoxDecoration(
                                                    color: pageTheme.profileIcons
                                                )
                                            ),
                                            labelsDistanceFromTrackBar: 60,

                                          ),
                                          onDragging: (int _targhandler, _lowerval, _upperval){
                                            if(_vplayer.length>0 && _cutWallVideo){
                                              if(_targhandler == 0){
                                                if(_upperval - _lowerval >14){
                                                  double _lowervalu= _lowerval > 0 ? _lowerval-1 : 0;
                                                  _wallRange= RangeValues(_lowervalu, _lowervalu + 15);
                                                }
                                                else{
                                                  _wallRange= RangeValues(_lowerval, _upperval);
                                                }
                                              }
                                              else if(_targhandler == 1){
                                                if(_upperval - _lowerval >14){
                                                  double _uppervalu=_upperval < _videoRange.end ? _upperval+1 : _videoRange.end;
                                                  _wallRange= RangeValues(_uppervalu - 15, _uppervalu);
                                                }
                                                else{
                                                  _wallRange= RangeValues(_lowerval, _upperval);
                                                }
                                              }
                                              _wallRangeDragNotifier.add("kjut");
                                            }
                                          },
                                          onDragCompleted: (int _targhandler, _lowerval, _upperval){
                                            if(_vplayer.length>0 && _cutWallVideo){
                                              _wallRange= RangeValues(_lowerval, _upperval);
                                              VideoPlayerController _focplayer= _vplayer.last;
                                              if(_focplayer.value.isPlaying){
                                                _focplayer.pause();
                                                _playIconOpacitCtr.add("kjut");
                                              }
                                              if(_targhandler == 0){
                                                double _lowervalu=_lowerval;
                                                _focplayer.seekTo(Duration(seconds: _lowervalu.toInt()));
                                              }
                                              else if(_targhandler == 1){
                                                double _uppervalu=_upperval;
                                                _focplayer.seekTo(Duration(seconds: _uppervalu.toInt()));
                                              }
                                              _playRangeVals=_wallRange;
                                            }
                                          },
                                          decoration: BoxDecoration(
                                              color: pageTheme.bgColorVar1
                                          ),
                                          maximumDistance: 15,
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            )
                          ],
                        ),
                      ), //wall portion

                      Container(
                        margin: EdgeInsets.only(top: 16),
                        padding: EdgeInsets.only(left: 16,right: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              child: StreamBuilder(
                                stream:_customPosterCtr.stream,
                                builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                  return CheckboxListTile(
                                    onChanged: (bool _curval){
                                      _customPoster= !_customPoster;
                                      _customPosterCtr.add("kjut");
                                    },
                                    value: _customPoster,
                                    title: Text(
                                      "Select a frame as poster (optional)",
                                      style: TextStyle(
                                          color: pageTheme.fontColor,
                                          fontSize: 12
                                      ),
                                    ),
                                    controlAffinity: ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.only(left: 0),
                                    subtitle: Text(
                                      "Not selecting means the frame at 1s. will be used",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: pageTheme.profileIcons
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Container(
                              child: Container(
                                child: StreamBuilder(
                                  stream: _selectionChangeNotifier.stream,
                                  builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                    return FlutterSlider(
                                      tooltip: FlutterSliderTooltip(
                                          textStyle: TextStyle(
                                              color: pageTheme.fontColor
                                          ),
                                          boxStyle: FlutterSliderTooltipBox(
                                              decoration: BoxDecoration(
                                                  color: pageTheme.bgColor
                                              )
                                          ),
                                          leftSuffix: Text(
                                            " S",
                                            style: TextStyle(
                                                color: pageTheme.fontColor
                                            ),
                                          ),
                                          rightSuffix: Text(
                                            " S",
                                            style: TextStyle(
                                                color: pageTheme.fontColor
                                            ),
                                          )
                                      ),
                                      values: [_posterFrame/1],
                                      min: 0, max: _videoRange.end,
                                      hatchMark: FlutterSliderHatchMark(
                                        density: .5,
                                        linesDistanceFromTrackBar: -32,
                                        displayLines: true,
                                        linesAlignment: FlutterSliderHatchMarkAlignment.left,
                                        smallLine: FlutterSliderSizedBox(
                                            width: 1, height: 16,
                                            decoration: BoxDecoration(
                                                color: pageTheme.fontColor
                                            )
                                        ),
                                        bigLine: FlutterSliderSizedBox(
                                            width: 2, height: 10,
                                            decoration: BoxDecoration(
                                                color: pageTheme.profileIcons
                                            )
                                        ),
                                        labelsDistanceFromTrackBar: 60,

                                      ),
                                      onDragCompleted: (int _targhandler, _lowerval, _upperval){
                                        if(_vplayer.length>0 && _customPoster){
                                          double _lowervalu=_lowerval;
                                          _posterFrame=_lowervalu.toInt();
                                          VideoPlayerController _focplayer= _vplayer.last;
                                          if(_focplayer.value.isPlaying){
                                            _focplayer.pause();
                                          }
                                          _focplayer.seekTo(Duration(seconds: _posterFrame));
                                        }
                                      },
                                      decoration: BoxDecoration(
                                          color: pageTheme.bgColorVar1
                                      ),
                                      maximumDistance: 15,
                                    );
                                  },
                                ),
                              ),
                            )
                          ],
                        ),
                      ), //poster

                      Container(
                        padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
                        margin: EdgeInsets.only(top: 16),
                        decoration: BoxDecoration(
                            color: pageTheme.bgColorVar1
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding:EdgeInsets.only(left: 9),
                              margin: EdgeInsets.only(bottom: 5),
                              child: Text(
                                "Post Title",
                                style: TextStyle(
                                    color: pageTheme.profileIcons
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                  color: pageTheme.bgColor
                              ),
                              padding: EdgeInsets.only(top: 2, bottom: 2, left: 12, right: 12),
                              child: TextField(
                                style: TextStyle(
                                    color: pageTheme.fontColor
                                ),
                                controller: _postTitleCtr,
                                decoration: InputDecoration(
                                    focusedBorder: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    hintText: "Post title",
                                    hintStyle: TextStyle(
                                        color: pageTheme.profileIcons
                                    )
                                ),
                                onEditingComplete: (){
                                  FocusScope.of(_pageContext).requestFocus(_aboutNode);
                                },
                                textInputAction: TextInputAction.next,
                              ),
                            )
                          ],
                        ),
                      ), //post title

                      Container(
                        margin: EdgeInsets.only(top: 16),
                        padding: EdgeInsets.only(left: 16),
                        width: _screenSize.width,
                        height: 80,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              child: Text(
                                "Post Interest",
                                style: TextStyle(
                                  color: pageTheme.fontGrey,
                                  fontSize: 13
                                ),
                              ),
                              margin: EdgeInsets.only(bottom: 5),
                            ),
                            Expanded(
                              child: Container(
                                width: _screenSize.width,
                                child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    physics: BouncingScrollPhysics(),
                                    itemCount: globals.interestCat.length,
                                    cacheExtent: _screenSize.width*3,
                                    itemBuilder: (BuildContext _ctx, int _itemIndex){
                                      String _targInterest= globals.interestCat[_itemIndex];
                                      return Container(
                                        width: 200,
                                        decoration: BoxDecoration(
                                          color: pageTheme.bgColorVar1
                                        ),
                                        margin: EdgeInsets.only(right: 16),
                                        child: StreamBuilder(
                                          stream: _selectedInterestChangeNotifier.stream,
                                          builder: (BuildContext _ctx, AsyncSnapshot _interestShot){
                                            return CheckboxListTile(
                                              onChanged: (bool _curval){
                                                if(_selectedInterest.indexOf(_targInterest)>-1){
                                                  _selectedInterest.remove(_targInterest);
                                                }
                                                else{
                                                  _selectedInterest.add(_targInterest);
                                                }
                                                _selectedInterestChangeNotifier.add("kjut");
                                              },
                                              value: _selectedInterest.indexOf(_targInterest)>-1,
                                              title: Text(
                                                _targInterest,
                                                style: TextStyle(
                                                    color: pageTheme.profileIcons
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    }
                                ),
                              ),
                            )
                          ],
                        ),
                      ),//post interest

                      Container(
                        padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
                        margin: EdgeInsets.only(top: 16),
                        decoration: BoxDecoration(
                          color: pageTheme.bgColorVar1
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding:EdgeInsets.only(left: 9),
                              margin: EdgeInsets.only(bottom: 5),
                              child: Text(
                                "About post",
                                style: TextStyle(
                                  color: pageTheme.profileIcons
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: pageTheme.bgColor
                              ),
                              padding: EdgeInsets.only(top: 2, bottom: 2, left: 12, right: 12),
                              child: TextField(
                                style: TextStyle(
                                  color: pageTheme.fontColor
                                ),
                                controller: _postAboutCtr,
                                decoration: InputDecoration(
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  hintText: "Say something about this post",
                                  hintStyle: TextStyle(
                                    color: pageTheme.profileIcons
                                  )
                                ),
                                focusNode: _aboutNode,
                                minLines: 2,
                                maxLines: 3,
                                textInputAction: TextInputAction.newline,
                              ),
                            )
                          ],
                        ),
                      ), //post about

                      Container(
                        margin: EdgeInsets.only(top: 16),
                        padding: EdgeInsets.only(left: 16, right: 16),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: (){
                              savePost();
                            },
                            child: Ink(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(7)
                                ),
                                padding: EdgeInsets.only(top: 12, bottom: 12),
                                alignment: Alignment.center,
                                child: Text(
                                  "Post",
                                  style: TextStyle(
                                    color: Colors.white
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )//post button
                    ],
                  ),
                ),

                StreamBuilder(
                  stream: _toastCtr.stream,
                  builder: (BuildContext _ctx, _snapshot){
                    if(_showToast){
                      return AnimatedPositioned(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        left: _toastLeft, top: _toastTop,
                        child: IgnorePointer(
                          ignoring: true,
                          child: Container(
                            width: _screenSize.width,
                            alignment: Alignment.center,
                            child: TweenAnimationBuilder(
                              tween: Tween<double>(
                                  begin: 0, end: 1
                              ),
                              duration: Duration(milliseconds: 700),
                              curve: Curves.easeInOut,
                              builder: (BuildContext _ctx, double _twVal, _){
                                return Opacity(
                                  opacity: _twVal < 0 ? 0 : _twVal>1?1: _twVal,
                                  child: Container(
                                    width: (_twVal * _screenSize.width) - 96<0 ? 0 : _twVal>1 ? 1 : (_twVal * _screenSize.width) - 96,
                                    padding: EdgeInsets.only(left: 16, right: 16, top: 9, bottom: 9),
                                    decoration: BoxDecoration(
                                        color: pageTheme.toastBGColor,
                                        borderRadius: BorderRadius.circular(16)
                                    ),
                                    child: Container(

                                      child: Text(
                                        _twVal < .7 ? "" : _toastText,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: pageTheme.toastFontColor,
                                            fontSize: (_twVal * 13) + 1
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    }
                    return Container();
                  },
                )//local toast displayer
              ],
            ),
          ),
          autofocus: true,
          onFocusChange: (bool _isFocused){
            if(_isFocused){
              if(MediaQuery.of(_pageContext).platformBrightness == Brightness.light){
                _deviceTheme="light";
              }
              else{
                _deviceTheme="dark";
              }
              if(_deviceTheme!=pageTheme.deviceTheme){
                pageTheme.deviceTheme=_deviceTheme;
                pageTheme.updateTheme();
                setState(() {
                });
              }
            }
          },
        ),
      ),
      onWillPop: ()async{
        Navigator.of(_pageContext).pop();
        return false;
      },
    );
  }//route's build method

  resetVPlayer(){
    _vplayer.forEach((element) {
      element.dispose();
    });
    _vplayer=List<VideoPlayerController>();
    _selectionChangeNotifier.add("kjut");
  }//reset video player

  pickVideo()async{
    try{
      resetVPlayer();
      File _pickedFile=await FilePicker.getFile(
        type: FileType.video
      );
      _selectedVid= _pickedFile;
      _vplayer.add(
        VideoPlayerController.file(_selectedVid)
      );
      _vplayer.last.initialize().then((value) {
        VideoPlayerController _focplayer= _vplayer.last;
        _focplayer.setLooping(true);
        _vidAR=_focplayer.value.aspectRatio;
        int _viddur=_focplayer.value.duration.inSeconds;
        if(_viddur > 10){
          _selectedPortion=RangeValues(0, _viddur/1);
          _videoRange=RangeValues(0, _viddur/1);
          _wallRange=RangeValues(0, _viddur<16 ? _viddur : 15);
          _posterFrame=1;
          _curPlayerPos=0;
          _selectionChangeNotifier.add("kjut");
        }
        else{
          showLocalToast(
            text: "Minimum video length allowed is 10 seconds",
            duration: Duration(seconds: 5)
          );
        }
      });
      _vplayer.last.addListener(() {
        _curPlayerPos= _vplayer.last.value.position.inSeconds;
        if(_playRange){
          if(_curPlayerPos>_playRangeVals.end.toInt()){
            _vplayer.last.seekTo(Duration(seconds: _playRangeVals.start.toInt()));
            _curPlayerPos= _vplayer.last.value.position.inSeconds;
          }
        }
        _playerPosChangeNotifier.add("kjut");
      });
    }
    catch(ex){
    }
  }//pick a video file

  List<String> _selectedInterest=List<String>();
  bool _posting=false;
  FlutterFFmpeg _fFmpeg= FlutterFFmpeg();
  String _postID="";
  String _wallPostID="";
  savePost()async{
    if(_posting || globals.tvPostData["status"] == "active") return;
    if(_vplayer.length<1){
      showLocalToast(
          text: "Select a video file to continue",
          duration: Duration(seconds: 3)
      );
      return;
    }
    if(_postTitleCtr.text==""){
      showLocalToast(
          text: "Post title is required to continue",
          duration: Duration(seconds: 5)
      );
      return;
    }
    if(_postAboutCtr.text==""){
      showLocalToast(
        text: "Say something about this post, in the post's about box",
        duration: Duration(seconds: 5)
      );
      return;
    }
    if(_selectedInterest.length<1){
      showLocalToast(
          text: "Select at least an interest to continue",
          duration: Duration(seconds: 5)
      );
      return;
    }
    globals.tvPostData["status"]="active";
    globals.tvPostData["title"]="Getting things ready ...";
    globals.globalTVPostCtr.add("kjut");
    //cut the video
    int _viddur=_vplayer.last.value.duration.inSeconds;
    int _execresult=-1;
    String _outpath=_appDir.path + "/camtv/tmp/" + DateTime.now().millisecondsSinceEpoch.toString() + ".mp4";
    String _inpath= _selectedVid.path;
    if(_cutVideo){
      globals.tvPostData["title"]="Trimming video selection ...";
      globals.globalTVPostCtr.add("kjut");
      _viddur= (_selectedPortion.end - _selectedPortion.start).toInt();
      String _startpos= globals.convSecToHMS(_selectedPortion.start.toInt());
      int _endPos=(_selectedPortion.end  - _selectedPortion.start).toInt();
      String _endpos=globals.convSecToHMS(_endPos);
      _execresult=await _fFmpeg.execute("-ss $_startpos -i '$_inpath'  -t $_endpos -crf 30 -c:v libx264 -c:a aac $_outpath");
    }
    else{
      globals.tvPostData["title"]="Resizing video for upload ...";
      globals.globalTVPostCtr.add("kjut");
      _execresult=await _fFmpeg.execute("-i '$_inpath' -crf 30 -c:v libx264 -c:a aac $_outpath");
    }
    if(_execresult == 0){
      String _cutwallout= _appDir.path + "/camtv/tmp/" + DateTime.now().millisecondsSinceEpoch.toString() + ".mp4";
      int _wallExecResult=-1;
      if(_cutWallVideo){
        globals.tvPostData["title"]="Trimming selection for wall post ...";
        globals.globalTVPostCtr.add("kjut");
        String _startpos= globals.convSecToHMS(_wallRange.start.toInt());
        int _endPos=(_wallRange.end  - _wallRange.start).toInt();
        String _endpos=globals.convSecToHMS(_endPos);
        _wallExecResult=await _fFmpeg.execute("-ss $_startpos -i '$_inpath'  -t $_endpos -crf 30 -c:v libx264 -c:a aac $_cutwallout");
      }
      String _posterPath= _appDir.path + "/camtv/tmp/" + DateTime.now().millisecondsSinceEpoch.toString() + ".jpg";
      int _posterExecResult=-1;
      globals.tvPostData["title"]="Capturing poster frame ...";
      globals.globalTVPostCtr.add("kjut");
      if(_customPoster){
        String _frameSec= globals.convSecToHMS(_posterFrame);
        _posterExecResult= await _fFmpeg.execute("-i '$_inpath' -ss $_frameSec -vframes 1 '$_posterPath'");
      }
      else{
        _posterExecResult= await _fFmpeg.execute("-i '$_inpath' -ss 00:00:01 -vframes 1 '$_posterPath'");
      }
      globals.tvPostData["title"]="Starting upload ...";
      globals.globalTVPostCtr.add("kjut");
      try{
        http.Response _resp= await http.post(
          globals.globBaseTVURL + "?process_as=create_tv_post",
          body: {
            "user_id" : globals.userId,
            "channel_id": widget.channelID,
            "post_title": _postTitleCtr.text,
            "post_text": _postAboutCtr.text,
            "ar": _vidAR.toString(),
            "duration": _viddur.toString(),
            "interests": _selectedInterest.join(",")
          }
        );
        if(_resp.statusCode == 200){
          var _respObj= jsonDecode(_resp.body);
          if(_respObj["status"] == "success"){
            _postID= _respObj["post_id"];
            if(_execresult == 0){
              globals.tvPostData["title"]="Uploading video file ...";
              globals.globalTVPostCtr.add("kjut");
              File _vidout= File(_outpath);
              String _vidDataStr= base64Encode(_vidout.readAsBytesSync());
              await postSplitFiles(_vidDataStr, "camtv");

              if(_cutWallVideo){
                if(_wallExecResult == 0){
                  globals.tvPostData["title"]="Uploading wall post video ...";
                  globals.globalTVPostCtr.add("kjut");
                  http.Response _wallPostResp= await http.post(
                    globals.globBaseUrl + "?process_as=create_wall_post",
                    body: {
                      "user_id": globals.userId,
                      "text": _postTitleCtr.text
                    }
                  );

                  if(_wallPostResp.statusCode == 200){
                    var _wallRespObj= jsonDecode(_wallPostResp.body);
                    if(_wallRespObj["status"] == "success"){
                      _wallPostID= _wallRespObj["post_id"];
                    }
                  }

                  File _wallVidFile=File(_cutwallout);
                  String _wallVidStr= base64Encode(_wallVidFile.readAsBytesSync());
                  await postSplitFiles(_wallVidStr, "wall_post");
                }
                else{
                  globalEchoError("Could not complete this upload - error was found during wall post video trimming");
                }
              }

              if(_posterExecResult == 0){
                globals.tvPostData["title"]="Almost done ...";
                globals.globalTVPostCtr.add("kjut");
                File _posterFile= File(_posterPath);
                String _posterStr= base64Encode(_posterFile.readAsBytesSync());
                http.Response _posterResp= await http.post(
                    globals.globBaseTVURL + "?process_as=upload_tv_poster",
                    body: {
                      "user_id": globals.userId,
                      "post_id": _postID,
                      "file_str": _posterStr
                    }
                );
                if(_posterResp.statusCode == 200){
                  var _posterRespObj=jsonDecode(_posterResp.body);
                  if(_posterRespObj["status"] == "success"){
                    globals.tvPostData["title"]="Post was successfully created!";
                    globals.globalTVPostCtr.add("kjut");
                    Future.delayed(
                      Duration(seconds: 1),
                        (){
                        globals.tvPostData["status"]="passive";
                          globals.globalTVPostCtr.add("kjut");
                        }
                    );
                  }
                }
              }
            }
            else{
              globalEchoError("Could not complete this upload - error was found during video resizing");
            }
          }
        }
      }
      catch(ex){
        debugPrint("kjut we found an error $ex");
        _posting=false;
        globalEchoError("Kindly ensure that your device is properly connected to the internet");
      }
    }
  }//save post

  globalEchoError(String _errText){
    globals.tvPostData["title"]=_errText;
    globals.globalTVPostCtr.add("kjut");
    Future.delayed(
      Duration(seconds: 5),
        (){
        globals.tvPostData["status"]="passive";
        globals.globalTVPostCtr.add("kjut");
        }
    );
  }

  postSplitFiles(String _dataStr, String _splitType)async{
    //we will split video files into chunks
    String _b64str= _dataStr;
    int _count= _b64str.length;
    int _strsize= 1024000 * 2; //2mb of string
    int _chunklen= (_count/_strsize).ceil();
    int _pointer=0;
    for(int _k=0; _k<_chunklen; _k++){
      if(_k==_chunklen-1){
        http.Response _partresp=await http.post(
            globals.globBaseTVURL + "?process_as=post_complete_split_file",
            body: {
              "user_id": globals.userId,
              "post_id": _postID,
              "part": _b64str.substring(_pointer),
              "wall_post_id": _wallPostID, //for the sake of creating a wall post
              "ar": "$_vidAR/1", //for the sake of creating a wall post
              "type": _splitType
            }
        );
        if(_partresp.statusCode == 200){
          var _respObj= jsonDecode(_partresp.body);
          if(_respObj["status"] == "success"){
            return true;
          }
          else{
            return false;
          }
        }
      }
      else{
        int _pcent= ((_k/_chunklen) * 100).floor();
        if(_splitType == "camtv") globals.tvPostData["title"]="Uploading video file ... $_pcent% complete";
        else globals.tvPostData["title"]="Uploading wall post video file ... $_pcent% complete";
        globals.globalTVPostCtr.add("kjut");
        await http.post(
            globals.globBaseTVURL + "?process_as=save_part_video_file",
            body: {
              "post_id": _postID,
              "part": _b64str.substring(_pointer, (_pointer+_strsize)),
              "type" : _splitType,
              "wall_post_id": _wallPostID
            }
        );
      }
      _pointer +=_strsize;
    }
  }

  StreamController _playerPosChangeNotifier= StreamController.broadcast();
  StreamController _wallRangeDragNotifier= StreamController.broadcast();
  TextEditingController _postAboutCtr= TextEditingController();
  FocusNode _aboutNode= FocusNode();
  TextEditingController _postTitleCtr= TextEditingController();
  StreamController _selectedInterestChangeNotifier=StreamController.broadcast();
  @override
  void dispose() {
    _toastCtr.close();
    _playerPosChangeNotifier.close();
    _vplayer.forEach((element) {
      element.dispose();
    });
    _selectionChangeNotifier.close();
    _cutVideoCtr.close();
    _cutWallVideoCtr.close();
    _customPosterCtr.close();
    _wallRangeDragNotifier.close();
    _postAboutCtr.dispose();
    _postTitleCtr.dispose();
    _selectionChangeNotifier.close();
    super.dispose();
  }//route's dispose method

  double _toastLeft=0, _toastTop=0;
  StreamController _toastCtr= StreamController.broadcast();
  bool _showToast=false;
  String _toastText="";
  showLocalToast({String text, Duration duration}){
    _showToast=true;
    _toastText=text;
    _toastCtr.add("kjut");
    Future.delayed(
        duration,
            (){
          _showToast=false;
          _toastCtr.add("kjut");
        }
    );
  }//show local toast
}