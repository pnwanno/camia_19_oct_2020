import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:file_picker/file_picker.dart';

import '../globals.dart' as globals;

class NewWallPost extends StatefulWidget{
  _NewWallPost createState(){
    return _NewWallPost();
  }
}

class _NewWallPost extends State<NewWallPost>{
  @override
  initState(){
    super.initState();
  }
  int _postLimit=10;

  List<Map> _selectedFiles= List<Map>();
  StreamController _focFileChanged= StreamController.broadcast();
  int _focIndex=-1;

  Offset _cropPosOffSet= Offset(0, 0);
  double _cropwidth=0; double _cropheight=0;
  Offset _pointerPos;
  double _lastwidth=0; double _lastheight=0;

  BuildContext _pageContext;
  Size _screenSize;
  globals.KjToast _kjToast;
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize= MediaQuery.of(_pageContext).size;
    if(_kjToast == null){
      _kjToast= globals.KjToast(12.0, _screenSize, _toastCtr, _screenSize.height*.4);
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
                                      child: Icon(
                                        FlutterIcons.image_evi,
                                        color: Colors.grey,
                                        size: 120,
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
                                                                    fit: BoxFit.cover
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
                                    Container(
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
                                                  if(_focIndex>0){
                                                    _focIndex--;
                                                    setCropRect();
                                                    _focFileChanged.add("kjut");
                                                    Future.delayed(
                                                      Duration(milliseconds: 700),
                                                        (){
                                                        cropImage();
                                                        }
                                                    );
                                                  }
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
                                                  if(_focIndex<_selectedFiles.length-1){
                                                    _focIndex++;
                                                    setCropRect();
                                                    _focFileChanged.add("kjut");
                                                    Future.delayed(
                                                        Duration(milliseconds: 700),
                                                            (){
                                                          cropImage();
                                                        }
                                                    );
                                                  }
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
                            ), //
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                _kjToast,
              ],
            ),
          ),
          onFocusChange: (bool _isFocused){

          },
        ),
      ),
      onWillPop: ()async{
        Navigator.of(_pageContext).pop();
        return false;
      },
    );
  }//route's build context

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
                "start": "0"
              });
            }
          }
          else _exceededlimit=true;
        }
        _focIndex=_selectedFiles.length-1;
        setCropRect();
        _focFileChanged.add("kjut");
        Future.delayed(
          Duration(milliseconds: 500),
            (){
            cropImage();
            }
        );

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
                Future.delayed(
                  Duration(milliseconds: 200),
                    (){
                      cropImage();
                    }
                );
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
  Future<void> cropImage()async{
    RenderRepaintBoundary _rp= _cropKey.currentContext.findRenderObject();
    ui.Image _uiImage= await _rp.toImage();
    ByteData _bd= await _uiImage.toByteData(format:ui.ImageByteFormat.png);
    Uint8List _pngData= _bd.buffer.asUint8List();
    _globCropCtr.add(_pngData);
  }

  StreamController _globCropCtr= StreamController.broadcast();
  StreamController _toastCtr= StreamController.broadcast();
  StreamController _cropChangedNotifier= StreamController.broadcast();
  @override
  void dispose() {
    _toastCtr.close();
    _focFileChanged.close();
    _cropChangedNotifier.close();
    _cropMeshOpacityChangeNotifier.close();
    _globCropCtr.close();
    super.dispose();
  }//route's dispose method
}