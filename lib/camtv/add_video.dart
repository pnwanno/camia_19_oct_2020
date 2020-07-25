import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:liquid_progress_indicator/liquid_progress_indicator.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';

import '../globals.dart' as globals;

class AddVideo extends StatefulWidget{
  _AddVideo createState(){
    return _AddVideo();
  }
  final String channelID;
  AddVideo(this.channelID);
}

class _AddVideo extends State<AddVideo>{

  String _globalChannelID="";
  Directory _appDir;
  Directory _tvDir;
  Directory _tvTmpDir;
  @override
  void initState() {
    super.initState();
    initDir();
  }

  FlutterFFmpeg _fFmpeg;
  initDir()async{
    _globalChannelID=widget.channelID;
    _appDir= await getApplicationDocumentsDirectory();
    _tvDir= Directory(_appDir.path + "/camtv");
    _tvTmpDir=Directory(_tvDir.path + "/tmp");
    _tvTmpDir.createSync();
    delLastPoster();
    _fFmpeg= FlutterFFmpeg();
    _fFmpeg.disableLogs();
    _fFmpeg.enableStatisticsCallback((time, size, bitrate, speed, videoFrameNumber, videoQuality, videoFps){
      debugPrint("kjut time is $time");
    });
  }//initialize the tv directory and path

  delLastPoster()async{
    String _outpath=_tvTmpDir.path + "/videoposter.jpg";
    File _tmpvideoposter=File(_outpath);
    bool _exists=await _tmpvideoposter.exists();
    if(_exists){
      await _tmpvideoposter.delete();
    }
  }

  VideoPlayerController _selVidCtr;
  File _selectedVideoFile;
  StreamController _selectFileNotifier= StreamController.broadcast();
  int _playerCurPos= 0;
  String _selVidFName="";
  RangeValues _playRange=RangeValues(0,0);
  int _curPlayingRange=0;
  pickAVideo() async{
    FilePicker.getFile(
      type: FileType.video
    ).then((_selectedF){
      _selectedVideoFile=_selectedF;
      List<String> _brkfpath=_selectedVideoFile.path.split("/");
      _selVidFName= _brkfpath.last;
      if(_selVidCtr!=null){
        if(_selVidCtr.value.isPlaying) _selVidCtr.pause();
      }
      _selVidCtr= VideoPlayerController.file(_selectedVideoFile);
      _selVidCtr.initialize().then((value){
        _selVidCtr.seekTo(Duration(seconds: 1));
        _selVidCtr.setLooping(true);
        _selectFileNotifier.add("kjut");
        _clipRangeA= RangeValues(0, _selVidCtr.value.duration.inSeconds/1);
        _clipRangeB= RangeValues(0, _selVidCtr.value.duration.inSeconds/1);
        _playRange= RangeValues(0, _selVidCtr.value.duration.inSeconds/1);
      });
      _selVidCtr.addListener(() {
        _playpauseNotifier.add("kjut");
        _muteUnmuteNotifier.add("kjut");
        _playerCurPos= _selVidCtr.value.position.inSeconds;
        if(_playerCurPos>=_playRange.end.toInt()){
          _selVidCtr.seekTo(Duration(seconds: _playRange.start.toInt()));
        }
        _playerPosNotifier.add("kjut");
        Future.delayed(
          Duration(seconds: 1),
            (){
            getVideoPoster();
            }
        );
      });
    });
  }//pick a video

  String convSecToMin(int secs){
    return (secs/60).floor().toString().padLeft(2,"0") + " : " + (secs % 60).toString().padLeft(2, "0");
  }//convert media sec to min

  bool _pageBusy= false;
  double _pageBusyOpacity=0;
  StreamController _pageBusyCtr= StreamController.broadcast();
  String _pageBusyText="Please wait ...";
  double _pageBusyAmount= .5;
  StreamController _pageBusyFloatingCtr= StreamController.broadcast();
  double _pageBusyAnimationEndVal=0;

  StreamController _playpauseNotifier= StreamController.broadcast();
  StreamController _muteUnmuteNotifier= StreamController.broadcast();
  StreamController _playerPosNotifier= StreamController.broadcast();

  TextEditingController _postTitleCtr= TextEditingController();
  TextEditingController _postAboutCtr= TextEditingController();

  StreamController _clipVideoANotifier=StreamController.broadcast();
  bool _isClippedA=false;
  RangeValues _clipRangeA= RangeValues(0,0);

  StreamController _clipVideoBNotifier=StreamController.broadcast();
  bool _isClippedB=false;
  RangeValues _clipRangeB= RangeValues(0, 15);

  StreamController _videoPosterSelectedNotifier= StreamController.broadcast();
  StreamController _posterRangeNotifier= StreamController.broadcast();
  int _selectedPosterTime=0;


  File _successfulPoster;
  getVideoPoster()async{
    String _outpath=_tvTmpDir.path + "/videoposter.jpg";
     String _selpos= "00:00:$_selectedPosterTime";
     String _inFpath= _selectedVideoFile.path;
    debugPrint("kjut -y -i $_inFpath -ss $_selpos -frames:v 1 $_outpath");
     _fFmpeg.execute("-y -i $_inFpath -ss $_selpos -frames:v 1 $_outpath").then((_retval){
       debugPrint("kjut -y -i $_inFpath -ss $_selpos -frames:v 1 $_outpath and ret val is $_retval");
       if(_retval == 0){
         _successfulPoster=File(_outpath);
         _videoPosterSelectedNotifier.add("event");
       }
     });
  }//get video poster



  globals.KjToast _kjToast;
  BuildContext _pageContext;
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize= MediaQuery.of(_pageContext).size;
    if(_kjToast==null){
      _kjToast=globals.KjToast(12.0, _screenSize, _toastCtr, _screenSize.height * .4);
    }
    return WillPopScope(
        child: Scaffold(
          backgroundColor: Color.fromRGBO(32, 32, 32, 1),
          body: FocusScope(
            child: Container(
              child: Stack(
                children: <Widget>[
                  Container(
                    width: _screenSize.width,
                    height: _screenSize.height,
                    padding: EdgeInsets.only(left: 20, right: 20, top: 32, bottom: 32),
                    child: StreamBuilder(
                      stream: _selectFileNotifier.stream,
                      builder: (BuildContext _ctx, AsyncSnapshot _selFshot){
                        if(_selectedVideoFile==null){
                          return Container(
                            alignment: Alignment.center,
                            padding: EdgeInsets.only(top: 120),
                            child: GestureDetector(
                              onTap: (){
                                pickAVideo();
                              },
                              child: Container(
                                alignment: Alignment.center,
                                  child: Column(
                                    children: <Widget>[
                                      Container(
                                        width: 120, height: 120,
                                        margin: EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                            color: Colors.grey,
                                            borderRadius: BorderRadius.circular(70)
                                        ),
                                        child: Icon(
                                          FlutterIcons.upload_ent,
                                          size: 50,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Container(
                                        child: Text(
                                          "Tap to choose a video File",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      )
                                    ],
                                  )
                              ),
                            ),
                          );
                        }
                        else{
                          return TweenAnimationBuilder(
                            tween: Tween<double>(
                                begin: 30, end: 0
                            ),
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            builder: (BuildContext _twctx, double _twcurval, __){
                              return Container(
                                height: _screenSize.height,
                                child: ListView(
                                  children: <Widget>[
                                    Container(
                                      width: _screenSize.width,
                                      transform: Matrix4.translationValues(0, _twcurval, 0),
                                      child: Column(
                                        children: <Widget>[
                                          Container(
                                            width: _screenSize.width, height: 400,
                                            child: Stack(
                                              children: <Widget>[
                                                Container(
                                                    width: _screenSize.width, height: 400,
                                                    alignment: Alignment.center,
                                                    child: Container(

                                                      child: AspectRatio(
                                                        aspectRatio: _selVidCtr.value.aspectRatio,
                                                        child: VideoPlayer(_selVidCtr),
                                                      ),
                                                    )
                                                ),// the player,
                                                Positioned(
                                                  width: _screenSize.width - 48,
                                                  left: 0, bottom: 10,
                                                  child: Container(
                                                    child:StreamBuilder(
                                                      stream: _playerPosNotifier.stream,
                                                      builder: (BuildContext _slideCtx, _slideShot){
                                                        return Slider(
                                                          divisions: _selVidCtr.value.duration.inSeconds,
                                                          min: 0,max: _selVidCtr.value.duration.inSeconds/1,
                                                          value: _playerCurPos/1,
                                                          onChanged: (double _curVal){
                                                            _playerCurPos=_curVal.toInt();
                                                            _selVidCtr.seekTo(Duration(seconds: _playerCurPos));
                                                          },
                                                          label: _playerCurPos.toString(),
                                                          activeColor: Colors.black,
                                                          inactiveColor: Colors.orange,
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ), //player's timeline
                                                Positioned(
                                                  right: 12, bottom: (50 - _twcurval),
                                                  child: Container(
                                                    padding: EdgeInsets.only(left:12, right: 12, top:9, bottom: 9),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black,
                                                      borderRadius: BorderRadius.circular(7)
                                                    ),
                                                    child: Row(
                                                      children: <Widget>[
                                                        Container(
                                                          child: StreamBuilder(
                                                            stream:_playerPosNotifier.stream,
                                                            builder: (BuildContext _ctx, _snapshot){
                                                              return Text(
                                                                convSecToMin(_playerCurPos) + " / ",
                                                                style: TextStyle(
                                                                  color: Colors.white,
                                                                  fontSize: 12,
                                                                  fontFamily: "ubuntu"
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                        Container(
                                                          child: Text(
                                                            convSecToMin(_selVidCtr.value.duration.inSeconds),
                                                            style: TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 12,
                                                              fontFamily: "ubuntu"
                                                            ),
                                                          ),
                                                        )
                                                      ],
                                                    ),
                                                  ),
                                                )//player curtime and duration
                                              ],
                                            ),
                                          ), //the player, timeline and time
                                          Container(
                                            margin: EdgeInsets.only(top: 11),
                                            child: Flex(
                                              direction: Axis.horizontal,
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: <Widget>[
                                                Flexible(
                                                  flex: 2,
                                                  child: Row(
                                                    children: <Widget>[
                                                      Container(
                                                        child: Text(
                                                          _selVidFName,
                                                          style: TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 11
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      StreamBuilder(
                                                        builder: (BuildContext _mmctx, AsyncSnapshot _mmsnapshot){
                                                          return Container(
                                                            margin: EdgeInsets.only(left: 12, right:12),
                                                            child: Material(
                                                              color:Colors.transparent,
                                                              child: InkResponse(
                                                                onTap: (){
                                                                  pickAVideo();
                                                                },
                                                                child: Icon(
                                                                  FlutterIcons.folder_video_ent,
                                                                  color: Color.fromRGBO(100, 100, 100, 1),
                                                                  size: 28,
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      ), //video folder
                                                    ],
                                                  ),
                                                ),
                                                Flexible(
                                                  flex: 1,
                                                  child: Container(
                                                    alignment: Alignment.centerRight,
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      children: <Widget>[
                                                        StreamBuilder(
                                                          stream: _playpauseNotifier.stream,
                                                          builder: (BuildContext _ppctx, AsyncSnapshot _ppsnapshot){
                                                            return Container(
                                                              child: Material(
                                                                color:Colors.transparent,
                                                                child: InkResponse(
                                                                  onTap: (){
                                                                    if(_selVidCtr.value.isPlaying){
                                                                      _selVidCtr.pause();
                                                                    }
                                                                    else {
                                                                      _curPlayingRange=0;
                                                                      _playRange= RangeValues(0, _selVidCtr.value.duration.inSeconds/1);
                                                                      _selVidCtr.play();
                                                                    }
                                                                  },
                                                                  child: Icon(
                                                                      (_selVidCtr.value.isPlaying) ? FlutterIcons.pausecircle_ant: FlutterIcons.play_ant,
                                                                    color: Colors.white,
                                                                    size: 28,
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),//play pause button
                                                        StreamBuilder(
                                                          stream: _muteUnmuteNotifier.stream,
                                                          builder: (BuildContext _mmctx, AsyncSnapshot _mmsnapshot){
                                                            return Container(
                                                              margin: EdgeInsets.only(left: 12, right:12),
                                                              child: Material(
                                                                color:Colors.transparent,
                                                                child: InkResponse(
                                                                  onTap: (){
                                                                    if(_selVidCtr.value.volume == 1){
                                                                      _selVidCtr.setVolume(0);
                                                                    }
                                                                    else _selVidCtr.setVolume(1);
                                                                  },
                                                                  child: Icon(
                                                                    (_selVidCtr.value.volume == 1) ? FlutterIcons.volume_up_faw: FlutterIcons.volume_mute_faw5s,
                                                                    color: Colors.white,
                                                                    size: 28,
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ), //mute unmute button
                                                      ],
                                                    ),
                                                  ),
                                                )
                                              ],
                                            ),
                                          ),//the player caption, open folder, play btn, mute btn
                                        ],
                                      ),
                                    ), //player and controls

                                    Container(
                                      margin:EdgeInsets.only(top: 12),
                                      decoration: BoxDecoration(
                                        color:Color.fromRGBO(20, 20, 20, 1),
                                        borderRadius: BorderRadius.circular(7)
                                      ),
                                        padding:EdgeInsets.only(left:12, right:12),
                                        child: TextField(
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: Colors.white
                                          ),
                                          controller: _postTitleCtr,
                                          decoration: InputDecoration(
                                              hintText: "A caption for this post",
                                              hintStyle: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12
                                              ),
                                            labelText: "Post Title",
                                            labelStyle: TextStyle(
                                              color: Colors.white,
                                              fontSize:10
                                            ),
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none
                                          ),
                                        ),
                                    ),//collect post title
                                    Container(
                                      margin:EdgeInsets.only(top: 12),
                                      padding: EdgeInsets.only(left:16, right:16),
                                      decoration: BoxDecoration(
                                          color:Color.fromRGBO(32, 32, 32, 1),
                                        borderRadius: BorderRadius.circular(7),
                                        border: Border.all(
                                          color: Colors.black
                                        )
                                      ),
                                      child: TextField(
                                        minLines: 2, maxLines: 3,
                                        style: TextStyle(
                                            color: Colors.white
                                        ),
                                        controller: _postAboutCtr,
                                        decoration: InputDecoration(
                                            hintText: "A brief description on this post",
                                            hintStyle: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12
                                            ),
                                            labelText: "Brief Description",
                                            labelStyle: TextStyle(
                                                color: Colors.white,
                                                fontSize:10
                                            ),
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none
                                        ),
                                      ),
                                    ),//collect video about,
                                    StreamBuilder(
                                      stream: _clipVideoANotifier.stream,
                                      builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                        return Container(
                                          child: Column(
                                            children: <Widget>[
                                              Container(
                                                child: Row(
                                                  children: <Widget>[
                                                    Container(
                                                      child: Checkbox(
                                                        value: _isClippedA,
                                                        onChanged: (bool _curVal){
                                                          _isClippedA= _curVal;
                                                          _clipVideoANotifier.add("kjut");
                                                        },
                                                        activeColor: Colors.black,
                                                        checkColor: Colors.white,
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: GestureDetector(
                                                        onTap: (){
                                                          _isClippedA = !_isClippedA;
                                                          _clipVideoANotifier.add("kjut");
                                                        },
                                                        child: Container(
                                                          margin:EdgeInsets.only(left:12),
                                                          child: Text(
                                                              "Select and clip a part of this video",
                                                            style: TextStyle(
                                                              color: Colors.white
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              ),//checkbox
                                              (_isClippedA) ?
                                                  TweenAnimationBuilder(
                                                    tween: Tween<double>(
                                                      begin: 30, end: 0
                                                    ),
                                                    duration: Duration(milliseconds: 500),
                                                    builder: (BuildContext __ctx, __curval, __){
                                                      return Container(
                                                        transform: Matrix4.translationValues(0, __curval, 0),
                                                        child: Column(
                                                          children: <Widget>[
                                                            Container(
                                                              child: RangeSlider(
                                                                activeColor: Colors.deepOrange,
                                                                inactiveColor: Colors.white24,
                                                                labels: RangeLabels(_clipRangeA.start.toString(), _clipRangeA.end.toString()),
                                                                values: _clipRangeA,
                                                                onChanged: (_curRange){
                                                                  RangeValues _lastRange= _clipRangeA;
                                                                  if(_lastRange.start!=_curRange.start){
                                                                    _selVidCtr.seekTo(Duration(seconds: _clipRangeA.start.toInt()));
                                                                  }
                                                                  else{
                                                                    _selVidCtr.seekTo(Duration(seconds: _clipRangeA.end.toInt()));
                                                                  }
                                                                  _clipRangeA=_curRange;
                                                                  if(_curPlayingRange == 1){
                                                                    _playRange=_clipRangeA;
                                                                  }
                                                                  _clipVideoANotifier.add("kjut");
                                                                },
                                                                min: 0, max: _selVidCtr.value.duration.inSeconds/1,
                                                              ),
                                                            ),
                                                            Container(
                                                              child: Row(
                                                                children: <Widget>[
                                                                  Material(
                                                                    color: Colors.transparent,
                                                                    child: InkResponse(
                                                                      onTap: (){
                                                                        _curPlayingRange=1;
                                                                        if(_selVidCtr.value.isPlaying){
                                                                          _selVidCtr.pause();
                                                                        }
                                                                        else{
                                                                          _selVidCtr.pause().then((value){
                                                                            _playRange=_clipRangeA;
                                                                            _selVidCtr.play();
                                                                          });
                                                                        }
                                                                      },
                                                                      child: Container(
                                                                        padding: EdgeInsets.all(9),
                                                                        decoration: BoxDecoration(
                                                                          color: Colors.black,
                                                                          borderRadius: BorderRadius.circular(20),
                                                                        ),
                                                                        child: Icon(
                                                                          FlutterIcons.play_network_mco,
                                                                          size: 24,
                                                                          color: Colors.white,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  Expanded(
                                                                    child: Container(
                                                                      margin: EdgeInsets.only(left:12),
                                                                        child: Text(
                                                                          "Select the portion using the range slider",
                                                                          style: TextStyle(
                                                                              fontSize: 9,
                                                                              color: Colors.grey
                                                                          ),
                                                                          softWrap: true,
                                                                        )
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            )
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ):
                                                  Container()
                                            ],
                                          ),
                                        );
                                      },
                                    ),//clip video main
                                    StreamBuilder(
                                      stream: _clipVideoBNotifier.stream,
                                      builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                        return Container(
                                          child: Column(
                                            children: <Widget>[
                                              Container(
                                                child: Row(
                                                  children: <Widget>[
                                                    Container(
                                                      child: Checkbox(
                                                        value: _isClippedB,
                                                        onChanged: (bool _curVal){
                                                          _isClippedB= _curVal;
                                                          _clipVideoBNotifier.add("kjut");
                                                        },
                                                        activeColor: Colors.black,
                                                        checkColor: Colors.white,
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: GestureDetector(
                                                        onTap: (){
                                                          _isClippedB = !_isClippedB;
                                                          _clipVideoBNotifier.add("kjut");
                                                        },
                                                        child: Container(
                                                          margin:EdgeInsets.only(left:12),
                                                          child: Text(
                                                            "Use a part of this video as teaser on my wall",
                                                            style: TextStyle(
                                                                color: Colors.white
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              ),//checkbox
                                              (_isClippedB) ?
                                              TweenAnimationBuilder(
                                                tween: Tween<double>(
                                                    begin: 30, end: 0
                                                ),
                                                duration: Duration(milliseconds: 500),
                                                builder: (BuildContext __ctx, __curval, __){
                                                  return Container(
                                                    transform: Matrix4.translationValues(0, __curval, 0),
                                                    child: Column(
                                                      children: <Widget>[
                                                        Container(
                                                          child: RangeSlider(
                                                            activeColor: Colors.deepOrange,
                                                            inactiveColor: Colors.white24,
                                                            labels: RangeLabels(_clipRangeB.start.toString(), _clipRangeB.end.toString()),
                                                            values: _clipRangeB,
                                                            onChanged: (_curRange){
                                                              RangeValues _lastRange= _clipRangeB;
                                                              if(_lastRange.start!=_curRange.start){
                                                                _selVidCtr.seekTo(Duration(seconds: _clipRangeB.start.toInt()));
                                                              }
                                                              else{
                                                                _selVidCtr.seekTo(Duration(seconds: _clipRangeB.end.toInt()));
                                                              }
                                                              if(_curRange.end>(_curRange.start + 15)){
                                                                _clipRangeB=RangeValues(_curRange.start, (_curRange.start + 15));
                                                              }
                                                              else{
                                                                _clipRangeB=_curRange;
                                                              }

                                                              if(_curPlayingRange == 2){
                                                                _playRange=_clipRangeB;
                                                              }
                                                              _clipVideoBNotifier.add("kjut");
                                                            },
                                                            min: 0, max: _selVidCtr.value.duration.inSeconds/1,
                                                          ),
                                                        ),
                                                        Container(
                                                          child: Row(
                                                            children: <Widget>[
                                                              Material(
                                                                color: Colors.transparent,
                                                                child: InkResponse(
                                                                  onTap: (){
                                                                    _curPlayingRange=2;
                                                                    if(_selVidCtr.value.isPlaying){
                                                                      _selVidCtr.pause();
                                                                    }
                                                                    else{
                                                                      _selVidCtr.pause().then((value){
                                                                        _playRange=_clipRangeB;
                                                                        _selVidCtr.play();
                                                                      });
                                                                    }
                                                                  },
                                                                  child: Container(
                                                                    padding: EdgeInsets.all(9),
                                                                    decoration: BoxDecoration(
                                                                      color: Colors.black,
                                                                      borderRadius: BorderRadius.circular(20),
                                                                    ),
                                                                    child: Icon(
                                                                      FlutterIcons.play_network_mco,
                                                                      size: 24,
                                                                      color: Colors.white,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              Expanded(
                                                                child: Container(
                                                                    margin: EdgeInsets.only(left:12),
                                                                    child: Text(
                                                                      "Select the portion using the range slider",
                                                                      style: TextStyle(
                                                                          fontSize: 9,
                                                                          color: Colors.grey
                                                                      ),
                                                                      softWrap: true,
                                                                    )
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        )
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ):
                                              Container()
                                            ],
                                          ),
                                        );
                                      },
                                    ),//clip video for wall,
                                    Container(
                                      margin: EdgeInsets.only(top:7),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Container(
                                            margin:EdgeInsets.only(bottom: 4),
                                            child: Text(
                                              "Video poster",
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey
                                              ),
                                            ),
                                          ),//label
                                          Container(
                                            child: Row(
                                              children: <Widget>[
                                                Expanded(
                                                  child: Container(
                                                    child: Container(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: <Widget>[
                                                          StreamBuilder(
                                                            stream: _posterRangeNotifier.stream,
                                                            builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                                              return Container(
                                                                child: Slider(
                                                                  min: 0, max: _selVidCtr.value.duration.inSeconds/1,
                                                                  value: _selectedPosterTime.toDouble(),
                                                                  onChanged: (double _curval){
                                                                    _selectedPosterTime= _curval.toInt();
                                                                    _selVidCtr.seekTo(Duration(seconds: _selectedPosterTime));
                                                                    _posterRangeNotifier.add("kjut");
                                                                  },
                                                                ),
                                                              );
                                                            },
                                                          ),//slider
                                                          Container(
                                                            margin:EdgeInsets.only(top:2),
                                                            child: Row(
                                                              children: <Widget>[
                                                                Container(
                                                                  margin:EdgeInsets.only(right:16),
                                                                  child: Material(
                                                                    color: Colors.transparent,
                                                                    child: InkResponse(
                                                                      onTap: (){
                                                                        getVideoPoster();
                                                                      },
                                                                      child: Icon(
                                                                        FlutterIcons.airplay_mco,
                                                                        size: 24,
                                                                        color: Colors.white,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                                Expanded(
                                                                  child: Container(
                                                                    child:  Text(
                                                                      "Use slider to select a different poster",
                                                                      style: TextStyle(
                                                                          color: Colors.grey,
                                                                          fontSize: 9
                                                                      ),
                                                                    ),
                                                                  ),
                                                                )
                                                              ],
                                                            ),
                                                          )//label
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),//slider and label
                                                StreamBuilder(
                                                  stream:_videoPosterSelectedNotifier.stream,
                                                  builder: (BuildContext _ctx, _snapshot){
                                                    if(_successfulPoster==null){
                                                      return Container(
                                                        width: 50, height: 50,
                                                        decoration: BoxDecoration(
                                                          color: Color.fromRGBO(32, 32, 32, 1),
                                                          borderRadius: BorderRadius.circular(70)
                                                        ),
                                                      );
                                                    }
                                                    else{
                                                      return Container(
                                                        alignment: Alignment.center,
                                                        child: CircleAvatar(
                                                          radius: 50,
                                                          backgroundImage: FileImage(_successfulPoster),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                )//poster preview
                                              ],
                                            ),
                                          ), //slider and poster preview
                                        ],
                                      ),
                                    ),//select video poster

                                  ],
                                ),
                              );
                            },
                          );
                        }
                      },
                    )
                  ),
                  _kjToast,
                  Positioned(
                    bottom: _screenSize.height * .4, left: 0,
                    child: IgnorePointer(
                      ignoring: true,
                      child: StreamBuilder(
                        stream: _pageBusyCtr.stream,
                        builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                          return AnimatedOpacity(
                            opacity: _pageBusyOpacity,
                            duration: Duration(milliseconds: 300),
                            child: StreamBuilder(
                              stream: _pageBusyFloatingCtr.stream,
                              builder: (BuildContext __ctx, __snapshot){
                                return TweenAnimationBuilder(
                                  onEnd: (){
                                    if(_pageBusyAnimationEndVal == 0)
                                    _pageBusyAnimationEndVal=-12;
                                    else _pageBusyAnimationEndVal=0;
                                    _pageBusyFloatingCtr.add("kjut");
                                  },
                                  tween: Tween<double>(
                                    begin: -12, end: _pageBusyAnimationEndVal
                                  ),
                                  duration: Duration(seconds: 1),
                                  curve: Curves.easeInOut,
                                  builder: (BuildContext ___ctx, double _curVal, _){
                                    return Container(
                                      width: _screenSize.width, height: 111,
                                      alignment: Alignment.center,
                                      transform: Matrix4.translationValues(0, _curVal, 0),
                                      child: Stack(
                                        children: <Widget>[
                                          Container(
                                            alignment: Alignment.center,
                                            width: 120, height: 111,
                                            child: LiquidCustomProgressIndicator(
                                              direction: Axis.vertical,
                                              shapePath: globals.logoPath(Size(120, 111)),
                                              value: _pageBusyAmount,
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 46, left: 30,
                                            child: Container(
                                              width: 55, height: 42,
                                              decoration: BoxDecoration(
                                                  image: DecorationImage(
                                                      image: AssetImage("./images/camtv.png"),
                                                      fit: BoxFit.contain
                                                  )
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 30, left: 22,
                                            child: Text(
                                              _pageBusyText,
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 8,
                                                  fontFamily: "ubuntu"
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  )
                ],
              ),
            ),
            onFocusChange: (bool _isFocused){

            },
          ),
          //floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: StreamBuilder(
            builder: (BuildContext _ctx, _snapshot){
              if(_selectedVideoFile == null){
                return Container();
              }
              else{
                return TweenAnimationBuilder(
                  tween: Tween<double>(
                    begin: 30, end: -60
                  ),
                  duration: Duration(milliseconds: 1000),
                  curve: Curves.ease,
                  builder: (BuildContext __ctx, double _curval, __){
                    return Container(
                      transform: Matrix4.translationValues(_curval, _curval, 0),
                      child: FloatingActionButton(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(36)
                        ),
                        onPressed: (){

                        },
                        child: Icon(
                            FlutterIcons.content_save_mco,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                );
              }
            },
          ),
        ),
        onWillPop: ()async{
          if(_pageBusy==true){
            displayAlert(
                title: Text(
                  "Cancel Upload"
                ),
                content: Text(
                  "There's an active upload on this page \n do you wish to cancel this process and exit the page"
                ),
              action: [
                Container(
                  child: RaisedButton(
                    padding: EdgeInsets.only(top: 5, bottom: 5, right: 16, left: 16),
                    color: Colors.orange,
                    textColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)
                    ),
                    onPressed: (){
                      Navigator.pop(dlgCtx);
                    },
                    child: Text(
                      "No please",
                      style: TextStyle(
                        fontSize: 13
                      ),
                    ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(left: 12),
                  child: RaisedButton(
                    color: Colors.red,
                    textColor: Colors.white,
                    onPressed: (){
                      Navigator.pop(dlgCtx);
                      _pageBusy=false;
                      Navigator.pop(_pageContext);
                    },
                    child: Text(
                      "Exit Process",
                      style: TextStyle(

                      ),
                    ),
                  ),
                )
              ]
            );
          }
          else{
            Navigator.pop(_pageContext);
          }
          return false;
        }
    );
  }//route's build method

  StreamController _toastCtr= StreamController.broadcast();
  @override
  void dispose() {
    super.dispose();
    _toastCtr.close();
    _pageBusyCtr.close();
    _pageBusyFloatingCtr.close();
    _selectFileNotifier.close();
    _playpauseNotifier.close();
    _playerPosNotifier.close();
    _muteUnmuteNotifier.close();
    _postAboutCtr.dispose();
    _postTitleCtr.dispose();
    if(_selVidCtr.value.isPlaying) _selVidCtr.pause();
    _selVidCtr.dispose();
    _clipVideoANotifier.close();
    _clipVideoBNotifier.close();
    _videoPosterSelectedNotifier.close();
    _posterRangeNotifier.close();
  }// route's dispose method

  BuildContext dlgCtx;
  displayAlert({@required Widget title, @required Widget content,  List<Widget> action}){
    showDialog(
      barrierDismissible: false,
        context: _pageContext,
        builder: (BuildContext localCtx){
          dlgCtx=localCtx;
          return AlertDialog(
            title: title,
            content: content,
            actions: (action!=null && action.length>0) ? action: null,
            backgroundColor: Color.fromRGBO(20, 20, 20, 1),
            contentTextStyle: TextStyle(
              color: Colors.white
            ),
            titleTextStyle: TextStyle(
              fontFamily: "ubuntu",
              color: Colors.white
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Colors.grey
              )
            ),
          );
        }
    );
  }//displayAlert
}