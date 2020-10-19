import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';

import '../globals.dart' as globals;

class NewWallPost extends StatefulWidget{
  _NewWallPost createState(){
    return _NewWallPost();
  }
}

class _NewWallPost extends State<NewWallPost>{
  List<VideoPlayerController> _videoPlayerControllers=[];
  double _playerVolume=0;
  bool _playerPlaying=true;
  int _playerPos=0;

  List<CameraDescription> _cameras;
  Directory _appDir;
  Directory _wallTmpDir;

  @override
  initState(){
    super.initState();
    initCamera();
  }

  List<CameraController> _cameraControllers=[];
  bool _showCam=false;
  int _curCameraIndex=0;
  double _camAR=4/3;
  String _curCamSavePath="";
  initCamera()async{
    _cameras= await availableCameras();
    if(_cameras.length>0){
      _curCameraIndex=0;
    }
    _appDir= await getApplicationDocumentsDirectory();
    _wallTmpDir= Directory(_appDir.path + "/wall_dir/tmp");
    _wallTmpDir.create();
    List<FileSystemEntity> _tmpfs= _wallTmpDir.listSync();
    _tmpfs.forEach((_tmpFile) {
      _tmpFile.delete();
    });
  }

  int _postLimit=10;

  List<Map> _selectedFiles= List<Map>();
  StreamController _focFileChanged= StreamController.broadcast();
  int _focIndex=-1;

  Offset _cropPosOffSet= Offset(0, 0);
  double _cropwidth=0; double _cropheight=0;
  Offset _pointerPos;
  double _lastwidth=0; double _lastheight=0;

  bool _activeStillCam=false;
  bool _activeVideoCam=false;

  BuildContext _pageContext;
  Size _screenSize;
  globals.KjToast _kjToast;
  globals.KToolTip _kToolTip;
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize= MediaQuery.of(_pageContext).size;
    if(_kjToast == null){
      _kjToast= globals.KjToast(Color.fromRGBO(20, 20, 20, 1), _screenSize, _toastCtr, _screenSize.height*.4);
    }
    if(_kToolTip==null){
      _kToolTip= globals.KToolTip(_toolTipCtr);
    }
    return WillPopScope(
      child: Scaffold(
        backgroundColor: Color.fromRGBO(56, 56, 56, 1),
        appBar: AppBar(
          backgroundColor: Color.fromRGBO(28, 28, 28, 1),
          title: Text(
            "Create Wall Post",
            style: TextStyle(
                color: Colors.grey
            ),
          ),
        ),

        body: FocusScope(
          child: Container(
            child: Stack(
              children: <Widget>[
                Container(
                  height: _screenSize.height,
                  child: ListView(
                    physics: BouncingScrollPhysics(),
                    children: <Widget>[
                      Container(
                        height: _screenSize.height * .5,
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            Container(
                              child: StreamBuilder(
                                stream: _focFileChanged.stream,
                                builder: (BuildContext _focfCtx, AsyncSnapshot _focfShot){
                                  if(_selectedFiles.length == 0){
                                    return Container(
                                      width: _screenSize.width, height: double.infinity,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                          color: Color.fromRGBO(42, 42, 42, 1)
                                      ),
                                      child: GestureDetector(
                                        onTap: (){
                                          selFile();
                                        },
                                        child: Container(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: <Widget>[
                                              Container(
                                                key:_imageplaceholderKey,
                                                child: Icon(
                                                  FlutterIcons.image_evi,
                                                  color: Colors.grey,
                                                  size: 120,
                                                ),
                                              ),
                                              Container(
                                                margin: EdgeInsets.only(bottom: 3),
                                                child: Text(
                                                  "Select Videos and Images for your wall post",
                                                  style: TextStyle(
                                                      color: Colors.grey,
                                                      fontFamily: "ubuntu"
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                child: Text(
                                                  "Maximum of 10 files are allowed",
                                                  style: TextStyle(
                                                      fontStyle: FontStyle.italic,
                                                      color: Colors.grey
                                                  ),
                                                ),
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  else if(_selectedFiles[_focIndex]["type"] == "image"){
                                    return StreamBuilder(
                                      stream: _cropChangedNotifier.stream,
                                      builder: (BuildContext _cropCtx, AsyncSnapshot _cropShot){
                                        return RepaintBoundary(
                                          key: _cropKey,
                                          child: TweenAnimationBuilder(
                                            tween: Tween<double>(
                                                begin: 0, end: 1
                                            ),
                                            duration: Duration(milliseconds: 500),
                                            curve: Curves.easeInOut,
                                            builder: (BuildContext _twctx, double _twval, _){
                                              return Opacity(
                                                opacity: _twval,
                                                child: Container(
                                                  width: _screenSize.width, height: _screenSize.height * .5,
                                                  child: Stack(
                                                    fit: StackFit.expand,
                                                    children: <Widget>[
                                                      Positioned(
                                                          left: _cropPosOffSet.dx, top: _cropPosOffSet.dy,
                                                          child: Container(
                                                            width: _cropwidth,
                                                            height: _cropheight,
                                                            decoration: BoxDecoration(
                                                                image: DecorationImage(
                                                                    image: FileImage(File(_selectedFiles[_focIndex]["path"])),
                                                                    fit: BoxFit.fitHeight
                                                                )
                                                            ),
                                                          )
                                                      ),
                                                      Positioned(
                                                        left: 0, top: 0, width: _screenSize.width, height: _screenSize.height * .5,
                                                        child: cropMesh(),
                                                      ),
                                                      Positioned.fill(
                                                        child: GestureDetector(
                                                          onScaleUpdate: (ScaleUpdateDetails _sud){
                                                            double dx = _pointerPos.dx - _sud.localFocalPoint.dx;
                                                            double dy = _pointerPos.dy - _sud.localFocalPoint.dy;
                                                            Offset _locoffset = Offset(_cropPosOffSet.dx - dx, _cropPosOffSet.dy - dy);
                                                            _cropPosOffSet=_locoffset;
                                                            _pointerPos=_sud.localFocalPoint;
                                                            double _scaleDiff=_sud.scale - 1;
                                                            _cropwidth= _lastwidth + (_lastwidth * _scaleDiff);
                                                            _cropheight= _lastheight + (_lastheight * _scaleDiff);
                                                            _cropChangedNotifier.add("kjut");
                                                          },
                                                          onScaleStart: (ScaleStartDetails ssd) {
                                                            _pointerPos = ssd.localFocalPoint;
                                                            _cropMeshOpacity=1;
                                                            _cropMeshOpacityChangeNotifier.add("kjut");
                                                            _lastwidth=_cropwidth +0;
                                                            _lastheight=_cropheight +0;
                                                          },
                                                          onScaleEnd: (ScaleEndDetails _sed){
                                                            _cropMeshOpacity=0;
                                                            _cropMeshOpacityChangeNotifier.add("kjut");
                                                            fillCropRect();
                                                          },
                                                        ),
                                                      ),//gesture detector to scale and position for crop
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    );
                                  }
                                  else if(_selectedFiles[_focIndex]["type"] == "video"){
                                    resetVidPlayer();
                                    _videoPlayerControllers.add(
                                        VideoPlayerController.file(File(_selectedFiles[_focIndex]["path"]))
                                    );
                                    VideoPlayerController _focPlayer= _videoPlayerControllers.last;
                                    _focPlayer.initialize().then((value) {
                                      //add video controller listener
                                      _focPlayer.addListener(() {
                                        if(_focPlayer.value.isPlaying){
                                          _playerPos= _focPlayer.value.position.inSeconds;
                                          _playerPosChangeNotifier.add("kjut");
                                          int _selvidendpos=_selectedFiles[_focIndex]["end"];
                                          if(_playerPos == _selvidendpos){
                                            int _selvidstartpos=_selectedFiles[_focIndex]["start"];
                                            _focPlayer.seekTo(Duration(seconds: _selvidstartpos));
                                          }
                                        }
                                      });
                                      //end add vid ctr listener

                                      _videoARReadyNotifier.add(_focPlayer.value.aspectRatio);
                                      _focPlayer.setVolume(_playerVolume);
                                      _focPlayer.setLooping(true);
                                      if(_selectedFiles[_focIndex]["init"] == false){
                                        _selectedFiles[_focIndex]["init"]=true;
                                        int _viddur=_focPlayer.value.duration.inSeconds;
                                        if(_viddur>30){
                                          _selectedFiles[_focIndex]["end"]=30;
                                        }
                                        else _selectedFiles[_focIndex]["end"]= _viddur;
                                      }
                                      int _selvidstartpos=_selectedFiles[_focIndex]["start"];
                                      _focPlayer.seekTo(Duration(seconds: _selvidstartpos));
                                      if(_playerPlaying){
                                        _focPlayer.play();
                                      }
                                      _playerPosChangeNotifier.add("kjut");
                                    });
                                    return Container(
                                      child: Stack(
                                        children: <Widget>[
                                          Container(
                                            width: _screenSize.width, height: _screenSize.height * .5,
                                            alignment: Alignment.center,
                                            child: StreamBuilder(
                                              stream: _videoARReadyNotifier.stream,
                                              builder: (BuildContext _arctx, _arshot){
                                                if(_arshot.hasData){
                                                  return TweenAnimationBuilder(
                                                    tween: Tween<double>(
                                                        begin: 0, end: 1
                                                    ),
                                                    duration: Duration(milliseconds: 1000),
                                                    curve: Curves.easeInOut,
                                                    builder: (BuildContext _twctx, double _twval, _){
                                                      return Opacity(
                                                          opacity: _twval,
                                                          child: Container(
                                                            alignment: Alignment.center,
                                                            transform: Matrix4.translationValues(0, (_twval * 16) - 16, 0),
                                                            child: AspectRatio(
                                                              aspectRatio: _arshot.data,
                                                              child: Container(
                                                                  child: VideoPlayer(_focPlayer)
                                                              ),
                                                            ),
                                                          )
                                                      );
                                                    },
                                                  );
                                                }
                                                return Container(
                                                  width: _screenSize.width, height: _screenSize.height * .4,
                                                );
                                              },
                                            ),
                                          ),//the player
                                          Positioned.fill(
                                            child: StreamBuilder(
                                              stream: _showPlayBtnCtr.stream,
                                              builder: (BuildContext _showplayctx, AsyncSnapshot _showplayshot){
                                                return GestureDetector(
                                                  onTapDown: (_){
                                                    _showPlayBtnOpacity=1;
                                                    _showPlayBtnCtr.add("kjut");
                                                  },
                                                  onTapUp: (_){
                                                    Future.delayed(
                                                        Duration(milliseconds: 1000),
                                                            (){
                                                          _showPlayBtnOpacity=0;
                                                          _showPlayBtnCtr.add("kjut");
                                                        }
                                                    );
                                                  },
                                                  child: Container(
                                                    color: Color.fromRGBO(10, 10, 10, .2),
                                                    child: AnimatedOpacity(
                                                      opacity: _showPlayBtnOpacity,
                                                      duration: Duration(milliseconds: 500),
                                                      child: Container(
                                                        width: _screenSize.width, height: double.infinity,
                                                        alignment: Alignment.center,
                                                        child: StreamBuilder(
                                                          stream: _playPausectr.stream,
                                                          builder: (BuildContext _playctx, AsyncSnapshot _playshot){
                                                            return Container(
                                                              padding: EdgeInsets.only(left:24, right:24, top:24, bottom: 24),
                                                              decoration: BoxDecoration(
                                                                color: Color.fromRGBO(120, 120, 120, 1),
                                                                borderRadius: BorderRadius.circular(48),
                                                              ),
                                                              child: Material(
                                                                color: Colors.transparent,
                                                                child: InkResponse(
                                                                  onTap: (){
                                                                    if(_focPlayer.value.isPlaying){
                                                                      _playerPlaying=false;
                                                                      _focPlayer.pause().then((value){
                                                                        _playPausectr.add("kjut");
                                                                      });
                                                                    }
                                                                    else{
                                                                      _playerPlaying=true;
                                                                      _focPlayer.play().then((value) {
                                                                        _playPausectr.add("kjut");
                                                                      });
                                                                    }
                                                                    Future.delayed(
                                                                        Duration(milliseconds: 1000),
                                                                            (){
                                                                          _showPlayBtnOpacity=0;
                                                                          _showPlayBtnCtr.add("kjut");
                                                                        }
                                                                    );
                                                                  },
                                                                  child: Icon(
                                                                    _focPlayer.value.isPlaying ? FlutterIcons.pause_faw5s : FlutterIcons.play_faw5s,
                                                                    size: 32,
                                                                    color: Colors.white,
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ), //the play pause button
                                          Positioned(
                                            right: 12, bottom: 120,
                                            child: StreamBuilder(
                                              stream: _volChangeNotifier.stream,
                                              builder: (BuildContext _volCtx, AsyncSnapshot _volshot){
                                                return Container(
                                                  padding: EdgeInsets.only(left: 7, right: 7, top: 7, bottom: 7),
                                                  decoration: BoxDecoration(
                                                      color: Color.fromRGBO(32, 32, 32, 1),
                                                      borderRadius: BorderRadius.circular(18)
                                                  ),
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkResponse(
                                                      onTap: (){
                                                        if(_playerVolume == 0){
                                                          _playerVolume=1;
                                                          _focPlayer.setVolume(1);
                                                        }
                                                        else{
                                                          _playerVolume=0;
                                                          _focPlayer.setVolume(0);
                                                        }
                                                        _volChangeNotifier.add("kjut");
                                                      },
                                                      child: Icon(
                                                        _playerVolume==0 ? FlutterIcons.volume_off_faw5s : FlutterIcons.volume_up_faw5s,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),//volume button gesture
                                          Positioned(
                                            left: 16, bottom: 130,
                                            child: StreamBuilder(
                                              stream: _playerPosChangeNotifier.stream,
                                              builder: (BuildContext _platimeCtx, AsyncSnapshot _playtimeShot){
                                                return Container(
                                                  padding: EdgeInsets.only(top: 5, bottom: 5, left: 12, right: 12),
                                                  decoration: BoxDecoration(
                                                      color: Color.fromRGBO(32, 32, 32, .8),
                                                      borderRadius: BorderRadius.circular(7)
                                                  ),
                                                  child: Text(
                                                    _playerPos>0 ? globals.convSecToMin(_playerPos) + " / " + globals.convSecToMin(_focPlayer.value.duration.inSeconds) : "00:00 / 00:00",
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontFamily: "ubuntu"
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),//video time data display
                                          Positioned(
                                            left: 0,
                                            bottom: 70,
                                            child: StreamBuilder(
                                              stream: _videoARReadyNotifier.stream,
                                              builder: (BuildContext _sliderCtx, _sliderShot){
                                                if(_sliderShot.hasData){
                                                  return Container(
                                                    width: _screenSize.width,
                                                    child: StreamBuilder(
                                                      stream: _playerPosChangeNotifier.stream,
                                                      builder: (BuildContext _posCtx, AsyncSnapshot _posShot){
                                                        return Container(
                                                          child: Column(
                                                            children: <Widget>[
                                                              Container(
                                                                child: Slider(
                                                                  value: (_focPlayer!=null && _focPlayer.value.initialized) ? (_playerPos/1) : 0,
                                                                  min: 0, max: (_focPlayer!=null && _focPlayer.value.initialized) ? (_focPlayer.value.duration.inSeconds/1) : 0,
                                                                  onChanged: (_){

                                                                  },
                                                                  label: "$_playerPos",
                                                                ),
                                                              ),
                                                              Container(
                                                                padding:EdgeInsets.only(top:3, bottom:3),
                                                                child: Text(
                                                                  "K",
                                                                  style: TextStyle(
                                                                      color: Colors.transparent
                                                                  ),
                                                                ),
                                                              )
                                                            ],
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  );
                                                }
                                                return Container(
                                                  width: _screenSize.width,
                                                );
                                              },
                                            ),
                                          ),//player time line
                                          Positioned(
                                            left: 0,
                                            bottom: 70,
                                            child: StreamBuilder(
                                              stream: _videoARReadyNotifier.stream,
                                              builder: (BuildContext _sliderCtx, _sliderShot){
                                                if(_sliderShot.hasData){
                                                  return Container(
                                                    width: _screenSize.width,
                                                    child: StreamBuilder(
                                                      stream: _playerPosChangeNotifier.stream,
                                                      builder: (BuildContext _posCtx, AsyncSnapshot _posShot){
                                                        return Container(
                                                          child: Column(
                                                            children: <Widget>[
                                                              Container(
                                                                child: RangeSlider(
                                                                  min: 0, max: (_focPlayer!=null && _focPlayer.value.initialized)? (_focPlayer.value.duration.inSeconds/1) : 0,
                                                                  onChanged: (RangeValues _rv){
                                                                    if(_rv.end > _rv.start + 30){
                                                                      _selectedFiles[_focIndex]["start"]= _rv.start.toInt();
                                                                      _selectedFiles[_focIndex]["end"]= 30;
                                                                    }
                                                                    else{
                                                                      _selectedFiles[_focIndex]["start"]= _rv.start.toInt();
                                                                      _selectedFiles[_focIndex]["end"]= _rv.end.toInt();
                                                                    }
                                                                    _focPlayer.seekTo(Duration(seconds: _rv.start.toInt()));
                                                                    _playerPosChangeNotifier.add("kjut");
                                                                  },
                                                                  values: (_focPlayer!=null && _focPlayer.value.initialized) ? RangeValues(_selectedFiles[_focIndex]["start"]/1, _selectedFiles[_focIndex]["end"]/1) : RangeValues(0,0),
                                                                ),
                                                              ),
                                                              Container(
                                                                padding:EdgeInsets.only(top:3, bottom:3, left:7, right: 7),
                                                                decoration:BoxDecoration(
                                                                    color: Color.fromRGBO(20, 20, 20, 1),
                                                                    borderRadius: BorderRadius.circular(12)
                                                                ),
                                                                child: Text(
                                                                  "Select 30 secs. max of this video",
                                                                  style: TextStyle(
                                                                      color: Colors.white
                                                                  ),
                                                                ),
                                                              )
                                                            ],
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  );
                                                }
                                                return Container(
                                                  width: _screenSize.width,
                                                );
                                              },
                                            ),
                                          ),//player time line
                                        ],
                                      ),
                                    );
                                  }
                                  return Container();
                                },
                              ),
                            ),//the currently focused media

                            Positioned(
                              left: 0, bottom: 5,
                              child: Container(
                                padding: EdgeInsets.only(left: 16, right: 16, top: 7, bottom: 7),
                                width: _screenSize.width,
                                child: Row(
                                  children: <Widget>[
                                    StreamBuilder(
                                      stream: _focFileChanged.stream,
                                      builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                        if(_selectedFiles.length>1){
                                          return TweenAnimationBuilder(
                                            tween: Tween<double>(begin: 0, end: 1),
                                            duration: Duration(milliseconds: 500),
                                            builder: (BuildContext _ctx, double _twval, _){
                                              return Opacity(
                                                opacity: _twval,
                                                child: Container(
                                                  padding: EdgeInsets.only(left: 3, right: 3),
                                                  decoration:BoxDecoration(
                                                      borderRadius: BorderRadius.circular(24),
                                                      color: Color.fromRGBO(32, 32, 32, 1)
                                                  ),
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.center,
                                                    children: <Widget>[
                                                      Container(
                                                        margin:EdgeInsets.only(right:7),
                                                        child: Material(
                                                          color: Colors.transparent,
                                                          child: InkResponse(
                                                            onTap: (){
                                                              prevSlide();
                                                            },
                                                            child: Container(
                                                              padding: EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 12),
                                                              child: Icon(
                                                                FlutterIcons.left_ant,
                                                                color: Color.fromRGBO(200, 200, 200, 1),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),//left arrow nav
                                                      Container(
                                                        child: Material(
                                                          color: Colors.transparent,
                                                          child: InkResponse(
                                                            onTap: (){
                                                              nextSlide();
                                                            },
                                                            child: Container(
                                                              padding: EdgeInsets.only(left: 12, right:12, top: 12, bottom: 12),
                                                              child: Icon(
                                                                FlutterIcons.right_ant,
                                                                color: Color.fromRGBO(200, 200, 200, 1),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),//right arrow nav
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        }
                                        return Container();
                                      },
                                    ),//page nav buttons

                                    Expanded(
                                      child: Container(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: <Widget>[
                                            Material(
                                              color:Colors.transparent,
                                              child: InkResponse(
                                                onTap: (){
                                                  selFile();
                                                },
                                                child: Container(
                                                  padding: EdgeInsets.only(top: 12, right:12, left: 12, bottom: 12),
                                                  decoration: BoxDecoration(
                                                      color: Color.fromRGBO(32, 32, 32, 1),
                                                      borderRadius: BorderRadius.circular(32)
                                                  ),
                                                  child: Icon(
                                                      FlutterIcons.addfile_ant,
                                                      color: Color.fromRGBO(200, 200, 200, 1)
                                                  ),
                                                ),
                                              ),
                                            ), //add file gesture detector
                                            Container(
                                              margin: EdgeInsets.only(left: 12, right: 12),
                                              child: Material(
                                                color:Colors.transparent,
                                                child: InkResponse(
                                                  onTap: (){
                                                    if(_selectedFiles.length<_postLimit){
                                                      resetVidPlayer();
                                                      resetCams();
                                                      _cameraControllers.add(CameraController(_cameras[_curCameraIndex], ResolutionPreset.high));
                                                      CameraController _focCam= _cameraControllers.last;
                                                      _focCam.initialize().then((value) {
                                                        _camAR=_focCam.value.aspectRatio;
                                                        _showCam=true;
                                                        _activeStillCam=true;
                                                        _showCamCtr.add("kjut");
                                                      });
                                                    }
                                                    else{
                                                      _kjToast.showToast(
                                                          text: "Maximum limit of $_postLimit files have been reached!",
                                                          duration: Duration(seconds: 3)
                                                      );
                                                    }
                                                  },
                                                  child: Container(
                                                    padding: EdgeInsets.only(top: 12, right:12, left: 12, bottom: 12),
                                                    decoration: BoxDecoration(
                                                        color: Color.fromRGBO(32, 32, 32, 1),
                                                        borderRadius: BorderRadius.circular(32)
                                                    ),
                                                    child: Icon(
                                                        FlutterIcons.add_a_photo_mdi,
                                                        color: Color.fromRGBO(200, 200, 200, 1)
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ), //add photo
                                            Material(
                                              color:Colors.transparent,
                                              child: InkResponse(
                                                onTap: (){
                                                  if(_selectedFiles.length<_postLimit){
                                                    resetVidPlayer();
                                                    resetCams();
                                                    _cameraControllers.add(CameraController(_cameras[_curCameraIndex], ResolutionPreset.high, enableAudio: true));
                                                    CameraController _focCam=_cameraControllers.last;
                                                    _focCam.initialize().then((value) {
                                                      _camAR=_focCam.value.aspectRatio;
                                                      _showVidCam=true;
                                                      _activeVideoCam=true;
                                                      _showVidCamCtr.add("kjut");
                                                      _camRecordTime=0;
                                                      clearTaken();
                                                    });
                                                  }
                                                  else{
                                                    _kjToast.showToast(
                                                        text: "Maximum limit of $_postLimit files have been reached!",
                                                        duration: Duration(seconds: 3)
                                                    );
                                                  }
                                                },
                                                child: Container(
                                                  padding: EdgeInsets.only(top: 12, right:12, left: 12, bottom: 12),
                                                  decoration: BoxDecoration(
                                                      color: Color.fromRGBO(32, 32, 32, 1),
                                                      borderRadius: BorderRadius.circular(32)
                                                  ),
                                                  child: Icon(
                                                      FlutterIcons.video_plus_mco,
                                                      color: Color.fromRGBO(200, 200, 200, 1)
                                                  ),
                                                ),
                                              ),
                                            ), //add video gesture detector
                                          ],
                                        ),
                                      ),
                                    ), //image selection options
                                  ],
                                ),
                              ),
                            ),//page nav buttons, image selection option,
                            Positioned(
                              left: 0, top: 0,
                              child: StreamBuilder(
                                stream: _focFileChanged.stream,
                                builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                  return AnimatedOpacity(
                                    opacity: _focIndex>-1 && _selectedFiles[_focIndex]["type"]=="image" ? 1 : 0,
                                    duration: Duration(milliseconds: 500),
                                    child: StreamBuilder(
                                      stream: _globCropCtr.stream,
                                      builder: (BuildContext _ctx, AsyncSnapshot _cropShot){
                                        if(_cropShot.hasData){
                                          return Container(
                                            width: 150, height: 120,
                                            decoration: BoxDecoration(
                                                image: DecorationImage(
                                                    image: MemoryImage(_cropShot.data),
                                                    fit: BoxFit.contain
                                                )
                                            ),
                                          );
                                        }
                                        return Container(
                                          width: 150, height: 120,
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ), //sample crop display
                            Positioned(
                                right: 12, top: 12,
                                child: StreamBuilder(
                                  stream: _focFileChanged.stream,
                                  builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                    if(_selectedFiles.length==0){
                                      return Container();
                                    }
                                    return TweenAnimationBuilder(
                                      tween: Tween<double>(
                                          begin: 0, end: 1
                                      ),
                                      duration: Duration(milliseconds: 300),
                                      builder: (BuildContext _ctx, double _twval, _){
                                        return Opacity(
                                          opacity: _twval,
                                          child: Container(
                                            padding: EdgeInsets.all(9),
                                            decoration: BoxDecoration(
                                                color: Color.fromRGBO(20, 20, 20, 1),
                                                borderRadius: BorderRadius.circular(18)
                                            ),
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkResponse(
                                                onTap: (){
                                                  if(_selectedFiles.length>0){
                                                    resetVidPlayer();
                                                    int _curindex=_focIndex + 0; //save the current index
                                                    _selectedFiles.removeAt(_curindex);
                                                    if(_focIndex>0) _focIndex--;
                                                    else _focIndex= _selectedFiles.length - 1;

                                                    if(_focIndex>-1 && _selectedFiles[_focIndex]["type"] == "image"){
                                                      cropImage();
                                                      setCropRect();
                                                    }
                                                    _focFileChanged.add("kjut");
                                                  }
                                                },
                                                child: Container(
                                                  padding: EdgeInsets.all(7),
                                                  child: Icon(
                                                    FlutterIcons.close_faw,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                )
                            ), //remove an item from selection
                            StreamBuilder(
                              stream: _showCamCtr.stream,
                              builder: (BuildContext _camctx, AsyncSnapshot _camshot){
                                if(_camshot.hasData && _showCam){
                                  return TweenAnimationBuilder(
                                    tween: Tween<double>(begin: 0, end: 1),
                                    duration: Duration(milliseconds: 700),
                                    curve: Curves.easeInOut,
                                    builder: (BuildContext _ctx, double _twval, _){
                                      return Opacity(
                                        opacity: _twval,
                                        child: Container(
                                          width: _screenSize.width, height: double.infinity,
                                          transform: Matrix4.translationValues(0, (_twval * 18) - 18, 0),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: <Widget>[
                                              Container(
                                                  width:double.infinity, height: double.infinity,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                      color: Colors.white
                                                  ),
                                                  child: StreamBuilder(
                                                    stream: _camshotNotifier.stream,
                                                    builder: (BuildContext _ctx, _playpreviewshot){
                                                      if(_camshotTaken){
                                                        return Container(
                                                          width: _screenSize.width,
                                                          height: double.infinity,
                                                          decoration: BoxDecoration(
                                                              image: DecorationImage(
                                                                  image: FileImage(File(_curCamSavePath)),
                                                                  fit: BoxFit.contain
                                                              )
                                                          ),
                                                        );
                                                      }
                                                      else{
                                                        return Container(
                                                          decoration: BoxDecoration(
                                                              color: Colors.black
                                                          ),
                                                          child: Container(
                                                            width: _screenSize.width,
                                                            alignment: Alignment.center,
                                                            child: AspectRatio(
                                                              aspectRatio: _camAR,
                                                              child: CameraPreview(
                                                                  _cameraControllers.last
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                  )
                                              ),// render camera image
                                              Positioned(
                                                left: 0, bottom: 12,
                                                width: _screenSize.width,
                                                child: Container(
                                                  width: _screenSize.width,
                                                  alignment: Alignment.center,
                                                  child: Container(
                                                    width: 70, height: 70,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                        color: Color.fromRGBO(62, 62, 62, 1),
                                                        borderRadius: BorderRadius.circular(50)
                                                    ),
                                                    child: Material(
                                                      color: Colors.transparent,
                                                      child: InkResponse(
                                                        onTap: (){
                                                          if(_camshotTaken){
                                                            clearTaken();
                                                            _camshotTaken=false;
                                                            _camshotNotifier.add("kjut");
                                                          }
                                                          else{
                                                            int _curTime=DateTime.now().millisecondsSinceEpoch;
                                                            _curCamSavePath= _wallTmpDir.path + "/$_curTime.jpg";
                                                            _cameraControllers.last.takePicture(_curCamSavePath).then((value){
                                                              _camshotTaken=true;
                                                              _camshotNotifier.add("kjut");
                                                            });
                                                          }
                                                        },
                                                        child: Container(
                                                          width: 50, height: 50,
                                                          decoration: BoxDecoration(
                                                              color: Color.fromRGBO(20, 20, 20, 1),
                                                              borderRadius: BorderRadius.circular(40)
                                                          ),
                                                          child: StreamBuilder(
                                                            stream: _camshotNotifier.stream,
                                                            builder: (BuildContext _ctx, _saveshot){
                                                              if(_camshotTaken){
                                                                return TweenAnimationBuilder(
                                                                  tween: Tween<double>(begin: 0, end: 1),
                                                                  duration: Duration(milliseconds: 500),
                                                                  builder: (BuildContext _ctx, double _twval, _){
                                                                    return Opacity(
                                                                      opacity: _twval,
                                                                      child: Icon(
                                                                        FlutterIcons.camera_retake_mco,
                                                                        color: Colors.white,
                                                                        size: 12,
                                                                      ),
                                                                    );
                                                                  },
                                                                );
                                                              }
                                                              return Container();
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ), //camera click btn
                                              Positioned(
                                                right: 12, top: 12,
                                                child: Container(
                                                  padding: EdgeInsets.all(9),
                                                  decoration: BoxDecoration(
                                                      color: Color.fromRGBO(20, 20, 20, 1),
                                                      borderRadius: BorderRadius.circular(24)
                                                  ),
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkResponse(
                                                      radius: 60,
                                                      onTap: (){
                                                        hideCamApp();
                                                      },
                                                      child: Container(
                                                        padding: EdgeInsets.all(5),
                                                        child: Icon(
                                                          FlutterIcons.close_faw,
                                                          color: Colors.white,
                                                          size: 14,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ), //dismiss
                                              Positioned(
                                                right: 12, top: 60,
                                                child: StreamBuilder(
                                                  stream: _camshotNotifier.stream,
                                                  builder: (BuildContext _ctx, _showSaveShot){
                                                    if(_camshotTaken){
                                                      return TweenAnimationBuilder(
                                                        tween: Tween<double>(begin: 0, end: 1),
                                                        duration: Duration(milliseconds: 1000),
                                                        curve: Curves.easeInOut,
                                                        builder: (BuildContext _ctx, double _twval, _){
                                                          return Opacity(
                                                            opacity: _twval,
                                                            child: Container(
                                                              transform: Matrix4.translationValues((_twval * 12) - 12, (_twval * 12) - 12, 0),
                                                              padding: EdgeInsets.all(5),
                                                              decoration: BoxDecoration(
                                                                  color: Color.fromRGBO(20, 20, 20, 1),
                                                                  borderRadius: BorderRadius.circular(20)
                                                              ),
                                                              child: Material(
                                                                color: Colors.transparent,
                                                                child: InkResponse(
                                                                  radius: 60,
                                                                  onTap: (){
                                                                    if(_selectedFiles.length< _postLimit){
                                                                      _selectedFiles.add({
                                                                        "type": "image",
                                                                        "path": _curCamSavePath,
                                                                        "x": 0.0, "y":0.0, "width": _screenSize.width, "height":_screenSize.height * .5
                                                                      });
                                                                      _focIndex++;
                                                                      setCropRect();
                                                                      _focFileChanged.add("kjut");
                                                                      Future.delayed(
                                                                          Duration(milliseconds: 300),
                                                                              (){
                                                                            cropImage();
                                                                          }
                                                                      );
                                                                    }
                                                                    _curCamSavePath="";
                                                                    _showCam=false;
                                                                    _showCamCtr.add("kjut");
                                                                    _camshotTaken=false;
                                                                  },
                                                                  child: Container(
                                                                    padding: EdgeInsets.all(5),
                                                                    child: Icon(
                                                                      FlutterIcons.check_fea,
                                                                      color: Colors.white,
                                                                      size: 15,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      );
                                                    }
                                                    return Container();
                                                  },
                                                ),
                                              ),//save cam shot
                                              Positioned(
                                                left: 12, bottom: 12,
                                                child: Container(
                                                  padding: EdgeInsets.all(9),
                                                  decoration: BoxDecoration(
                                                      color: Color.fromRGBO(20, 20, 20, 1),
                                                      borderRadius: BorderRadius.circular(24)
                                                  ),
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkResponse(
                                                      radius: 60,
                                                      onTap: (){
                                                        if(_curCameraIndex<_cameras.length-1){
                                                          _curCameraIndex++;
                                                        }
                                                        else{
                                                          _curCameraIndex=0;
                                                        }
                                                        resetCams();
                                                        _cameraControllers.add(CameraController(_cameras[_curCameraIndex], ResolutionPreset.high));
                                                        CameraController _focCam= _cameraControllers.last;
                                                        _focCam.initialize().then((value){
                                                          clearTaken();
                                                          _showCam=true;
                                                          _showCamCtr.add("kjut");
                                                          _camshotTaken=false;
                                                          _camshotNotifier.add("kjut");
                                                        });
                                                      },
                                                      child: Container(
                                                        padding: EdgeInsets.all(5),
                                                        child: Icon(
                                                          FlutterIcons.rotate_3d_variant_mco,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ), //swap cameras
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                }
                                return Container();
                              },
                            ),//still camera app
                            StreamBuilder(
                              stream: _showVidCamCtr.stream,
                              builder: (BuildContext _camctx, AsyncSnapshot _camshot){
                                if(_camshot.hasData && _showVidCam){
                                  return TweenAnimationBuilder(
                                    tween: Tween<double>(begin: 0, end: 1),
                                    duration: Duration(milliseconds: 700),
                                    curve: Curves.easeInOut,
                                    builder: (BuildContext _ctx, double _twval, _){
                                      return Opacity(
                                        opacity: _twval,
                                        child: Container(
                                          width: _screenSize.width, height: double.infinity,
                                          transform: Matrix4.translationValues(0, (_twval * 18) - 18, 0),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: <Widget>[
                                              Container(
                                                  width:double.infinity, height: double.infinity,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                      color: Colors.black
                                                  ),
                                                  child: StreamBuilder(
                                                    stream: _camrecordNotifier.stream,
                                                    builder: (BuildContext _ctx, _playpreviewshot){
                                                      return Container(
                                                        alignment: Alignment.center,
                                                        child: AspectRatio(
                                                            aspectRatio: _camAR,
                                                            child: CameraPreview(
                                                                _cameraControllers.last
                                                            )
                                                        ),
                                                      );
                                                    },
                                                  )
                                              ),// render camera image
                                              Positioned(
                                                left: 0, bottom: 12,
                                                width: _screenSize.width,
                                                child: Container(
                                                  width: _screenSize.width,
                                                  alignment: Alignment.center,
                                                  child: Container(
                                                    width: 70, height: 70,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                        color: Color.fromRGBO(62, 62, 62, 1),
                                                        borderRadius: BorderRadius.circular(50)
                                                    ),
                                                    child: Material(
                                                      color: Colors.transparent,
                                                      child: InkResponse(
                                                        onTap: (){
                                                          if(_camRecordTime<30){
                                                            if(_camRecording){
                                                              _cameraControllers.last.pauseVideoRecording().then((value) {
                                                                _camRecording=false;
                                                                _addRecorded=true;
                                                                _addRecordednotifier.add("kjut");
                                                              });
                                                            }
                                                            else{
                                                              int _curTime=DateTime.now().millisecondsSinceEpoch;
                                                              _curCamSavePath= _wallTmpDir.path + "/$_curTime.mp4";
                                                              _camRecording=true;
                                                              if(_camRecordTime==0){
                                                                _cameraControllers.last.startVideoRecording(_curCamSavePath).then((value) {
                                                                  camRecordTimer();
                                                                  _addRecorded=false;
                                                                  _addRecordednotifier.add("kjut");
                                                                });
                                                              }
                                                              else{
                                                                _cameraControllers.last.resumeVideoRecording().then((value) {
                                                                  camRecordTimer();
                                                                });
                                                              }
                                                            }
                                                          }
                                                        },
                                                        child: Container(
                                                          width: 50, height: 50,
                                                          decoration: BoxDecoration(
                                                              color: Color.fromRGBO(20, 20, 20, 1),
                                                              borderRadius: BorderRadius.circular(40)
                                                          ),
                                                          child: StreamBuilder(
                                                            stream: _camrecordNotifier.stream,
                                                            builder: (BuildContext _ctx, _saveshot){
                                                              if(_camRecording){
                                                                return TweenAnimationBuilder(
                                                                  tween: Tween<double>(begin: 0, end: 1),
                                                                  duration: Duration(milliseconds: 500),
                                                                  builder: (BuildContext _ctx, double _twval, _){
                                                                    return Opacity(
                                                                        opacity: _twval,
                                                                        child: Container(
                                                                          width: 12, height: 12,
                                                                          decoration: BoxDecoration(
                                                                              color: Colors.red,
                                                                              borderRadius: BorderRadius.circular(12)
                                                                          ),
                                                                        )
                                                                    );
                                                                  },
                                                                );
                                                              }
                                                              return Container(
                                                                width: 12, height: 12,
                                                                decoration: BoxDecoration(
                                                                    color: Colors.black,
                                                                    borderRadius: BorderRadius.circular(12)
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ), //camera click btn
                                              Positioned(
                                                right: 12, top: 12,
                                                child: Container(
                                                  padding: EdgeInsets.all(9),
                                                  decoration: BoxDecoration(
                                                      color: Color.fromRGBO(20, 20, 20, 1),
                                                      borderRadius: BorderRadius.circular(24)
                                                  ),
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkResponse(
                                                      radius: 60,
                                                      onTap: (){
                                                        hideVideoCamApp();
                                                      },
                                                      child: Container(
                                                        padding: EdgeInsets.all(5),
                                                        child: Icon(
                                                          FlutterIcons.close_faw,
                                                          color: Colors.white,
                                                          size: 14,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ), //dismiss
                                              Positioned(
                                                right: 12, top: 60,
                                                child: StreamBuilder(
                                                  stream: _addRecordednotifier.stream,
                                                  builder: (BuildContext _ctx, _showSaveShot){
                                                    if(_addRecorded){
                                                      return TweenAnimationBuilder(
                                                        tween: Tween<double>(begin: 0, end: 1),
                                                        duration: Duration(milliseconds: 1000),
                                                        curve: Curves.easeInOut,
                                                        builder: (BuildContext _ctx, double _twval, _){
                                                          return Opacity(
                                                            opacity: _twval,
                                                            child: Container(
                                                              transform: Matrix4.translationValues((_twval * 12) - 12, (_twval * 12) - 12, 0),
                                                              padding: EdgeInsets.all(5),
                                                              decoration: BoxDecoration(
                                                                  color: Color.fromRGBO(20, 20, 20, 1),
                                                                  borderRadius: BorderRadius.circular(20)
                                                              ),
                                                              child: Material(
                                                                color: Colors.transparent,
                                                                child: InkResponse(
                                                                  radius: 60,
                                                                  onTap: ()async{
                                                                    if(_selectedFiles.length< _postLimit){
                                                                      if(_cameraControllers.last.value.isRecordingPaused){
                                                                        await _cameraControllers.last.stopVideoRecording();
                                                                      }
                                                                      _selectedFiles.add({
                                                                        "type": "video",
                                                                        "path": _curCamSavePath,
                                                                        "start": 0, "end": 0,
                                                                        "init": false
                                                                      });
                                                                      _focIndex= _selectedFiles.length - 1;
                                                                      _focFileChanged.add("kjut");
                                                                    }
                                                                    _showVidCam=false;
                                                                    _showVidCamCtr.add("kjut");
                                                                    _addRecorded=false;
                                                                  },
                                                                  child: Container(
                                                                    padding: EdgeInsets.all(5),
                                                                    child: Icon(
                                                                      FlutterIcons.check_fea,
                                                                      color: Colors.white,
                                                                      size: 15,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      );
                                                    }
                                                    return Container();
                                                  },
                                                ),
                                              ),//save recorded
                                              Positioned(
                                                left: 12, bottom: 12,
                                                child: Container(
                                                  padding: EdgeInsets.all(9),
                                                  decoration: BoxDecoration(
                                                      color: Color.fromRGBO(20, 20, 20, 1),
                                                      borderRadius: BorderRadius.circular(24)
                                                  ),
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkResponse(
                                                      radius: 60,
                                                      onTap: (){
                                                        if(_curCameraIndex<_cameras.length-1){
                                                          _curCameraIndex++;
                                                        }
                                                        else{
                                                          _curCameraIndex=0;
                                                        }
                                                        resetCams();
                                                        _cameraControllers.add(CameraController(_cameras[_curCameraIndex], ResolutionPreset.high));
                                                        CameraController _focCam=_cameraControllers.last;
                                                        _focCam.initialize().then((value){
                                                          _camRecordTime=0;
                                                          _camrecordNotifier.add("kjut");
                                                          _addRecorded=false;
                                                          _addRecordednotifier.add("kjut");
                                                          clearTaken();
                                                          _showVidCam=true;
                                                          _showVidCamCtr.add("kjut");
                                                        });
                                                      },
                                                      child: Container(
                                                        padding: EdgeInsets.all(5),
                                                        child: Icon(
                                                          FlutterIcons.rotate_3d_variant_mco,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ), //swap cameras
                                              Positioned(
                                                left: 16, bottom: 100,
                                                width: _screenSize.width - 32,
                                                child: StreamBuilder(
                                                  stream: _camrecordNotifier.stream,
                                                  builder: (BuildContext _ctx, AsyncSnapshot _recordShot){
                                                    return Container(
                                                      width: double.infinity,
                                                      height: 3,
                                                      alignment: Alignment.centerLeft,
                                                      decoration: BoxDecoration(
                                                          color: Color.fromRGBO(20, 20, 20, 1),
                                                          borderRadius: BorderRadius.circular(7)
                                                      ),
                                                      child: AnimatedContainer(
                                                        duration: Duration(milliseconds: 50),
                                                        curve: Curves.easeInOut,
                                                        width: _camRecordTime * (_screenSize.width-32)/30,
                                                        height: 3,
                                                        decoration: BoxDecoration(
                                                            color: Colors.red,
                                                            borderRadius: BorderRadius.circular(7)
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),//camera recording timeline
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                }
                                return Container();
                              },
                            )//video camera app
                          ],
                        ),
                      ), //Image and video editor
                      Container(
                          margin: EdgeInsets.only(top: 16, left: 16, right: 16),
                          width: _screenSize.width - 32,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                margin:EdgeInsets.only(bottom: 5),
                                child: Text(
                                  "Post text",
                                  style: TextStyle(
                                      color: Colors.grey
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.only(left: 12, right: 12),
                                decoration: BoxDecoration(
                                    color: Color.fromRGBO(32, 32, 32, 1),
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(color: Colors.grey)
                                ),
                                child: TextField(
                                  key: _textKey,
                                  controller: _postTextCtr,
                                  style: TextStyle(
                                      color: Colors.white
                                  ),
                                  maxLines: null, minLines: 3,
                                  decoration: InputDecoration(
                                      hintText: "Say something about this post",
                                      hintStyle: TextStyle(
                                          color: Colors.grey
                                      ),
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none
                                  ),
                                  textInputAction: TextInputAction.newline,
                                ),
                              )
                            ],
                          )
                      ), //post text
                      Container(
                        margin: EdgeInsets.only(top:9),
                        padding: EdgeInsets.only(left: 16, right: 16),
                        child: Container(
                          padding: EdgeInsets.only(top: 5, bottom: 5),
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(30, 30, 30, 1),
                            borderRadius: BorderRadius.circular(9),

                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkResponse(
                              radius: 300,
                              onTap: (){
                                createServerPost();
                              },
                              child: Container(
                                padding: EdgeInsets.only(top: 9, bottom: 9),
                                child: Text(
                                  "POST",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: "ubuntu",
                                      fontSize: 16
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ), //postButton
                    ],
                  ),
                ),
                _kjToast,
                Positioned(
                  bottom: 0, left: 0,
                  child: IgnorePointer(
                    child: StreamBuilder(
                      stream: globals.globalWallPostCtr.stream,
                      builder: (BuildContext _ctx, AsyncSnapshot _gpostShot){
                        if(globals.wallPostData["state"] == "active"){
                          return TweenAnimationBuilder(
                            tween: Tween<double>(begin: 1, end: 2),
                            duration: Duration(milliseconds: 700),
                            curve: Curves.elasticOut,
                            builder: (BuildContext _ctx, double _twval, _){
                              return Opacity(
                                opacity: (_twval - 1)<0 ? 0 : (_twval - 1)>1 ? 1 : _twval - 1,
                                child: Transform.scale(
                                  scale: _twval - 1,
                                  child: Container(
                                    width: _screenSize.width,
                                    padding: EdgeInsets.only(top: 12, bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Color.fromRGBO(32, 32, 32, 1),
                                      borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(12),
                                          topRight: Radius.circular(12)
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Container(
                                          width: _screenSize.width,
                                          padding:EdgeInsets.only(left: 16, right: 16, top: 9, bottom: 9),
                                          decoration: BoxDecoration(
                                              border: Border(
                                                  bottom: BorderSide(color: Color.fromRGBO(120, 120, 120, 1))
                                              )
                                          ),
                                          child: Text(
                                            globals.wallPostData["title"],
                                            style: TextStyle(
                                                color: Colors.white
                                            ),
                                          ),
                                        ), //title
                                        Container(
                                            padding: EdgeInsets.only(left: 16, right: 16, top: 5, bottom: 20),
                                            child: Text(
                                              globals.wallPostData["body"],
                                              style: TextStyle(
                                                  color: Colors.white
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            )
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }
                        return Container();
                      },
                    ),
                  ),
                ),
                _kToolTip
              ],
            ),
          ),
          onFocusChange: (bool _isFocused){

          },
        ),
      ),
      onWillPop: ()async{
        if(_activeStillCam){
          hideCamApp();
        }
        else if(_activeVideoCam) hideVideoCamApp();
        else Navigator.of(_pageContext).pop();
        return false;
      },
    );
  }//route's build method

  hideCamApp(){
    clearTaken();
    _showCam=false;
    _activeStillCam=false;
    _showCamCtr.add("kjut");
  }//hide cam app

  hideVideoCamApp(){
    clearTaken();
    _showVidCam=false;
    _activeVideoCam=false;
    _showVidCamCtr.add("kjut");
  }//hide video camera app

  GlobalKey _textKey=GlobalKey();
  GlobalKey _imageplaceholderKey= GlobalKey();
  int counter=0;
  createServerPost()async{
    if(globals.wallPostData["state"] == "active"){
      _kjToast.showToast(
          text: "You currently have one post being processed",
          duration: Duration(seconds: 7)
      );
      return;
    }
    if(_postTextCtr.text!="" && _selectedFiles.length>0){
      String _postText=_postTextCtr.text;
      if(globals.wallPostData["state"] == "passive"){
        globals.wallPostData["state"]="active";
        globals.wallPostData["title"]="Please wait ... ";
        globals.wallPostData["body"]="Getting things ready";
        globals.wallPostData["media"]=jsonEncode(_selectedFiles);
        globals.wallPostData["text"]=_postText;
        globals.globalWallPostCtr.add("kjut");
      }
      try{
        http.Response _resp= await http.post(
            globals.globBaseUrl + "?process_as=create_wall_post",
            body: {
              "user_id" : globals.userId,
              "text": _postText,
            }
        );

        if(_resp.statusCode == 200){
          var _respObj= jsonDecode(_resp.body);
          if(_respObj["status"] == "success"){
            globals.wallPostData["post_id"]=_respObj["post_id"];
            postMediaFiles();
          }
        }
      }
      catch(ex){
        globals.wallPostData["state"]="passive";
        globals.wallPostData["message"]="error";
        _kjToast.showToast(
            text: "Kindly ensure that your device is properly connected to the internet!",
            duration: Duration(seconds: 5)
        );
      }
    }
    else if(_selectedFiles.length<1){
      _kToolTip.showTip(
          target: _imageplaceholderKey,
          duration: Duration(seconds: 3),
          bgcolor: Color.fromRGBO(24, 24, 24, 1),
          textcolor: Colors.white,
          text: "Select at least one image or video file",
          context: _pageContext
      );
    }
    else{
      _kToolTip.showTip(
          target: _textKey,
          duration: Duration(seconds: 3),
          bgcolor: Color.fromRGBO(24, 24, 24, 1),
          textcolor: Colors.white,
          text: "Enter some texts here",
          context: _pageContext
      );
    }
  }//create server post

  FlutterFFmpeg _ffmpeg= FlutterFFmpeg();
  postMediaFiles()async{
    _kjToast.showToast(
        text: "Post created - uploading files",
        duration: Duration(milliseconds: 2500)
    );
    Future.delayed(
        Duration(seconds: 3),
            (){
          Navigator.pop(_pageContext);
        }
    );
    List _locSel=_selectedFiles;
    int _count= _locSel.length;
    List<String> _successful= List<String>();
    for(int _k=0; _k<_count; _k++){
      Map _targFile= _locSel[_k];
      List<String> _brkPath= _targFile["path"].toString().split("/");
      globals.wallPostData["title"]= "Sending ${_k + 1} of $_count files";
      globals.wallPostData["body"]= "Processing " + _brkPath.last;
      globals.globalWallPostCtr.add("kjut");
      if(_targFile["type"] == "image"){
        if(_targFile.containsKey("crop")){
          Uint8List _imgData= _targFile["crop"];
          List<String> _sendData= List<String>();
          String _b64str= base64Encode(_imgData);
          _sendData.add(_b64str);
          bool _retval= await postSplitFile(_sendData, "image", _k, _count);
          if(_retval){
            _successful.add(_targFile["path"]);
          }
        }
        else{
          File _targF= File(_targFile["path"]);
          Uint8List _uint8= _targF.readAsBytesSync();
          List<String> _sendData= List<String>();
          _sendData.add(base64Encode(_uint8));
          bool _retval= await postSplitFile(_sendData, "image", _k, _count);
          if(_retval){
            _successful.add(_targFile["path"]);
          }
        }
      }
      else{
        globals.wallPostData["title"]= "Processing " + _brkPath.last;
        globals.wallPostData["body"]= "Processing " + _brkPath.last;
        globals.globalWallPostCtr.add("kjut");
        String _outpath=_wallTmpDir.path + "/" + DateTime.now().millisecondsSinceEpoch.toString() + ".mp4";
        String _inpath= _targFile["path"];
        String _startpos=""; String _endpos="";
        if(_targFile["init"]){
          int _st=_targFile["start"];
          _startpos= globals.convSecToHMS(_st);
          int _dur=_targFile["end"] - _st;
          _endpos=globals.convSecToHMS(_dur);
        }
        else{
          _startpos= "00:00:00";
          _endpos="00:00:30";
        }
        int _execResult=await _ffmpeg.execute("-ss $_startpos -i '$_inpath'  -t $_endpos -crf 30 -c:v libx264 -c:a aac $_outpath");
        if(_execResult == 0){
          String _posterpath= _wallTmpDir.path + "/" + DateTime.now().millisecondsSinceEpoch.toString() + ".jpg";
          int _thumbresult=await _ffmpeg.execute("-ss 00:00:01 -i '$_inpath' -vframes 1 $_posterpath");
          if(_thumbresult == 0){
            File _targF= File(_outpath);
            Uint8List _uint8= _targF.readAsBytesSync();
            List<String> _sendData= List<String>();
            _sendData.add(base64Encode(_uint8));

            _targF= File(_posterpath);
            _uint8= _targF.readAsBytesSync();
            var _decodedImage= await decodeImageFromList(_uint8);
            String _vidAR= _decodedImage.width.toString() + "/" + _decodedImage.height.toString();
            _sendData.add(_vidAR);
            bool _retval= await postSplitFile(_sendData, "video", _k, _count);
            if(_retval){
              _successful.add(_targFile["path"]);
            }
          }
          else{
            echoGlobalWallPostError();
            break;
          }
        }
        else{
          echoGlobalWallPostError();
          break;
        }
      }
    }
    if(_successful.length == _count){
      globals.wallPostData["state"]="passive";
      globals.wallPostData["message"]="success";
      globals.globalWallPostCtr.add("kjut");
    }
  }//post media files

  postSplitFile(List<String> b64Str, String ftype, int pos, int kount)async{
    globals.wallPostData["body"]= "Processing";
    globals.globalWallPostCtr.add("kjut");
    try{
      if(ftype == "image"){
        //an image is light so we send the whole file at a time
        http.Response _resp= await http.post(
            globals.globBaseUrl + "?process_as=upload_wall_post_image",
            body: {
              "user_id": globals.userId,
              "post_id": globals.wallPostData["post_id"],
              "file": b64Str[0],
              "position": "$pos",
              "total": "$kount"
            }
        );
        if(_resp.statusCode == 200){
          var _respObj= jsonDecode(_resp.body);
          if(_respObj["status"] == "success"){
            return true;
          }
          else{
            echoGlobalWallPostError();
            return false;
          }
        }
        else{
          echoGlobalWallPostError();
          return false;
        }
      }
      else if(ftype == "video"){
        //we will split video files into chunks
        String _b64str= b64Str[0];
        int _count= _b64str.length;
        int _strsize= 1024000 * 2; //2mb of string
        int _chunklen= (_count/_strsize).ceil();
        int _pointer=0;
        for(int _k=0; _k<_chunklen; _k++){
          if(_k==_chunklen-1){
            http.Response _partresp=await http.post(
                globals.globBaseUrl + "?process_as=wall_post_complete_split_file",
                body: {
                  "user_id": globals.userId,
                  "post_id": globals.wallPostData["post_id"],
                  "part": _b64str.substring(_pointer),
                  "position": "$pos",
                  "total": "$kount",
                  "ar":b64Str[1]
                }
            );
            if(_partresp.statusCode == 200){
              var _respObj= jsonDecode(_partresp.body);
              if(_respObj["status"] == "success"){
                return true;
              }
              else{
                echoGlobalWallPostError();
                return false;
              }
            }
          }
          else{
            int _pcent= (_k/_chunklen).ceil() * 100;
            globals.wallPostData["title"]= "Sending ${pos + 1} of $kount files ($_pcent%)";
            globals.globalWallPostCtr.add("kjut");
            await http.post(
                globals.globBaseUrl + "?process_as=save_part_video_file",
                body: {
                  "post_id": globals.wallPostData["post_id"],
                  "part": _b64str.substring(_pointer, (_pointer+_strsize))
                }
            );
          }
          _pointer +=_strsize;
        }
      }
    }
    catch(ex){
      echoGlobalWallPostError();
      return false;
    }
  }//post split file

  echoGlobalWallPostError(){
    globals.wallPostData["state"]="passive";
    globals.wallPostData["message"]="error";
    globals.globalWallPostCtr.add("kjut");
  }

  prevSlide(){
    resetVidPlayer();
    if(_focIndex>0){
      _focIndex--;
      setCropRect();
      _focFileChanged.add("kjut");
      cropImage();
    }
  }//prev slide

  nextSlide(){
    resetVidPlayer();
    if(_focIndex<_selectedFiles.length-1){
      _focIndex++;
      setCropRect();
      _focFileChanged.add("kjut");
      cropImage();
    }
  }

  List<String> _imageExts=["png", "jpg", "jpeg"];
  List<String> _vidExts=["mp4"];
  selFile()async{
    if(_selectedFiles.length<_postLimit){
      try{
        List<File> _pickedFiles=await FilePicker.getMultiFile(type: FileType.media);
        int _count= _pickedFiles.length;
        bool _exceededlimit=false;
        for(int _k=0; _k<_count; _k++){
          File _targFile= _pickedFiles[_k];
          String _targFPath= _targFile.path;
          List<String> _brkPath= _targFPath.split(".");
          String _targExt=_brkPath.last;
          if(_selectedFiles.length<_postLimit){
            if(_imageExts.indexOf(_targExt)>-1){
              _selectedFiles.add({
                "path": _targFPath,
                "type": "image",
                "x": 0.0, "y":0.0, "width": _screenSize.width, "height":_screenSize.height * .5
              });
            }
            else if(_vidExts.indexOf(_targExt)>-1){
              _selectedFiles.add({
                "path": _targFPath,
                "type": "video",
                "start": 0,
                "init": false,
                "end": 0
              });
            }
          }
          else _exceededlimit=true;
        }
        resetVidPlayer();
        _focIndex=_selectedFiles.length-1;
        setCropRect();
        _focFileChanged.add("kjut");
        if(_selectedFiles[_focIndex]["type"] == "image"){
          Future.delayed(
              Duration(milliseconds: 500),
                  (){
                cropImage();
              }
          );
        }

        if(_exceededlimit){
          _kjToast.showToast(
              text: "Maximum of $_postLimit media files can be posted",
              duration: Duration(seconds: 5)
          );
        }
      }
      catch(ex){

      }
    }
    else{
      _kjToast.showToast(
          text: "Maximum of $_postLimit media files can be posted",
          duration: Duration(seconds: 3)
      );
    }
  }//sel file

  ///This function should be called to pause the video player during critical changes like
  ///File selection, closing the still or video camera, ... basically any operation that changes
  ///the _selected files
  resetVidPlayer(){
    _playerPos=0;
    _videoPlayerControllers.forEach((element) {
      element.dispose();
    });
    _videoPlayerControllers=[];
  }//reset video players

  resetCams(){
    _cameraControllers.forEach((element) {
      element.dispose();
    });
    _cameraControllers=[];
  }//reset camera controllers

  setCropRect(){
    if(_focIndex>-1 && _focIndex<_postLimit){
      if(_selectedFiles[_focIndex]["type"] == "image"){
        _cropPosOffSet= Offset(_selectedFiles[_focIndex]["x"], _selectedFiles[_focIndex]["y"]);
        _cropwidth=_selectedFiles[_focIndex]["width"];
        _cropheight=_selectedFiles[_focIndex]["height"];
      }
    }
  }
  fillCropRect(){
    if(_focIndex>-1 && _focIndex<_postLimit){
      if(_selectedFiles[_focIndex]["type"] == "image"){
        _selectedFiles[_focIndex]["x"]=_cropPosOffSet.dx;
        _selectedFiles[_focIndex]["y"]=_cropPosOffSet.dy;
        _selectedFiles[_focIndex]["width"]=_cropwidth;
        _selectedFiles[_focIndex]["height"]=_cropheight;
      }
    }
  }//fillcroprect

  clearTaken(){
    if(_curCamSavePath!=""){
      File _tmpShot= File(_curCamSavePath);
      _tmpShot.exists().then((_fexists) {
        if(_fexists)_tmpShot.delete();
      });
      _curCamSavePath="";
    }
    resetVidPlayer();
  }

  double _cropMeshOpacity=0;
  StreamController _cropMeshOpacityChangeNotifier= StreamController.broadcast();
  Widget cropMesh(){
    return IgnorePointer(
      ignoring: true,
      child: StreamBuilder(
        stream: _cropMeshOpacityChangeNotifier.stream,
        builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
          return AnimatedOpacity(
            duration: Duration(milliseconds: 300),
            opacity: _cropMeshOpacity,
            onEnd: (){
              if(_cropMeshOpacity.toInt() == 0){
                cropImage();
              }
            },
            child: Container(
              width: _screenSize.width, height: _screenSize.height*.5,
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _screenSize.width < 700 ? 3 : 4
                ),
                itemCount: _screenSize.width<700 ? 12 : 20,
                itemBuilder: (BuildContext _ctx, int _gridIndex){
                  return Container(
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: Color.fromRGBO(20, 20, 20, 1)
                        )
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }//crop mesh

  static GlobalKey _cropKey=GlobalKey();
  cropImage(){
    if(_selectedFiles[_focIndex]["type"] == "image"){
      Future.delayed(
          Duration(milliseconds: 500),
              ()async{
            RenderRepaintBoundary _rp= _cropKey.currentContext.findRenderObject();
            ui.Image _uiImage= await _rp.toImage();
            ByteData _bd= await _uiImage.toByteData(format:ui.ImageByteFormat.png);
            Uint8List _pngData= _bd.buffer.asUint8List();
            _globCropCtr.add(_pngData);
            _selectedFiles[_focIndex]["crop"]= _pngData;
          }
      );
    }
  }

  int _camRecordTime=0;
  camRecordTimer(){
    if(_camRecording && _camRecordTime<30){
      Future.delayed(
          Duration(seconds: 1),
              (){
            _camRecordTime++;
            _camrecordNotifier.add("kjut");
            camRecordTimer();
          }
      );
    }
    else if(_camRecordTime>=30){
      CameraController _focCam= _cameraControllers.last;
      if(_focCam.value.isRecordingVideo){
        _focCam.stopVideoRecording().then((value) {
          _camRecording=false;
          _camrecordNotifier.add("kjut");
        });
      }
    }
  }

  bool _camRecording=false;
  bool _showVidCam=false;
  bool _camshotTaken=false;
  double _showPlayBtnOpacity=0;
  StreamController _globCropCtr= StreamController.broadcast();
  StreamController _toastCtr= StreamController.broadcast();
  StreamController _cropChangedNotifier= StreamController.broadcast();
  StreamController _videoARReadyNotifier= StreamController.broadcast();
  StreamController _volChangeNotifier= StreamController.broadcast();
  StreamController _playPausectr= StreamController.broadcast();
  StreamController _showPlayBtnCtr= StreamController.broadcast();
  StreamController _playerPosChangeNotifier= StreamController.broadcast();
  StreamController _showCamCtr= StreamController.broadcast();
  StreamController _camshotNotifier= StreamController.broadcast();
  StreamController _showVidCamCtr= StreamController.broadcast();
  StreamController _camrecordNotifier= StreamController.broadcast();
  bool _addRecorded=false;
  StreamController _addRecordednotifier= StreamController.broadcast();

  TextEditingController _postTextCtr= TextEditingController();

  StreamController _toolTipCtr= StreamController.broadcast();
  @override
  void dispose() {
    _toastCtr.close();
    _focFileChanged.close();
    _cropChangedNotifier.close();
    _cropMeshOpacityChangeNotifier.close();
    _globCropCtr.close();
    _videoARReadyNotifier.close();
    _volChangeNotifier.close();
    _playPausectr.close();
    _showPlayBtnCtr.close();
    _playerPosChangeNotifier.close();
    _videoPlayerControllers.forEach((element) {
      element.dispose();
    });
    _cameraControllers.forEach((el){
      el.dispose();
    });
    _showCamCtr.close();
    _camshotNotifier.close();
    _camrecordNotifier.close();
    _addRecordednotifier.close();
    _postTextCtr.dispose();
    _toolTipCtr.close();
    super.dispose();
  }//route's dispose method
}