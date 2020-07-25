import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:liquid_progress_indicator/liquid_progress_indicator.dart';
import 'package:circular_clip_route/circular_clip_route.dart';

import '../globals.dart' as globals;
import '../dbs.dart';
import './add_video.dart';

class MyChannels extends StatefulWidget{
  _MyChannels createState(){
    return _MyChannels();
  }

  final channelId;
  MyChannels(this.channelId);
}

class _MyChannels extends State<MyChannels>{
  Directory _appDir;
  Directory _tvDir;
  String _globalsChannelID="";
  initState(){
    super.initState();
    _globalsChannelID=widget.channelId;
    initDir();
  }//route's init state

  updateProfile()async{
    if(_pageBusyOpacity==0){
      _pageBusyOpacity=1;
      _pageBusyCtr.add("kjut");
      String _locChannelID= _globalsChannelID;
      try{
        http.Response _resp= await http.post(
            globals.globBaseUrl + "?process_as=update_tv_profile",
            body: {
              "user_id": globals.userId,
              "channel_id": _locChannelID,
              "channel_name": _channelNameCtr.text,
              "about": _channelAbout.text,
              "website": _channelWebsite.text
            }
        );
        if(_resp.statusCode == 200){
          var _respObj= jsonDecode(_resp.body);
          if(_respObj["status"] == "success"){
            Database _con= await _dbTables.tvProfile();
            _con.execute("update profile set channel_name=?, website=?, brief=? where channel_id=?", [_channelNameCtr.text, _channelWebsite.text, _channelAbout.text, _locChannelID]).then((value) {
              _pageBusyOpacity=0;
              _pageBusyCtr.add("kjut");
              _kjToast.showToast(
                text: "Profile was updated successfully",
                duration: Duration(seconds: 1)
              );
              _editForm=false;
              _formEditCtrl.add("kjut");
            });
          }
        }
      }
      catch(ex){
        _kjToast.showToast(
          text: "Can't update profile - Offline mode",
          duration: Duration(seconds: 3)
        );
      }
    }
  }//update profile

  updateDp()async{
    try{
      FilePicker.getFile(type: FileType.image).then((_selFile){
        List<String> _brkfname=_selFile.path.split(".");
        String _fext= _brkfname.last;
        List<String> _allowedExts= ["gif", "jpg", "png", "jpeg"];
        if(_allowedExts.indexOf(_fext)>-1){
          _pageBusyOpacity=1;
          _pageBusyCtr.add("kjut");
          String _locChannelID= _globalsChannelID;
          _selFile.readAsBytes().then((_fbytes) {
            String _b64str= base64Encode(_fbytes);
            http.post(
                globals.globBaseUrl + "?process_as=update_tv_dp",
                body: {
                  "user_id": globals.userId,
                  "channel_id": _locChannelID,
                  "fstring": _b64str,
                  "ext": _fext
                }
            ).then((_resp){
              if(_resp.statusCode == 200){
                var _respObj= jsonDecode(_resp.body);
                if(_respObj["status"] == "success"){
                  String _retdpname= _respObj["fname"];
                  _dbTables.tvProfile().then((_con)async{
                    //get former dp
                    var _locresult= await _con.rawQuery("select dp from profile where channel_id='$_locChannelID'");
                    String _currentdp= _locresult[0]["dp"];
                    if(_currentdp.length > 1){
                      File _currenDPFile= File(_tvDir.path + "/$_currentdp");
                      _currenDPFile.exists().then((_fexists){
                        if(_fexists){
                          _currenDPFile.delete();
                        }
                      });
                    }
                    _con.execute(
                      "update profile set dp='$_retdpname' where channel_id='$_locChannelID'"
                    ).then((value) {
                      File _newdpfile= File(_tvDir.path+ "/$_retdpname");
                      _newdpfile.writeAsBytes(_fbytes).then((value){
                        _pageBusyOpacity=0;
                        _pageBusyCtr.add("kjut");
                        genChannelDp();
                      });
                    });
                  });
                }
              }
            });
          });
        }
        else{
          _kjToast.showToast(
            text: "Unaccepted image type",
            duration: Duration(seconds: 3)
          );
        }
      });
    }
    catch(ex){
      _kjToast.showToast(
        text: "Can't update dp in offline mode",
        duration: Duration(seconds: 3)
      );
    }
  }//update dp

  DBTables _dbTables= DBTables();
  initDir()async{
    _appDir= await getApplicationDocumentsDirectory();
    _tvDir= Directory(_appDir.path + "/camtv");
    Database _con= await _dbTables.tvProfile();
    var _result= await _con.rawQuery("select * from profile where channel_id=?", [_globalsChannelID]);
    if(_result.length == 1){
      genChannelDp();
    }
  }

  ///A convenient function to get channel dp
  genChannelDp() async{
    String _locchannelid= _globalsChannelID;
    Database _con=await _dbTables.tvProfile();
    String _dp="C";
    var _result= await _con.rawQuery("select * from profile where channel_id=?", [_locchannelid]);
    if(_result.length == 1){
      _globalChannelName= _result[0]["channel_name"];
      _channelNameCtr.text= _globalChannelName;
      _channelAbout.text= _result[0]["brief"];
      _channelWebsite.text= _result[0]["website"];
      _dp=_result[0]["dp"];
    }
    if(_dp.length == 1){
      _channeldp= Container(
        alignment: Alignment.center,
        child: CircleAvatar(
          radius: 24,
          child: Text(
              _dp
          ),
        ),
      );
    }
    else{
      _channeldp= Container(
        alignment: Alignment.center,
        child: CircleAvatar(
          radius: 24,
          backgroundImage: FileImage(File(_tvDir.path + "/$_dp")),
        ),
      );
    }
    _pageLoadedNotifier.add("kjut");
  }//convenience get channel dp

  final GlobalKey _addnewvideokey= GlobalKey();
  List<String> _uploadType= ["Uploads", "Live"];
  List<DropdownMenuItem> _uploadTypeItems;
  StreamController _uploadTypeChangeNotifier= StreamController.broadcast();

  TextEditingController _channelNameCtr= TextEditingController();
  TextEditingController _channelAbout= TextEditingController();
  TextEditingController _channelWebsite= TextEditingController();
  bool _editForm=false;
  StreamController _formEditCtrl= StreamController.broadcast();
  Widget pageBody(){
    if(_uploadTypeItems==null){
      _uploadTypeItems= List<DropdownMenuItem>();
      int _kount= _uploadType.length;
      for(int _k=0; _k<_kount; _k++){
        _uploadTypeItems.add(
          DropdownMenuItem(
              child: Text(
                _uploadType[_k]
              ),
            value: _k,
          )
        );
      }
    }
    return Container(
      padding: EdgeInsets.only(top:16),
      child: ListView(
        children: <Widget>[
          Container(
            child: StreamBuilder(
              stream: _pageLoadedNotifier.stream,
              builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                if(_snapshot.hasData){
                  return Container(
                    padding: EdgeInsets.only(left: 24, right: 24),
                    child: Form(
                      child: Column(
                        children: <Widget>[
                          Container(
                            child: Row(
                              children: <Widget>[
                                GestureDetector(
                                  onTap: (){
                                    updateDp();
                                  },
                                  child: _channeldp,
                                ),
                                Expanded(
                                  child: TweenAnimationBuilder(
                                    tween: Tween<double>(
                                        begin: 0, end: 12
                                    ),
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.linear,
                                    builder: (BuildContext _twCtx, _curval, __){
                                      return Container(
                                        margin: EdgeInsets.only(left:_curval),
                                        child: StreamBuilder(
                                          stream: _formEditCtrl.stream,
                                          builder: (BuildContext _ctx, snapshot){
                                            return TextFormField(
                                              readOnly:!_editForm,
                                              style: TextStyle(
                                                  color: Colors.white
                                              ),
                                              maxLines: 1,
                                              controller: _channelNameCtr,
                                              decoration: InputDecoration(
                                                  focusedBorder: InputBorder.none,
                                                  enabledBorder: InputBorder.none
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                )
                              ],
                            ),
                          ), //dp and channel name
                          Container(
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(25, 25, 25, 1),
                              borderRadius: BorderRadius.circular(7)
                            ),
                            margin: EdgeInsets.only(top:9),
                            padding:EdgeInsets.only(left: 12, right: 12),
                            child: StreamBuilder(
                              stream: _formEditCtrl.stream,
                              builder: (BuildContext _aboutCtx, AsyncSnapshot _aboutshot){
                                return TextFormField(
                                  controller: _channelAbout,
                                  readOnly: !_editForm,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "Brief about this channel",
                                    hintStyle: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic
                                    ),
                                    focusedBorder: InputBorder.none,
                                    enabledBorder: InputBorder.none
                                  ),
                                  minLines: 3, maxLines: 3,
                                );
                              },
                            ),
                          ), //about channel
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(12)
                            ),
                            margin: EdgeInsets.only(top: 12),
                            padding:EdgeInsets.only(left: 12, right: 12),
                            child: StreamBuilder(
                              builder: (BuildContext _websiteCtx, AsyncSnapshot _webshot){
                                return TextFormField(
                                  readOnly: !_editForm,
                                  maxLines: 1,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12
                                  ),
                                  controller: _channelWebsite,
                                  decoration: InputDecoration(
                                      hintStyle: TextStyle(
                                          fontSize: 12,
                                          color: Colors.black,
                                          fontStyle: FontStyle.italic
                                      ),
                                      hintText: "Website",
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none
                                  ),
                                );
                              },
                            )
                          ), //channel's website
                          Container(
                            alignment: Alignment.center,
                            margin: EdgeInsets.only(top:16),
                            child: StreamBuilder(
                              stream:_formEditCtrl.stream,
                              builder: (BuildContext _submitCtx, AsyncSnapshot _btnshot){
                                return GestureDetector(
                                  onTap: (){
                                    updateProfile();
                                  },
                                  child: AnimatedOpacity(
                                    opacity: _editForm ? 1 : 0,
                                    duration: Duration(milliseconds: 300),
                                    child: AnimatedContainer(
                                      alignment: Alignment.center,
                                      padding: EdgeInsets.only(top: 12, bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Color.fromRGBO(20, 20, 20, 1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.black
                                        )
                                      ),
                                      duration: Duration(milliseconds: 300),
                                      width: _editForm ? _screenSize.width : _screenSize.width * .5,
                                      child: Text(
                                        "UPDATE PROFILE",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                }
                else{
                  return Container(
                    height: _screenSize.height,
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(),
                  );
                }
              },
            ),
          ),//profile data
          Container(
            margin: EdgeInsets.only(top:7, bottom: 7),
            padding: EdgeInsets.only(left:24, right: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  margin:EdgeInsets.only(right:12),
                  child: Text(
                    "Your Videos",
                    style: TextStyle(
                      fontFamily: "ubuntu",
                      color: Colors.white,
                      fontSize: 13
                    ),
                  ),
                ),

                Expanded(
                  child: Container(
                    child: StreamBuilder(
                      stream: _uploadTypeChangeNotifier.stream,
                      builder: (BuildContext _ctx, _snapshot){
                        return DropdownButton(
                          isExpanded: false,
                          dropdownColor: Color.fromRGBO(20, 20, 20, 1),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white
                            ),
                            hint: Text(
                                _snapshot.hasData ? _uploadType[_snapshot.data] : _uploadType[0],
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12
                              ),
                            ),
                            items: _uploadTypeItems,
                            onChanged: (_newVal){
                              _uploadTypeChangeNotifier.add(_newVal);
                            }
                        );
                      },
                    ),
                  ),
                ),//the dropdown list of upload types

                Container(
                  key: _addnewvideokey,
                  margin: EdgeInsets.only(left:12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkResponse(
                      onTap: (){
                        Navigator.of(_pageContext).push(
                          CircularClipRoute(
                              expandFrom: _addnewvideokey.currentContext,
                              builder: (BuildContext _ctx){
                                return AddVideo(_globalsChannelID);
                              }
                          )
                        );
                      },
                      child: Icon(
                        FlutterIcons.video_plus_mco,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),//select video type, add new video
          Container(
            child: FutureBuilder(
              builder: (BuildContext _ctx, _snapshot){
                if(_snapshot.hasData){
                  return _snapshot.data;
                }
                else{
                  return Container(
                    height: 120,
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                    ),
                  );
                }
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _channeldp;
  String _globalChannelName= globals.fullname;
  BuildContext _pageContext;
  Size _screenSize;
  globals.KjToast _kjToast;
  @override
  Widget build(BuildContext context) {
    _pageContext= context;
    _screenSize= MediaQuery.of(_pageContext).size;
    if(_kjToast== null){
      _kjToast= globals.KjToast(12, _screenSize, _toastCtr, _screenSize.height * .4);
    }
    return Scaffold(
      backgroundColor: Color.fromRGBO(32, 32, 32, 1),
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(20, 20, 20, 1),
        title: Container(
          child: Row(
            children: <Widget>[
              Container(
                margin: EdgeInsets.only(right: 12),
                child: Icon(
                  FlutterIcons.tv_fea
                ),
              ),
              StreamBuilder(
                stream: _pageLoadedNotifier.stream,
                builder: (BuildContext _ctx, snapshot){
                  return Text(
                      _globalChannelName
                  );
                },
              )
            ],
          ),
        ),
      ),
      body: FocusScope(
        child: Container(
          child: Stack(
            children: <Widget>[
              pageBody(),
              Positioned(
                right: 24, top: 20,
                child: Material(
                  color: Colors.transparent,
                  child: InkResponse(
                    onTap: (){
                      _editForm =!_editForm;
                      _formEditCtrl.add("kjut");
                    },
                    child: Icon(
                      FlutterIcons.account_edit_mco,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              _kjToast,
              Positioned(
                left: 0, bottom: _screenSize.height * .4,
                child: IgnorePointer(
                  child: StreamBuilder(
                    stream: _pageBusyCtr.stream,
                    builder: (BuildContext _ctx, AsyncSnapshot snapshot){
                      return AnimatedOpacity(
                        opacity: _pageBusyOpacity,
                        duration: Duration(milliseconds: 300),
                        child: Container(
                          width: _screenSize.width,
                          alignment: Alignment.center,
                          child: Stack(
                            children: <Widget>[
                              LiquidCustomProgressIndicator(
                                direction: Axis.vertical,
                                shapePath: globals.logoPath(Size(120, 111)),
                              ),
                              Positioned(
                                bottom: 46, left:30,
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
                                  "Please wait...",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ), //page busy cue
            ],
          ),
        ),
        onFocusChange: (bool _isFocused){

        },
      ),
    );
  }//route's build method

  double _pageBusyOpacity=0;
  StreamController _pageBusyCtr= StreamController.broadcast();
  StreamController _pageLoadedNotifier= StreamController.broadcast();
  StreamController _toastCtr= StreamController.broadcast();
  @override
  void dispose() {
    super.dispose();
    _toastCtr.close();
    _pageLoadedNotifier.close();
    _pullRefreshCtr.close();
    _formEditCtrl.close();
    _channelNameCtr.dispose();
    _pageBusyCtr.close();
    _uploadTypeChangeNotifier.close();
  }//route's dispose method

  double pullRefreshHeight=0;
  double pullRefreshLoadHeight=80;
  StreamController _pullRefreshCtr= StreamController.broadcast();
  ScrollController _wallScrollCtr= ScrollController();

  ///This is the container placed as the first child of the listview
  ///to show a pull-to-refresh cue
  Widget pullToRefreshContainer(){
    return StreamBuilder(
      stream: _pullRefreshCtr.stream,
      builder: (BuildContext ctx, AsyncSnapshot snapshot){
        return AnimatedContainer(
          duration: Duration(milliseconds: 300),
          height: pullRefreshHeight,
          color: Color.fromRGBO(30, 30, 30, 1),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                  bottom: pullRefreshHeight - pullRefreshLoadHeight - 20,
                  child: Container(
                    alignment: Alignment.center,
                    child: Container(
                        width: 50, height: 50,
                        alignment: Alignment.center,
                        child: pullRefreshHeight< pullRefreshLoadHeight ?
                        CircularProgressIndicator(
                          value: pullRefreshHeight/pullRefreshLoadHeight,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                          strokeWidth: 3,
                        ):
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                          strokeWidth: 3,
                        )
                    ),
                  )
              )
            ],
          ),
        );
      },
    );
  }//pull to refresh container

  ///Pass a listview as child widget to this widget
  Widget kjPullToRefresh({Widget child}){
    return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerUp: (PointerUpEvent pue){
          if(pullRefreshHeight< pullRefreshLoadHeight){
            pullRefreshHeight =0;
            _pullRefreshCtr.add("kjut");
          }
          else{
            Future.delayed(
                Duration(milliseconds: 1500),
                    (){
                  //call the refresh function
                  pullRefreshHeight=0;
                  _pullRefreshCtr.add("kjut");

                }
            );
          }
        },
        onPointerMove: (PointerMoveEvent pme){
          Offset _delta= pme.delta;
          if(_wallScrollCtr.position.atEdge && !_delta.direction.isNegative){
            double dist= math.sqrt(_delta.distanceSquared);
            if(pullRefreshHeight <pullRefreshLoadHeight){
              pullRefreshHeight +=(dist/3);
              _pullRefreshCtr.add("kjut");
            }
          }
        },
        child: child
    );
  }//kjut pull to refresh


  genCmtvPath(){
    Path _cmtvpath= Path();
    Size _logo= Size(70, 54);

    _cmtvpath.lineTo(_logo.width * 0.08, _logo.height * 1.13);
    _cmtvpath.cubicTo(_logo.width * 0.05, _logo.height * 1.11, _logo.width * 0.04, _logo.height * 1.09, _logo.width * 0.03, _logo.height * 1.05);
    _cmtvpath.cubicTo(_logo.width * 0.01, _logo.height, 0, _logo.height * 0.96, 0, _logo.height * 0.88);
    _cmtvpath.cubicTo(0, _logo.height * 0.74, _logo.width * 0.02, _logo.height * 0.65, _logo.width * 0.07, _logo.height * 0.61);
    _cmtvpath.cubicTo(_logo.width * 0.08, _logo.height * 0.6, _logo.width * 0.09, _logo.height * 0.6, _logo.width * 0.12, _logo.height * 0.6);
    _cmtvpath.cubicTo(_logo.width * 0.16, _logo.height * 0.6, _logo.width * 0.16, _logo.height * 0.6, _logo.width * 0.18, _logo.height * 0.61);
    _cmtvpath.cubicTo(_logo.width / 5, _logo.height * 0.63, _logo.width * 0.23, _logo.height * 0.68, _logo.width * 0.24, _logo.height * 0.73);
    _cmtvpath.cubicTo(_logo.width * 0.26, _logo.height * 0.79, _logo.width * 0.26, _logo.height * 0.79, _logo.width * 0.22, _logo.height * 0.79);
    _cmtvpath.cubicTo(_logo.width * 0.18, _logo.height * 0.79, _logo.width * 0.17, _logo.height * 0.78, _logo.width * 0.16, _logo.height * 0.76);
    _cmtvpath.cubicTo(_logo.width * 0.15, _logo.height * 0.74, _logo.width * 0.14, _logo.height * 0.74, _logo.width * 0.13, _logo.height * 0.74);
    _cmtvpath.cubicTo(_logo.width * 0.11, _logo.height * 0.74, _logo.width * 0.1, _logo.height * 0.75, _logo.width * 0.09, _logo.height * 0.79);
    _cmtvpath.cubicTo(_logo.width * 0.09, _logo.height * 0.83, _logo.width * 0.08, _logo.height * 0.9, _logo.width * 0.09, _logo.height * 0.94);
    _cmtvpath.cubicTo(_logo.width * 0.1, _logo.height, _logo.width * 0.14, _logo.height * 1.02, _logo.width * 0.16, _logo.height * 0.97);
    _cmtvpath.cubicTo(_logo.width * 0.16, _logo.height * 0.97, _logo.width * 0.17, _logo.height * 0.95, _logo.width * 0.17, _logo.height * 0.95);
    _cmtvpath.cubicTo(_logo.width * 0.17, _logo.height * 0.95, _logo.width / 5, _logo.height * 0.95, _logo.width / 5, _logo.height * 0.95);
    _cmtvpath.cubicTo(_logo.width / 4, _logo.height * 0.95, _logo.width / 4, _logo.height * 0.95, _logo.width * 0.24, _logo.height);
    _cmtvpath.cubicTo(_logo.width * 0.23, _logo.height * 1.05, _logo.width / 5, _logo.height * 1.1, _logo.width * 0.18, _logo.height * 1.12);
    _cmtvpath.cubicTo(_logo.width * 0.16, _logo.height * 1.14, _logo.width * 0.1, _logo.height * 1.14, _logo.width * 0.08, _logo.height * 1.13);
    _cmtvpath.cubicTo(_logo.width * 0.08, _logo.height * 1.13, _logo.width * 0.08, _logo.height * 1.13, _logo.width * 0.08, _logo.height * 1.13);
    return _cmtvpath;
  }
}