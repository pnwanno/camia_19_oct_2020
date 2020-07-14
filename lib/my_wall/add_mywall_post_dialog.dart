import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:camera/camera.dart';
import 'package:flutter/rendering.dart';
//import 'package:camera_with_rtmp/camera.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:path_provider/path_provider.dart';

import 'package:http/http.dart' as http;

import '../globals.dart' as globals;

class NewWallPostDlg extends StatefulWidget {
  _NewWallPostDlg createState() {
    return _NewWallPostDlg();
  }
}

class _NewWallPostDlg extends State<NewWallPostDlg>
    with TickerProviderStateMixin {
  final FlutterFFmpeg _fffmpeg = FlutterFFmpeg();

  bool _globDlgSeen = false;

  TabController tabController;
  String _appBarTitle = "Gallery";
  List<String> _appBarTitles = ["Gallery", "Photo", "Video"];
  int _focusedTab = 0;

  List<CameraDescription> cameras;
  CameraController cameraCtr;

  ScrollController gridScrollCtr = ScrollController();

  PageController pageController = PageController();
  PageController finalPageController = PageController();
  StreamController finalPageScrollNotifier = StreamController.broadcast();
  StreamController finalVideoPlayerNotifier = StreamController.broadcast();

  Map<String, VideoPlayerController> _potVidCtr =Map<String, VideoPlayerController>();

  int curCamera = 0;

  ///camera description index to represent the first camera

  double playOpacity1 = 0;

  final GlobalKey cropKey = GlobalKey();

  Map<String, Map> finalImageData = Map<String,Map>(); //Contains the data of the image that will be uploaded finally
  String currentFocusedId =""; //used to hold the file id during the final file processing
  Map<String, VideoPlayerController> vplayers = Map<String, VideoPlayerController>();
  Map<String, Map> vplayerPPt = Map<String, Map>();

  double curVidEditorDur = 0;
  double curVidEditorPos = 0;
  String curVidEditorId = "";
  RangeValues curVidEditorRange = RangeValues(0, 0);
  bool vEditorIsActive = false;
  StreamController<Map> editorRangeCtr = StreamController.broadcast();

  StreamController galleryGridStream = StreamController.broadcast();
  StreamController galleryGridTapped = StreamController.broadcast();

  StreamController<Map<String, bool>> editorDlgCtrl =StreamController<Map<String, bool>>.broadcast();

  StreamController<Map<String, String>> firstVideoPlayerCtrl =StreamController<Map<String, String>>.broadcast();

  String curPlayingVidFirst = "";
  StreamController scaleCtr = StreamController.broadcast();

  StreamController _postProgressCtr = StreamController.broadcast();

  final GlobalKey pvgk= GlobalKey();
  Directory _appDir;
  @override
  void initState() {
    tabController = TabController(length: 3, vsync: this);
    tabController.addListener(() {
      _focusedTab = tabController.index;
      _fileIds.clear();
      _selFilePPT.clear();
      _selectedFiles.clear();
      finalImageData = {};
      vplayers = {};
      vplayerPPt = {};
      _globDlgSeen = false;
      editorDlgCtrl
          .add({"global_dlg": _globDlgSeen, "image_editor_dlg": false});
      setState(() {
        _appBarTitle = _appBarTitles[_focusedTab];
      });
    });
    gridChildren = List<Widget>();
    initPhotoMgr();
    initCamera();

    gridScrollCtr.addListener(() {
      if (gridScrollCtr.position.maxScrollExtent -
              gridScrollCtr.position.pixels <
          100) {
        if (isLoadingAssests == false) {
          isLoadingAssests = true;
          loadFolderAssets(selFolder, gridChildren.length);
        }
      }
    });

    pageController.addListener(() {
      double curPage = pageController.page;
      if (curPage.floor() == curPage){
        _potVidCtr.forEach((key, value) async {
          String k = _fileIds[curPage.toInt()];
          if(key == k){
            await value.play();
          }
          else{
            if(value.value.isPlaying) await value.pause();
          }
        });
      }
    });

    finalPageController.addListener(() {
      double curPage = finalPageController.page;
      if (curPage.floor() == curPage) {
        //when the page coontroller flips, stop all playing videos
        vplayers.forEach((key, value) async{
          if(value.value.isPlaying) {
            value.pause();
          }
        });

        //provide a global pointer to the focused file
        currentFocusedId = _fileIds[curPage.toInt()];

        //set video timeline position or image scale ppt
        if (_selFilePPT[curPage.toInt()]["type"] == AssetType.video) {
          String targId = _fileIds[curPage.toInt()];
          curVidEditorDur =vplayers["$targId"].value.duration.inSeconds.toDouble();
          curVidEditorRange = RangeValues(
              double.tryParse(vplayerPPt["$targId"]["start"]),
              double.tryParse(vplayerPPt["$targId"]["stop"])
          );
          vEditorIsActive = true;
          curVidEditorId = targId;
          updateVEditorSlider();
          finalPageScrollNotifier.add({"current_view": "video"});
        } 
        else {
          vEditorIsActive = false;
          updateVEditorSlider();

          double newScale = finalImageData[currentFocusedId]["scale"];
          Offset offset = finalImageData[currentFocusedId]["position"];
          curScaleHolder = newScale;
          finalPageScrollNotifier.add({"current_view": "image"});
          scaleCtr.add({"scale": newScale, "position": offset});
          if (finalImageData[currentFocusedId]["file"] == "") {
            cropImage();
          } 
          else {
            renderImageCtr.add(finalImageData[currentFocusedId]["file"]);
          }
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      updateVEditorSlider();
    });

    super.initState();
  }//initstate

  ///This method releases the memory held by high-memory variables on this page,
  ///by resetting their values
  clearMemoryVars(){
    finalImageData = Map<String,Map>();
    vplayers = Map();
    vplayerPPt = Map<String, Map>();
    _selectedFiles=List<File>();
    _fileIds= List<String>();
    curVidEditorRange = RangeValues(0, 0);
    _selFilePPT= List<Map>();
    
  }//clear memory vars

  initCamera() async {
    try {
      cameras = await availableCameras();
      cameraCtr = CameraController(cameras[0], ResolutionPreset.medium,enableAudio: true);
      await cameraCtr.initialize();
    } catch (ex) {}
  } //initialise camera

  List<File> _selectedFiles = List<File>();
  List<String> _fileIds = List<String>();
  List<Map> _selFilePPT = List<Map>();

  List<AssetPathEntity> assetPath = List<AssetPathEntity>();
  StreamController folderListStream = StreamController.broadcast();
  List<DropdownMenuItem<dynamic>> folderList =
      List<DropdownMenuItem<dynamic>>();
  int selFolder = 0;
  List<Widget> gridChildren;
  initPhotoMgr() async {
    _appDir = await getApplicationDocumentsDirectory();
    var result = await PhotoManager.requestPermission();
    if (result) {
      assetPath = await PhotoManager.getAssetPathList();
      int kount = assetPath.length;
      for (int k = 0; k < kount; k++) {
        folderList.add(DropdownMenuItem(
          child: Text(assetPath[k].name),
          value: k,
        ));
      }

      if (kount > 0) {
        loadFolderAssets(0, 0);
      }
      setState(() {});
      Future.delayed(Duration(seconds: 1), () {
        folderListStream.add(folderList);
      });
    } else {
      PhotoManager.openSetting();
    }
  } //initialise photo manager

  List<AssetEntity> _folderFiles = List<AssetEntity>();
  List<Uint8List> _folderFilesThumbData = List<Uint8List>();
  bool isLoadingAssests = false;

  ///Load assets that are in a specific folder for the drop-down at the appbar
  loadFolderAssets(int assetIndex, int start) async {
    if (start == 0) {
      _folderFiles = List<AssetEntity>();
      _folderFilesThumbData = List<Uint8List>();
    }

    _folderFiles.addAll(await assetPath[assetIndex]
        .getAssetListRange(start: start, end: start + 20));

    for (int k = start; k < _folderFiles.length; k++) {
      _folderFilesThumbData.add(await _folderFiles[k].thumbData);
    }
    await loadGridView();
    isLoadingAssests = false;
  } //load selected folder assets (files)

  ///  Loads up content for the grid view that displays the file system pictures
  ///  and videos
  loadGridView() async {
    int filecount = _folderFiles.length;
    gridChildren = List<Widget>();
    for (int k = 0; k < filecount; k++) {
      if (_folderFiles[k].type == AssetType.image ||_folderFiles[k].type == AssetType.video) {
        Uint8List img = _folderFilesThumbData[k];
        String remoteId = _folderFiles[k].id;
        gridChildren.add(GestureDetector(
            onTap: () async {
              String targId = _folderFiles[k].id;
              int _indexOfId = _fileIds.indexOf(targId);
              File f = await _folderFiles[k].file;
              var targMIME = _folderFiles[k].type;
              double targAR = _folderFiles[k].width / _folderFiles[k].height;
              Map gridStreamData=Map();
              if (_indexOfId == -1) {
                if (_fileIds.length < 10) {
                  _fileIds.add(targId);
                  _selectedFiles.add(f);
                  _selFilePPT.add({"type": targMIME, "ar": targAR});
                  finalImageData["$targId"] = {
                    "scale": 1.0,
                    "position": Offset(0, 0),
                    "file": ""
                  };
                  if(targMIME == AssetType.video){
                    vplayers["$targId"] = VideoPlayerController.file(f);
                    _potVidCtr["$targId"]=VideoPlayerController.file(f);
                    _potVidCtr["$targId"].addListener(() {
                      if(_potVidCtr["$targId"].value.isPlaying){
                        curPlayingVidFirst = "$targId";
                        firstVideoPlayerCtrl.add({"player_id": curPlayingVidFirst});
                      }
                      else{
                        if (curPlayingVidFirst == targId) curPlayingVidFirst = "";
                        firstVideoPlayerCtrl.add({"player_id": curPlayingVidFirst});
                      }
                      if(_potVidCtr["$targId"].value.position.inSeconds == _potVidCtr["$targId"].value.duration.inSeconds){
                        _potVidCtr["$targId"].seekTo(Duration(seconds: 0));
                        firstVideoPlayerCtrl.add({"player_id": curPlayingVidFirst});
                      }
                    });
                    try{
                      await _potVidCtr["$targId"].initialize();
                      await _potVidCtr["$targId"].seekTo(Duration(milliseconds: 500));
                    }
                    catch(ex){
                      //can't open media
                    }
                  }
                  modifyLocalPageView(_fileIds.length-1);
                  gridStreamData={
                    "action": "add",
                    "type": "any",
                    "index": _fileIds.length - 1
                  };
                } 
                else {
                  showToast(
                    text: "Maximum selection reached",
                    persistDur: Duration(seconds: 3)
                  );
                }
              } 
              else {
                String fid=_fileIds[_indexOfId];
                _fileIds.removeAt(_indexOfId);
                _selectedFiles.removeAt(_indexOfId);
                _selFilePPT.removeAt(_indexOfId);
                finalImageData.remove(fid);
                gridStreamData={
                  "action": "remove",
                  "type": "image",
                  "index": "$_indexOfId"
                };
                if (targMIME == AssetType.video) {
                  vplayers.remove(fid);
                  await _potVidCtr["$fid"].pause();
                  gridStreamData={
                    "action": "remove",
                    "type": "video",
                    "index": "$fid"
                  };
                }
                _pageViewChildren.removeAt(_indexOfId);
              }
              galleryGridTapped.add(gridStreamData);
            },
            child: Stack(
              children: <Widget>[
                Container(
                  width: 150,
                  height: 150,
                  child: Stack(
                    children: <Widget>[
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: MemoryImage(img), 
                            fit: BoxFit.cover
                          ),
                        ),
                      ),
                      Positioned(left: 12, top: 12,
                          child: StreamBuilder(
                              stream: galleryGridTapped.stream,
                              builder:(BuildContext ctx, AsyncSnapshot snapshot) {
                                if (snapshot.hasData){
                                  int _rindexOfId = _fileIds.indexOf(remoteId);
                                  return Container(
                                    width: 24,
                                    height: 24,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: (_rindexOfId > -1)
                                            ? Color.fromRGBO(255, 143, 5, 1)
                                            : Colors.white),
                                    child: Text(
                                      (_rindexOfId > -1)
                                          ? (_rindexOfId + 1).toString()
                                          : "",
                                      style: TextStyle(
                                          color: (_rindexOfId > -1)
                                              ? Colors.white
                                              : Colors.black),
                                    ),
                                  );
                                } else {
                                  return Container();
                                }
                              }))
                    ],
                  ),
                ),
                (_folderFiles[k].type == AssetType.video)
                    ? Positioned(
                        right: 16,
                        bottom: 16,
                        child: Icon(
                          FlutterIcons.play_faw,
                          color: Colors.white,
                        ))
                    : Positioned(child: Container())
              ],
            )));
      }
    }
    galleryGridStream.add(gridChildren);
  } //load grid view
  /*
  */

  List<Widget> _pageViewChildren = List<Widget>();
  modifyLocalPageView(int itemPos){
    var targType = _selFilePPT[itemPos]["type"];
    String targId = _fileIds[itemPos];
    _pageViewChildren.add(
      Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: () {},
          child: Container(
            child: Stack(
              children: <Widget>[
                Container(
                  child: (targType == AssetType.image)
                    ? Image.file(
                         _selectedFiles[itemPos],
                        width: MediaQuery.of(context).size.width,
                        fit: BoxFit.fitWidth,
                        alignment: Alignment.center,
                      )
                      : Container(
                        child: Stack(
                          children: <Widget>[
                            Container(
                              child: VideoPlayer(_potVidCtr["$targId"]),
                            ),
                            Positioned.fill(
                              child: Material(
                                color: Colors.transparent,
                                child: InkResponse(
                                  onTap:() async {
                                    if (_potVidCtr["$targId"].value.isPlaying) {
                                      await _potVidCtr["$targId"].pause();
                                    } 
                                    else {
                                      await _potVidCtr["$targId"].play();
                                    }
                                  },
                                  child: StreamBuilder(
                                    stream:firstVideoPlayerCtrl.stream,
                                    builder: (BuildContext ctx,AsyncSnapshot snapshot) {
                                      if (snapshot.hasData) {
                                        return AnimatedOpacity(
                                          opacity: 1,
                                          duration: Duration(milliseconds: 500),
                                          child: Icon(
                                            snapshot.data["player_id"] =="$targId"
                                              ? FlutterIcons.pause_faw
                                              : FlutterIcons.play_faw,
                                            color: Colors.grey,
                                          ),
                                        );
                                      } 
                                      else {
                                        return Container(
                                          child: Icon(
                                            FlutterIcons.play_faw
                                          ),
                                        );
                                      }
                                    }),
                              )))
                    ],
                  ),
                ))
              ],
            ),
          ),
        ),
      ));
  }

  ///Load the contents of the page view that displays selected images
  Future<void> loadPageViewContent() async {
    _pageViewChildren = List<Widget>();
    int _selFileCount = _selectedFiles.length;
    for (int k = 0; k < _selFileCount; k++) {
      var targType = _selFilePPT[k]["type"];
      String targId = _fileIds[k];
      if (targType == AssetType.video) {
        if (_potVidCtr["$targId"] == null){
          _potVidCtr["$targId"] = VideoPlayerController.file(_selectedFiles[k]);
        }
      }
      _pageViewChildren.add(Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: () {},
          child: Container(
            child: Stack(
              children: <Widget>[
                Container(
                    child: (targType == AssetType.image)
                        ? Image.file(
                            _selectedFiles[k],
                            width: MediaQuery.of(context).size.width,
                            fit: BoxFit.fitWidth,
                            alignment: Alignment.center,
                          )
                        : Container(
                            child: Stack(
                              children: <Widget>[
                                Container(
                                  child: VideoPlayer(_potVidCtr["$targId"]),
                                ),
                                Positioned.fill(
                                    child: Material(
                                        color: Colors.transparent,
                                        child: InkResponse(
                                          onTap: () async {
                                            if (_potVidCtr["$targId"].value.isPlaying) {
                                              await _potVidCtr["$targId"].pause();
                                            } 
                                            else {
                                              await _potVidCtr["$targId"].play();
                                            }
                                          },
                                          child: StreamBuilder(
                                              stream:firstVideoPlayerCtrl.stream,
                                              builder: (BuildContext ctx,AsyncSnapshot snapshot) {
                                                if (snapshot.hasData) {
                                                  return AnimatedOpacity(
                                                    opacity: 1,
                                                    duration: Duration(milliseconds: 500),
                                                    child: Icon(
                                                      snapshot.data["player_id"] =="$targId"
                                                        ? FlutterIcons.pause_faw
                                                        : FlutterIcons.play_faw),
                                                  );
                                                } 
                                                else {
                                                  return Container(
                                                    child: Icon(
                                                      FlutterIcons.play_faw
                                                    ),
                                                  );
                                                }
                                              }),
                                        )))
                              ],
                            ),
                          ))
              ],
            ),
          ),
        ),
      ));

      
    }
    int kounter=0;
    _potVidCtr.forEach((key, value) async {
      if (_fileIds.indexOf(key) < 0) {
        await value.pause();
        await value.dispose();
        _potVidCtr.remove(key);
      }
      else{
        value.pause();
      }
      if(kounter == (_fileIds.length-1) || kounter == (_fileIds.length-2)){
        if(!value.value.initialized){
          await value.initialize();
          value.addListener(() {
            if(_potVidCtr["$key"].value.isPlaying){
              curPlayingVidFirst = "$key";
              firstVideoPlayerCtrl.add({"player_id": curPlayingVidFirst});
            }
            else{
              if (curPlayingVidFirst == key) curPlayingVidFirst = "";
              firstVideoPlayerCtrl.add({"player_id": curPlayingVidFirst});
            }
          });
        }
      }
      kounter++;
    });
    
  } //load pageView content

  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;
    return WillPopScope(
        child: SafeArea(
            top: false,
            minimum: EdgeInsets.only(top: 40),
            child: Scaffold(
                appBar: AppBar(
                  backgroundColor: Color.fromRGBO(26, 26, 26, 1),
                  title: Text(
                    _appBarTitle,
                  ),
                  actions: <Widget>[
                    (assetPath.length > 0 && _focusedTab == 0)
                        ? Container(
                            width: 150,
                            margin: EdgeInsets.only(right: 32),
                            child: StreamBuilder(
                                stream: folderListStream.stream,
                                builder:
                                    (BuildContext ctx, AsyncSnapshot snapshot) {
                                  if (snapshot.hasData) {
                                    return DropdownButton(
                                        items: snapshot.data,
                                        isExpanded: true,
                                        hint: Text(assetPath[selFolder].name,
                                            style:
                                                TextStyle(color: Colors.white)),
                                        onChanged: (curVal) async {
                                          await loadFolderAssets(curVal, 0);
                                          setState(() {
                                            selFolder = curVal;
                                          });
                                        });
                                  } else {
                                    return Container(
                                      margin: EdgeInsets.only(top: 12),
                                      child: Text(
                                        "Loading...",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    );
                                  }
                                }))
                        : Container(),
                  ],
                ),
                body: GestureDetector(
                  child: Stack(
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.only(left: 16, right: 16),
                        height: MediaQuery.of(context).size.height,
                        color: Color.fromRGBO(1, 1, 1, 1),
                        child: TabBarView(controller: tabController, children: [
                          Container(
                              child: Column(
                            children: <Widget>[
                              Container(
                                  height: (_screenSize.height < 600)? 300
                                      : (_screenSize.height < 900) ? 450 : 600,
                                  child: Stack(
                                    children: <Widget>[
                                      Container(
                                          child: StreamBuilder(
                                              stream: galleryGridTapped.stream,
                                              builder: (BuildContext ctx,AsyncSnapshot snapshot) {
                                                if (snapshot.hasData && _pageViewChildren.length>0) {
                                                  Future.delayed(
                                                    Duration(milliseconds: 500),
                                                    (){
                                                      pageController.animateToPage(
                                                        _fileIds.length - 1,
                                                        duration: Duration(milliseconds: 300), 
                                                        curve: Curves.linear
                                                      );
                                                    }
                                                  );
                                                  return PageView.builder(
                                                    controller: pageController,
                                                    itemCount: _pageViewChildren.length,
                                                    itemBuilder: (BuildContext ctx, int idx){
                                                      return _pageViewChildren[idx];
                                                    },
                                                    onPageChanged: (value) async {                                                      if(snapshot.data.length>0){
                                                        Map snapData=snapshot.data;
                                                        if(snapData["action"]=="remove" && snapData["type"]=="video"){
                                                          String fid=snapData["index"];
                                                          await _potVidCtr["$fid"].dispose();
                                                          _potVidCtr.remove(fid);
                                                        }
                                                      }
                                                    },
                                                  );
                                                }
                                                else {
                                                  return Container();
                                                }
                                              })),
                                      Positioned(
                                          right: 12,
                                          bottom: 12,
                                          child: Container(
                                            child: RaisedButton(
                                              color: Color.fromRGBO(
                                                  26, 26, 26, .8),
                                              textColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)),
                                              onPressed: () async{
                                                if (_fileIds.length > 0) {
                                                  _potVidCtr.forEach((key, value) {
                                                    if (value.value.isPlaying) {
                                                      value.pause();
                                                    }
                                                  });

                                                  _finalSelection.clear();
                                                  _finalSelection.addAll(_selectedFiles);
                                                  await initFinalSelVideos();
                                                } 
                                                else {
                                                  showToast(
                                                    text:"Select at least one file to continue",
                                                    persistDur:Duration(seconds: 3)
                                                  );
                                                }
                                              },
                                              child: Text("NEXT"),
                                            ),
                                          ))
                                    ],
                                  )),
                              Expanded(
                                  child: StreamBuilder(
                                      stream: galleryGridStream.stream,
                                      builder: (BuildContext ctx, AsyncSnapshot snapshot) {
                                        if (snapshot.hasData) {
                                          Future.delayed(
                                            Duration(milliseconds: 500), 
                                            (){
                                              galleryGridTapped.add("kjut");
                                            }
                                          );
                                          return Container(
                                              child: GridView.builder(controller: gridScrollCtr,
                                                  itemCount:gridChildren.length,
                                                  gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(
                                                    crossAxisCount: 4,
                                                    mainAxisSpacing: 2,
                                                    crossAxisSpacing: 2
                                                  ),
                                                  itemBuilder:(BuildContext ctx,int index) {
                                                    return snapshot.data[index];
                                                  }));
                                        } else {
                                          return Container();
                                        }
                                      }))
                            ],
                          )), //gallery

                          Container(
                              child: Column(
                            children: <Widget>[
                              Container(
                                  height: (_screenSize.height < 600)
                                      ? 300
                                      : (_screenSize.height < 900) ? 400 : 550,
                                  child: Stack(
                                    children: <Widget>[
                                      Container(
                                        child: CameraPreview(cameraCtr),
                                      ),
                                      Positioned(
                                          bottom: 12,
                                          left: 12,
                                          child: Container(
                                            child: Row(
                                              children: <Widget>[
                                                Container(
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkResponse(
                                                      onTap: () async {
                                                        int camLen =
                                                            cameras.length;
                                                        if (curCamera + 1 <
                                                            camLen) {
                                                          curCamera++;
                                                        } else
                                                          curCamera = 0;

                                                        cameraCtr =
                                                            CameraController(
                                                              cameras[curCamera],
                                                              ResolutionPreset.medium,
                                                              enableAudio:true
                                                            );
                                                        await cameraCtr.initialize();
                                                        setState(() {});
                                                      },
                                                      child: Icon(
                                                        FlutterIcons
                                                            .ios_reverse_camera_ion,
                                                        color: Colors.white,
                                                        size: 32,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              ],
                                            ),
                                          ))
                                    ],
                                  )), //camera preview
                              Expanded(
                                  child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: Color.fromRGBO(60, 60, 60, 1)),
                                child: Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(50),
                                      color: Colors.grey),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(50),
                                    child: InkResponse(
                                      onTap: () {},
                                    ),
                                  ),
                                ),
                              ))
                            ],
                          )), //photo

                          Container(
                              child: Column(
                            children: <Widget>[
                              Container(
                                  height: 400,
                                  child: Stack(
                                    children: <Widget>[
                                      Container(
                                        child: CameraPreview(cameraCtr),
                                      ),
                                      Positioned(
                                          bottom: 12,
                                          left: 12,
                                          child: Container(
                                            child: Row(
                                              children: <Widget>[
                                                Container(
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkResponse(
                                                      onTap: () async {
                                                        int camLen =
                                                            cameras.length;
                                                        if (curCamera + 1 <
                                                            camLen) {
                                                          curCamera++;
                                                        } else
                                                          curCamera = 0;

                                                        cameraCtr =
                                                            CameraController(
                                                              cameras[curCamera],
                                                              ResolutionPreset.medium,
                                                              enableAudio:true
                                                            );
                                                        await cameraCtr.initialize();
                                                        setState(() {});
                                                      },
                                                      child: Icon(
                                                        FlutterIcons
                                                            .ios_reverse_camera_ion,
                                                        color: Colors.white,
                                                        size: 32,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              ],
                                            ),
                                          ))
                                    ],
                                  )), //camera preview
                              Expanded(
                                  child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: Color.fromRGBO(60, 60, 60, 1)),
                                child: Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(50),
                                      color: Colors.grey),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(50),
                                    child: InkResponse(
                                      onTap: () {},
                                    ),
                                  ),
                                ),
                              ))
                            ],
                          )), //video
                        ]),
                      ), //body's main container

                      Positioned(
                          child: StreamBuilder(
                              stream: editorDlgCtrl.stream,
                              builder:
                                  (BuildContext ctx, AsyncSnapshot snapshot) {
                                if (snapshot.hasData) {
                                  if (snapshot.data["global_dlg"] == true && snapshot.data["image_editor_dlg"] == true) {
                                    return imageEditorDialog();
                                  }
                                  else {
                                    return Container();
                                  }
                                } 
                                else {
                                  return Container();
                                }
                              })),

                      Positioned(
                          bottom: 200,
                          width: MediaQuery.of(context).size.width - 60,
                          left: 30,
                          child: StreamBuilder(
                              stream: toastCtrl.stream,
                              builder:
                                  (BuildContext ctx, AsyncSnapshot snapshot) {
                                if (snapshot.hasData) {
                                  return AnimatedOpacity(
                                    opacity: double.tryParse(
                                        snapshot.data["opacity"]),
                                    duration: Duration(milliseconds: 500),
                                    child: Container(
                                      padding: EdgeInsets.only(
                                          top: 12,
                                          bottom: 12,
                                          left: 16,
                                          right: 16),
                                      decoration: BoxDecoration(
                                          color: Color.fromRGBO(40, 40, 40, .8),
                                          borderRadius:
                                              BorderRadius.circular(24)),
                                      alignment: Alignment.center,
                                      child: Text(
                                        snapshot.data["text"],
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 16),
                                      ),
                                    ),
                                  );
                                } else {
                                  return Container();
                                }
                              })), //mimic android toast
                    ],
                  ),
                ),
                bottomNavigationBar: Container(
                  padding:
                      EdgeInsets.only(left: 32, right: 32, top: 16, bottom: 16),
                  color: Color.fromRGBO(26, 26, 26, 1),
                  width: MediaQuery.of(context).size.width,
                  child: TabBar(controller: tabController, tabs: [
                    Container(
                        padding: EdgeInsets.only(top: 12, bottom: 12),
                        child: Text("Gallery")),
                    Container(child: Text("Photo")),
                    Container(child: Text("Video"))
                  ]),
                ))),
        onWillPop: () async {
          if (_globDlgSeen) {
            vplayers.forEach((key, value) {
              if (value.value.isPlaying) value.pause();
            });
            _globDlgSeen = false;
            editorDlgCtrl
                .add({"global_dlg": _globDlgSeen, "image_editor_dlg": false});

            return false;
          } else {
            return true;
          }
        });
  } //build function

  StreamController<Map> toastCtrl = StreamController<Map>.broadcast();
  showToast({String text, Duration persistDur}) {
    toastCtrl.add({"text": text, "opacity": "1"});

    Future.delayed(persistDur, () {
      toastCtrl.add({"text": "", "opacity": "0"});
    });
  }

  @override
  void dispose() {
    tabController.dispose();
    cameraCtr.dispose();
    pageController.dispose();
    finalPageController.dispose();
    gridScrollCtr.dispose();
    vplayers.forEach((key, value) {
      value.dispose();
    });
    clearMemoryVars();
    editorRangeCtr.close();
    galleryGridStream.close();
    folderListStream.close();
    galleryGridTapped.close();
    editorDlgCtrl.close();
    toastCtrl.close();
    firstVideoPlayerCtrl.close();
    scaleCtr.close();
    renderImageCtr.close();
    finalPageScrollNotifier.close();
    finalVideoPlayerNotifier.close();
    _postProgressCtr.close();
    super.dispose();
  }

  updateVEditorSlider() {
    editorRangeCtr.add({
      "visible": vEditorIsActive,
      "position": "$curVidEditorPos",
      "duration": "$curVidEditorDur",
      "range": curVidEditorRange
    });
  }

  Future initFinalSelVideos()async{
    int kounter=0;
    vplayers.forEach((key, value)async{
      value.addListener(() {
        try{
          if (value.value.isPlaying) {
            curVidEditorPos = value.value.position.inSeconds.toDouble();
            if (curVidEditorPos ==double.tryParse(vplayerPPt["$key"]["stop"])) {
              vplayers["$key"].seekTo(Duration(seconds: double.tryParse(vplayerPPt["$key"]["start"]).toInt()));
            }
            updateVEditorSlider();
          }
          finalVideoPlayerNotifier.add(true);
        }
        catch(ex){
          debugPrint("Error caught in the play event");
        }
        
      });
      if(!value.value.initialized){
        /*_pageViewChildren=List<Widget>();
        _potVidCtr.forEach((k, v)async {
          await v.pause();
          await v.dispose();
        });
        _potVidCtr= Map<String, VideoPlayerController>();
        galleryGridTapped.add("kjut");*/
        try{
          await value.initialize();
          await value.seekTo(Duration(seconds: 1));
          int curVidDur =value.value.duration.inSeconds;
          if (curVidDur >= 30) curVidDur = 30;
            vplayerPPt["$key"] = {
            "start": "0",
            "stop": curVidDur.toString()
          };
        }
        catch(ex){
          //can't init media 
          debugPrint("Can't init media $ex");
        }
      }

      kounter++;
      if(kounter == vplayers.length){
        _globDlgSeen = true;
        editorDlgCtrl.add({
          "global_dlg": _globDlgSeen,
          "image_editor_dlg": true
        });
      }
    });
    if(vplayers.length==0){
      //there are no videos found
      _globDlgSeen = true;
      editorDlgCtrl.add({
        "global_dlg": _globDlgSeen,
        "image_editor_dlg": true
      });
    }
  }
  List<File> _finalSelection = List<File>();
  TextEditingController postCaption = TextEditingController();
  TextEditingController postLocation = TextEditingController();
  /*
  The section below will be used to define ui segments of this page that I 
  would have imported, but I want to be part of the page
  */
  StreamController<Uint8List> renderImageCtr =
      StreamController<Uint8List>.broadcast();
  Offset pointerPos = Offset(0, 0);
  double curScale = 1;
  double curScaleHolder = 1;

  Future cropImage() async {
    RenderRepaintBoundary b = cropKey.currentContext.findRenderObject();
    double pixelRatio = 800 / MediaQuery.of(context).size.width;
    ui.Image image = await b.toImage(pixelRatio: pixelRatio);
    ByteData bd = await image.toByteData(format: ui.ImageByteFormat.png);
    Uint8List pngData = bd.buffer.asUint8List();
    finalImageData[currentFocusedId]["file"] = pngData;
    finalPageScrollNotifier.add({"current_view": "image"});
    renderImageCtr.add(pngData);
  }

  /*
    For the Image editor dialog
   */
  ///The Image editor dialog
  Widget imageEditorDialog() {
    //create the mesh look
    List<Widget> meshView = List<Widget>();
    for (int k = 0; k < 20; k++) {
      meshView.add(Container(
        decoration: BoxDecoration(
            border: Border.all(color: Color.fromRGBO(200, 200, 200, 1))),
      ));
    }
  
    List<Widget> pgChildren = List<Widget>();
    int kount = _fileIds.length;
    for (int k = 0; k < kount; k++) {
      String targFId = _fileIds[k];
      if (_selFilePPT[k]["type"] == AssetType.image) {
        pgChildren.add(Container(
          child: GestureDetector(
            onScaleUpdate: (scp) {
              double dx = pointerPos.dx - scp.localFocalPoint.dx;
              double dy = pointerPos.dy - scp.localFocalPoint.dy;
              Offset offset = Offset(
                  finalImageData["$currentFocusedId"]["position"].dx - dx,
                  finalImageData["$currentFocusedId"]["position"].dy - dy);

              finalImageData[currentFocusedId]["position"] = offset;
              pointerPos = scp.localFocalPoint;

              double scaleDiff = scp.scale - curScale;
              double newScale = curScaleHolder + scaleDiff;
              finalImageData[currentFocusedId]["scale"] = newScale;

              scaleCtr.add({"scale": newScale, "position": offset});
            },
            onScaleStart: (ScaleStartDetails ssd) {
              pointerPos = ssd.localFocalPoint;
              curScaleHolder = finalImageData[currentFocusedId]["scale"];
            },
            onScaleEnd: (ScaleEndDetails sed) async {
              cropImage();
            },
            child: StreamBuilder(
                stream: scaleCtr.stream,
                builder: (BuildContext ctx, AsyncSnapshot snapshot) {
                  return Container(
                    alignment: Alignment.center,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        Positioned(
                            left: snapshot.hasData
                                ? snapshot.data["position"].dx
                                : 0,
                            top: snapshot.hasData
                                ? snapshot.data["position"].dy
                                : 0,
                            child: Transform.scale(
                                scale: snapshot.hasData
                                    ? snapshot.data["scale"]
                                    : 1,
                                child: Container(
                                  width: MediaQuery.of(context).size.height *
                                      0.5 *
                                      (16 / 9),
                                  height:
                                      MediaQuery.of(context).size.height * 0.5,
                                  decoration: BoxDecoration(
                                      image: DecorationImage(
                                          image: FileImage(_selectedFiles[k]),
                                          fit: BoxFit.cover)),
                                ))),
                      ],
                    ),
                  );
                }),
          ),
        ));
      } 
      else if (_selFilePPT[k]["type"] == AssetType.video) {
        curVidEditorDur =vplayers["$targFId"].value.duration.inSeconds.toDouble();
        curVidEditorRange = RangeValues(
          double.tryParse(vplayerPPt["$targFId"]["start"]),
          double.tryParse(vplayerPPt["$targFId"]["stop"])
        );
        curVidEditorId = targFId;
        pgChildren.add(Container(
          child: Stack(
            children: <Widget>[
              Container(
                  alignment: Alignment.center,
                  child: Container(
                    alignment: Alignment.center,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: VideoPlayer(vplayers["$targFId"]),
                    ),
                  )), //player view
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    if (vplayers["$targFId"].value.isPlaying) {
                      vplayers["$targFId"].pause();
                    } 
                    else {
                      vplayers["$targFId"].play();
                    }
                  },
                  child: Container(
                      width: MediaQuery.of(context).size.width,
                      alignment: Alignment.center,
                      child: StreamBuilder(
                          stream: finalVideoPlayerNotifier.stream,
                          builder: (BuildContext ctx, AsyncSnapshot snapshot) {
                            return Icon(
                              (snapshot.hasData && vplayers["$targFId"].value.isPlaying)
                                  ? FlutterIcons.pause_faw
                                  : FlutterIcons.play_faw,
                              color: Colors.white,
                              size: 36,
                            );
                          })),
                ),
              ),
            ],
          ),
        ));
      }
    }
    //do a quick initialization on the page view
    Future.delayed(Duration(seconds: 1), () {
      double curPage = finalPageController.page;
      if (curPage.floor() == curPage) {
        int localK = curPage.toInt();
        currentFocusedId = _fileIds[localK];
        if (_selFilePPT[localK]["type"] == AssetType.image) {
          cropImage();
        } 
        else if (_selFilePPT[localK]["type"] == AssetType.video) {
          finalPageScrollNotifier.add({"current_view": "video"});
          vEditorIsActive = true;
          updateVEditorSlider();
        }
      }
    });

    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: BoxDecoration(color: Color.fromRGBO(10, 10, 10, 1)),
      child: ListView(
        children: <Widget>[
          Container(
              padding: EdgeInsets.only(top: 12, bottom: 12),
              height: MediaQuery.of(context).size.height * 0.5,
              child: Stack(
                children: <Widget>[
                  Container(
                    child: PageView(
                      key: cropKey,
                      controller: finalPageController,
                      children: pgChildren,
                    ),
                  ),
                  Positioned(
                      left: 0,
                      top: 0,
                      height: MediaQuery.of(context).size.height * 0.5,
                      width:
                          MediaQuery.of(context).size.height * 0.5 * (16 / 9),
                      child: IgnorePointer(
                        ignoring: true,
                        child: StreamBuilder(
                            stream: finalPageScrollNotifier.stream,
                            builder: (BuildContext ctx, snapshot) {
                              return AnimatedOpacity(
                                opacity: (snapshot.hasData &&
                                        snapshot.data["current_view"] ==
                                            "image")
                                    ? 1
                                    : 0,
                                duration: Duration(milliseconds: 200),
                                child: GridView.count(
                                    crossAxisCount: 4, children: meshView),
                              );
                            }),
                      )),
                  Positioned(
                      right: 0,
                      bottom: 0,
                      child: StreamBuilder(
                          stream: finalPageScrollNotifier.stream,
                          builder: (BuildContext ctx,
                              AsyncSnapshot visibilitySnapshot) {
                            return StreamBuilder(
                                stream: renderImageCtr.stream,
                                builder:
                                    (BuildContext ctx, AsyncSnapshot snapshot) {
                                  return AnimatedOpacity(
                                    opacity: (visibilitySnapshot.hasData &&
                                            visibilitySnapshot
                                                    .data["current_view"] ==
                                                "image")
                                        ? 1
                                        : 0,
                                    duration: Duration(milliseconds: 200),
                                    child: Container(
                                      child: (snapshot.hasData)
                                          ? Container(
                                              width: 200,
                                              height: 200,
                                              decoration: BoxDecoration(
                                                  image: DecorationImage(
                                                image:
                                                    MemoryImage(snapshot.data),
                                              )),
                                            )
                                          : Container(
                                              width: 200,
                                              height: 200,
                                              color: Colors.black,
                                              alignment: Alignment.center,
                                              child: Text(
                                                "No preview available",
                                                style: TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ),
                                    ),
                                  );
                                });
                          })),
                  Positioned(
                      left: 10,
                      bottom: 0,
                      width: MediaQuery.of(context).size.width - 20,
                      child: StreamBuilder(
                          stream: editorRangeCtr.stream,
                          builder: (BuildContext ctx, AsyncSnapshot snapshot) {
                            Map snapData;
                            if (snapshot.hasData) snapData = snapshot.data;
                            return AnimatedOpacity(
                              opacity:(snapshot.hasData && snapshot.data["visible"])? 1: 0,
                              duration: Duration(milliseconds: 200),
                              child: Container(
                                child: (snapshot.hasData && snapshot.data["visible"] )
                                    ? Slider(
                                        value: double.tryParse(snapData["position"]),
                                        activeColor: Colors.white,
                                        onChanged: (double curVal) {},
                                        min: 0,
                                        max: double.tryParse(snapData["duration"]),
                                        divisions: double.tryParse(snapData["duration"]).toInt(),
                                        label: snapData["position"],
                                      )
                                    : Container(),
                              ),
                            );
                          })),

                  Positioned(
                      left: 10,
                      bottom: 0,
                      width: MediaQuery.of(context).size.width - 20,
                      child: StreamBuilder(
                          stream: editorRangeCtr.stream,
                          builder: (BuildContext ctx, AsyncSnapshot snapshot) {
                            Map snapData;
                            if (snapshot.hasData) snapData = snapshot.data;
                            return AnimatedOpacity(
                              opacity: (snapshot.hasData && snapData["visible"])? 1 : 0,
                              duration: Duration(milliseconds: 200),
                              child: Container(
                                child: (snapshot.hasData && snapData["visible"])
                                    ? RangeSlider(
                                        activeColor: Colors.deepOrange,
                                        values: curVidEditorRange,
                                        min: 0,
                                        max: double.tryParse(snapData["duration"]),
                                        divisions: double.tryParse(snapData["duration"]).toInt(),
                                        labels: RangeLabels(
                                            snapData["range"].start.toInt().toString() + " s",
                                            snapData["range"].end.toInt().toString() + " s"),
                                        onChanged: (curValues) {
                                          if (curValues.end >=(curValues.start + 30))
                                            curVidEditorRange = RangeValues(curValues.start, curValues.start + 30);
                                          else curVidEditorRange = curValues;
                                          vplayers["$curVidEditorId"].seekTo(Duration(seconds:curValues.start.toInt()));
                                          vplayerPPt["$curVidEditorId"]["start"] =curValues.start.toString();
                                          vplayerPPt["$curVidEditorId"]["stop"] =curValues.end.toString();
                                          updateVEditorSlider();
                                        })
                                    : Container(),
                              ),
                            );
                          })),

                  //post loader
                  Positioned(
                      width: MediaQuery.of(context).size.width - 30,
                      left: 15,
                      top: (MediaQuery.of(context).size.height * .4) - 100,
                      child: StreamBuilder(
                          stream: _postProgressCtr.stream,
                          builder: (BuildContext ctx, AsyncSnapshot snapshot) {
                            return IgnorePointer(
                                ignoring: !(snapshot.hasData && snapshot.data["loading"]),
                                child: AnimatedOpacity(
                                  opacity: (snapshot.hasData &&snapshot.data["loading"]) ? 1 : 0,
                                  duration: Duration(milliseconds: 200),
                                  child: Container(
                                    padding: EdgeInsets.only(
                                        top: 32,
                                        bottom: 32,
                                        left: 42,
                                        right: 42),
                                    decoration: BoxDecoration(
                                      color: Color.fromRGBO(5, 5, 5, .9),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Container(
                                          child: Row(
                                            children: <Widget>[
                                              Container(
                                                width: 30,
                                                height: 30,
                                                alignment: Alignment.center,
                                                margin:
                                                    EdgeInsets.only(right: 16),
                                                child:
                                                    CircularProgressIndicator(
                                                      valueColor:AlwaysStoppedAnimation<Color>(Color.fromRGBO(200,200, 200, 1)),
                                                      strokeWidth: 7,
                                                    ),
                                              ),
                                              Expanded(
                                                child: Container(
                                                  child: Text((snapshot.hasData &&  snapshot.data["loading"])
                                                            ? snapshot.data["loading_text"]
                                                            : "Please wait ...",
                                                            overflow:TextOverflow.ellipsis,
                                                            style: TextStyle(
                                                              color: Colors.white
                                                            ),
                                                          ),
                                                )
                                              ),
                                            ],
                                          ),
                                        ), //loading text and spinner

                                        Container(
                                          margin: EdgeInsets.only(top: 5),
                                          child: Text(
                                            (snapshot.hasData &&  snapshot.data["loading"]) ? snapshot.data["loading_desc"] : "",
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white
                                            ),
                                          ),
                                        )//post details
                                      ],
                                    ),
                                  ),
                                ));
                          }))
                ],
              )),
          Container(
            margin: EdgeInsets.only(top: 12, bottom: 12),
            padding: EdgeInsets.only(left: 16, right: 16),
            child: TextField(
              controller: postCaption,
              style: TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                  hintText: "Say something about this post",
                  hintStyle: TextStyle(color: Colors.white, fontSize: 12),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white))),
            ),
          ),
          Container(
            padding: EdgeInsets.only(left: 16, right: 16),
            child: RaisedButton(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Color.fromRGBO(20, 20, 20, 1),
              textColor: Colors.white,
              onPressed: () {
                tryPost();
              },
              child: Text("POST"),
            ),
          )
        ],
      ),
    );
  } //the image editor dialog

  bool posting = false;
  String postingText = "";
  int finalSelectionCount=0;
  int processingCounter=0;
  int uploadedCount=0;
  int postingCount=0;

  tryPost() async {
    if (postCaption.text == "") {
      showToast(
          text: "Say something about this post",
          persistDur: Duration(seconds: 3));
      return;
    }
    if (posting == false) {
      posting = true;
      _postProgressCtr.add({
        "loading": posting, 
        "loading_text": "Please wait ...",
        "loading_desc": "Getting things ready"
      });

      String postUrl=globals.globBaseUrl + "?process_as=create_wall_post";
      //register the post in the server
      try{
        http.Response resp=await http.post(
          postUrl,
          body: {
            "user_id": globals.userId,
            "text": postCaption.text
          }
        );
        if(resp.statusCode == 200){
          var respObj= jsonDecode(resp.body);
          if(respObj["status"] == "success"){
            String postId= respObj["post_id"];

            //now process and send the selectections
            Directory kjutTmp = Directory(_appDir.path + "/kjut_tmp");
            await kjutTmp.create();
            finalSelectionCount = _fileIds.length;
            for(int k=0; k<finalSelectionCount; k++){
              String targFid= _fileIds[k];
              String b64Str="";
              String inPath= _finalSelection[k].path;
              List<String> brkInName= inPath.split("/");
              String inFName= brkInName.last;

              if(_selFilePPT[k]["type"] == AssetType.image){
                processingCounter++;
                //check if a cropped copy exists
                if(finalImageData["$targFid"]["file"]==""){
                  //not cropped copy send original
                  b64Str= base64Encode(_finalSelection[k].readAsBytesSync());    
                }
                else{
                  //send cropped data
                  b64Str= base64Encode(finalImageData["$targFid"]["file"]);
                }
                await tryPostFile(b64Str, postId, inFName, "image");
              }
              else if(_selFilePPT[k]["type"] == AssetType.video){
                //cut the video based on user selected if it exists or automatically cut the first 30 seconds
                String outFname= "kj" + DateTime.now().millisecondsSinceEpoch.toString() + ".mp4";
                String outPath=kjutTmp.path + "/$outFname";
                if(vplayerPPt.containsKey(targFid)){
                  //range has been selected by the user
                  int startPosInt=double.tryParse(vplayerPPt["$targFid"]["start"]).toInt();
                  String startPos="00:00:" + startPosInt.toString();
                  String endPos=vplayerPPt["$targFid"]["stop"];
                  int cutLen= double.tryParse(endPos).toInt() - startPosInt;
                  processingCounter++;
                  _postProgressCtr.add({
                      "loading": posting, 
                      "loading_text": "Please wait ...",
                      "loading_desc": "Processing $inFName ($processingCounter of $finalSelectionCount)"
                    });
                  int execResult=await _fffmpeg.execute("-ss $startPos -i $inPath  -t 00:00:$cutLen -crf 30 -c:v libx264 -c:a aac $outPath");
                  if(execResult == 0){
                    File tmpF= File(outPath);
                    if(await tmpF.exists()){
                      b64Str= base64Encode(tmpF.readAsBytesSync());
                      await tryPostFile(b64Str, postId, inFName, "video");
                      tmpF.delete();
                    }
                    else{
                      showToast(
                        text: "An error occured while processing $inFName",
                        persistDur: Duration(seconds: 15)
                      );
                    }
                  }
                  else{
                    showToast(
                      text: "An error occured while processing $inFName",
                      persistDur: Duration(seconds: 15)
                    );
                  }
                }
                else{
                  //no range was selected - so we cut the first 30 seconds
                  String startPos="00:00:00";
                  int cutLen= 30;
                  processingCounter++;
                  _postProgressCtr.add({
                      "loading": posting, 
                      "loading_text": "Please wait ...",
                      "loading_desc": "Processing $inFName ($processingCounter of $finalSelectionCount)"
                    });
                  int execResult= await _fffmpeg.execute("-ss $startPos -i $inPath  -t 00:00:$cutLen -crf 30 -c:v libx264 -c:a aac $outPath");
                  if(execResult == 0){
                    File tmpF= File(outPath);
                    if(await tmpF.exists()){
                      b64Str= base64Encode(tmpF.readAsBytesSync());
                      await tryPostFile(b64Str, postId, inFName, "video");
                      tmpF.delete();
                    }
                    else{
                      showToast(
                        text: "An error occured while processing $inFName",
                        persistDur: Duration(seconds: 15)
                      );
                    }
                  }
                  else{
                    showToast(
                      text: "An error occured while processing $inFName",
                      persistDur: Duration(seconds: 15)
                    );
                  }
                }
              }
            }
          }
        }
      }
      catch(ex){
        _postProgressCtr.add({
          "loading": false, 
          "loading_text": ""
        });
        showToast(
          text: "Kindly ensure that your device is connected to the internet",
          persistDur: Duration(seconds: 7)
        );
      }
    } //posting is false
  } //try post

  ///Posts the processed file data to the server
  Future tryPostFile(String b64, String formId, String fname, String ftype)async{
    try{
      postingCount++;
      double pcent= (uploadedCount/finalSelectionCount) * 100;
      String pcentStr= pcent.toStringAsFixed(1);
      _postProgressCtr.add({
        "loading": posting, 
        "loading_text": "Please wait ... ($pcentStr% completed)",
        "loading_desc": "Posting $fname ($postingCount of $finalSelectionCount)"
      });
      String postUrl= globals.globBaseUrl + "?process_as=upload_wall_post_file";
      http.Response resp= await http.post(
        postUrl,
        body: {
          "user_id": globals.userId,
          "post_id": formId,
          "file": b64,
          "position": "$uploadedCount",
          "total": "$finalSelectionCount",
          "ftype": ftype
        }
      );
      
      if(resp.statusCode == 200){
        var respObj= jsonDecode(resp.body);
        if(respObj["status"] == "success"){
          uploadedCount++;
          pcent= (uploadedCount/finalSelectionCount) * 100;
          if(uploadedCount >= finalSelectionCount){
            posting=false;
            _postProgressCtr.add({
              "loading": posting, 
              "loading_text": "Please wait ... ($pcent% completed)",
              "loading_desc": "Posting $fname ($postingCount of $finalSelectionCount)"
            });
            showToast(
              text: "Post was successfully completed!",
              persistDur: Duration(seconds: 7)
            );
            Future.delayed(
              Duration(seconds: 7),
              (){
                Navigator.of(context).pop();
                //Navigator.of(context).pop();
              }
            );
          }
          else{
            showToast(
              text: "Uploaded $fname ($pcent completed!)",
              persistDur: Duration(seconds: 12)
            );
          }
        }
      }
    }
    catch(ex){
      _postProgressCtr.add({
        "loading": false, 
        "loading_text": ""
      });
      showToast(
        text: "Kindly ensure that your device is proerly connected to the internet!",
        persistDur: Duration(seconds: 7)
      );
    }
  }//try posting file

}