import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import './theme_data.dart' as pageTheme;
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
  @override
  void initState() {
    super.initState();
    initDir();
  }

  List<String> _availableInterests;

  String _channelName="";
  String _channelDP="";
  String _channelID="";
  Directory _appDir;
  DBTables _dbTables= DBTables();
  initDir()async{
    if(_appDir == null){
      _appDir= await getApplicationDocumentsDirectory();
    }
    _availableInterests= globals.interestCat;
    Database _con= await _dbTables.tvProfile();
    List _result= await _con.rawQuery("select * from profile where status='ACTIVE'");
    if(_result.length == 1){
      _channelName=_result[0]["channel_name"];
      _channelNameCtr.text=_channelName;
      _websiteCtr.text=_result[0]["website"];
      _briefCtr.text=_result[0]["brief"];
      _channelDP=_result[0]["dp"];
      _channelID=_result[0]["channel_id"].toString();
      String _locInterests= _result[0]["interests"];
      if(_locInterests!=""){
        _myInterests= _locInterests.split(",");
      }
      _interestChangeNotifier.add("kjut");
      _profileUpdateNotifier.add("kjut");
    }
  }//get user's local data

  TextEditingController _channelNameCtr= TextEditingController();
  TextEditingController _websiteCtr= TextEditingController();
  FocusNode _websteNode= FocusNode();
  TextEditingController _briefCtr= TextEditingController();
  FocusNode _briefNode= FocusNode();
  List<String> _myInterests= [];

  BuildContext _pageContext;
  Size _screenSize;
  String _deviceTheme;
  @override
  Widget build(BuildContext context) {
    _pageContext= context;
    _screenSize=MediaQuery.of(_pageContext).size;
    _toastTop=_screenSize.height * .4;
    return WillPopScope(
      child: Scaffold(
        backgroundColor: pageTheme.bgColor,
        appBar: AppBar(
          backgroundColor: pageTheme.bgColorVar1,
          title: Container(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  margin: EdgeInsets.only(right: 7),
                  child: Icon(
                    FlutterIcons.tv_fea,
                    color: pageTheme.fontColor,
                    size: 16,
                  ),
                ),
                StreamBuilder(
                  stream: _profileUpdateNotifier.stream,
                  builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                    return Container(
                      child: Text(
                        _channelName,
                        style: TextStyle(
                          color: pageTheme.fontColor,
                          fontFamily: "ubuntu",
                          fontSize: 16
                        ),
                      ),
                    );
                  },
                )
              ],
            ),
          ),
          iconTheme: IconThemeData(
            color: pageTheme.fontColor
          ),
          actions: [
            Container(
              margin: EdgeInsets.only(right: 12),
              child: InkResponse(
                onTap: (){
                  updateProfile();
                },
                child: Ink(
                  child: Icon(
                    FlutterIcons.ios_save_ion,
                    color:pageTheme.profileIcons
                  ),
                ),
              ),
            ),//save icon
            Container(
              margin: EdgeInsets.only(right: 24),
              child: InkResponse(
                onTap: (){
                  Navigator.of(_pageContext).push(
                    MaterialPageRoute(
                      builder: (BuildContext _ctx){
                        return AddVideo(_channelID);
                      }
                    )
                  );
                },
                child: Ink(
                  child: Icon(
                      FlutterIcons.video_plus_mco,
                      color:pageTheme.profileIcons
                  ),
                ),
              ),
            ), //add video
          ],
        ),
        body: FocusScope(
          autofocus: true,
          child: Container(
            width: _screenSize.width,
            height: _screenSize.height,
            child: Stack(
              children: [
                Container(
                  padding: EdgeInsets.only(top: 16),
                  width: _screenSize.width, height: _screenSize.height,
                  child: ListView(
                    physics: BouncingScrollPhysics(),
                    children: [
                      Container(
                        alignment: Alignment.center,
                        margin: EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: (){
                            updateDP();
                          },
                          highlightColor: Colors.transparent,
                          child: Ink(
                            color: pageTheme.bgColorVar1,
                            child: Container(
                              child: Stack(
                                children: [
                                  Container(
                                    child: StreamBuilder(
                                      stream: _profileUpdateNotifier.stream,
                                      builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                        if(_channelDP==""){
                                          return Container(
                                            width: 100, height: 100,
                                            decoration: BoxDecoration(
                                              color: pageTheme.bgColorVar1
                                            ),
                                          );
                                        }
                                        return Container(
                                          width: 100,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(

                                          ),
                                          padding: _channelDP.length == 1 ? EdgeInsets.only(top: 16, bottom: 16) : EdgeInsets.only(),
                                          child: _channelDP.length == 1 ?
                                          Text(
                                            _channelDP.toUpperCase(),
                                            style: TextStyle(
                                                color: pageTheme.fontColor,
                                                fontSize: 32
                                            ),
                                          ):
                                          Container(
                                            width: 100, height: 110,
                                            decoration: BoxDecoration(
                                                image: DecorationImage(
                                                    image: FileImage(File(_appDir.path + "/camtv/$_channelDP"))
                                                )
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  Positioned(
                                    right: 12, top: 12,
                                    child: Icon(
                                      FlutterIcons.camera_ent,
                                      color: pageTheme.profileIcons,
                                      size: 13,
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),//channel DP

                      Container(
                        decoration: BoxDecoration(
                          color: pageTheme.bgColorVar1
                        ),
                        margin: EdgeInsets.only(bottom: 1),
                        padding: EdgeInsets.only(left: 16, right: 16, top: 9, bottom: 9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: EdgeInsets.only(bottom: 5),
                              padding: EdgeInsets.only(left: 9),
                              child: Text(
                                "Channel Name",
                                style: TextStyle(
                                  color: pageTheme.tvProfileLabel
                                ),
                              ),
                            ),
                            Container(
                              child: StreamBuilder(
                                stream: _profileUpdateNotifier.stream,
                                builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                  return Container(
                                    padding: EdgeInsets.only(left: 12, right: 12),
                                    decoration: BoxDecoration(
                                      color: pageTheme.bgColor
                                    ),
                                    child: TextField(
                                      controller: _channelNameCtr,
                                      decoration: InputDecoration(
                                        hintText: "Channel name",
                                        hintStyle: TextStyle(
                                          color: Colors.grey
                                        ),
                                        focusedBorder: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                      ),
                                      textInputAction: TextInputAction.next,
                                      onEditingComplete: (){
                                        FocusScope.of(context).requestFocus(_websteNode);
                                      },
                                      style: TextStyle(
                                        color: pageTheme.fontColor
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          ],
                        ),
                      ), //channel name

                      Container(
                        decoration: BoxDecoration(
                            color: pageTheme.bgColorVar1
                        ),
                        margin: EdgeInsets.only(bottom: 1),
                        padding: EdgeInsets.only(left: 16, right: 16, top: 9, bottom: 9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: EdgeInsets.only(bottom: 5),
                              padding: EdgeInsets.only(left: 9),
                              child: Text(
                                "Website",
                                style: TextStyle(
                                    color: pageTheme.tvProfileLabel
                                ),
                              ),
                            ),
                            Container(
                              child: StreamBuilder(
                                stream: _profileUpdateNotifier.stream,
                                builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                  return Container(
                                    padding: EdgeInsets.only(left: 12, right: 12),
                                    decoration: BoxDecoration(
                                      color: pageTheme.bgColor
                                    ),
                                    child: TextField(
                                      controller: _websiteCtr,
                                      decoration: InputDecoration(
                                          hintText: "Website",
                                          hintStyle: TextStyle(
                                              color: Colors.grey
                                          ),
                                          focusedBorder: InputBorder.none,
                                          enabledBorder: InputBorder.none
                                      ),
                                      focusNode: _websteNode,
                                      textInputAction: TextInputAction.next,
                                      keyboardType: TextInputType.url,
                                      onEditingComplete: (){
                                        FocusScope.of(context).requestFocus(_briefNode);
                                      },
                                      style: TextStyle(
                                        color: pageTheme.fontColor
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          ],
                        ),
                      ), //website

                      Container(
                        decoration: BoxDecoration(
                            color: pageTheme.bgColorVar1
                        ),
                        margin: EdgeInsets.only(bottom: 1),
                        padding: EdgeInsets.only(left: 16, right: 16, top: 9, bottom: 9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: EdgeInsets.only(bottom: 5),
                              padding: EdgeInsets.only(left: 9),
                              child: Text(
                                "About Channel",
                                style: TextStyle(
                                    color: pageTheme.tvProfileLabel
                                ),
                              ),
                            ),
                            Container(
                              child: StreamBuilder(
                                stream: _profileUpdateNotifier.stream,
                                builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                  return Container(
                                    padding: EdgeInsets.only(left: 12, right: 12),
                                    decoration: BoxDecoration(
                                      color: pageTheme.bgColor
                                    ),
                                    child: TextField(
                                      controller: _briefCtr,
                                      decoration: InputDecoration(
                                          hintText: "A bit about this channel",
                                          hintStyle: TextStyle(
                                              color: Colors.grey
                                          ),
                                          focusedBorder: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                      ),
                                      minLines: 3,
                                      maxLines: null,
                                      focusNode: _briefNode,
                                      textInputAction: TextInputAction.newline,
                                      style: TextStyle(
                                        color: pageTheme.fontColor
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          ],
                        ),
                      ), //brief

                      Container(
                        decoration: BoxDecoration(
                          color: pageTheme.bgColor
                        ),
                        padding: EdgeInsets.only(left: 16, right: 16, top: 9, bottom: 9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin:EdgeInsets.only(bottom: 5),
                              padding: EdgeInsets.only(left: 9),
                              child: Text(
                                "Interests",
                                style: TextStyle(
                                  color: pageTheme.tvProfileLabel
                                ),
                              ),
                            ),
                            Container(
                              child: StreamBuilder(
                                stream: _interestChangeNotifier.stream,
                                builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                  if(_availableInterests == null){
                                    return Container();
                                  }
                                  List<Widget> _liChildren= List<Widget>();
                                  int _kount= _availableInterests.length;
                                  for(int _k=0; _k<_kount; _k++){
                                    String _targInterest= _availableInterests[_k];
                                    _liChildren.add(Container(
                                      decoration: BoxDecoration(
                                        color: pageTheme.bgColorVar1
                                      ),
                                      margin: EdgeInsets.only(bottom: 1),
                                      child: CheckboxListTile(
                                        onChanged: (bool _curVal){
                                          if(_curVal){
                                            if(_myInterests.length<7){
                                              _myInterests.add(_targInterest);
                                              _interestChangeNotifier.add("kjut");
                                            }
                                            else{
                                              showLocalToast(
                                                text: "Maximum of 7 interests are allowed",
                                                duration: Duration(seconds: 3)
                                              );
                                            }
                                          }
                                          else{
                                            _myInterests.remove(_targInterest);
                                            _interestChangeNotifier.add("kjut");
                                          }
                                        },
                                        value: _myInterests.indexOf(_targInterest)>-1,
                                        title: Text(
                                          _targInterest,
                                          style: TextStyle(
                                            color: pageTheme.fontColor
                                          ),
                                        ),
                                        controlAffinity: ListTileControlAffinity.leading,
                                      ),
                                    ));
                                  }
                                  return Container(
                                    child: Wrap(
                                      children: _liChildren,
                                    ),
                                  );
                                },
                              ),
                            )
                          ],
                        ),
                      )
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
        Navigator.pop(_pageContext);
        return false;
      },
    );
  }//route's build method


  updateDP()async{
    try{
      File _pickedFile=await FilePicker.getFile(
        type: FileType.image
      );
      String _fpath=_pickedFile.path;
      List<String> _brkpath= _fpath.split("/");
      String _fname= _brkpath.last;
      List<String> _brkname= _fname.split(".");
      String _fext=_brkname.last;
      List<String> _acceptedExts=["jpg", "jpeg", "png", "gif"];
      if(_acceptedExts.indexOf(_fext)>-1){
        _showToast=true;
        _toastText="Uploading selection ...";
        _toastCtr.add("kjut");
        String _imageStr=base64Encode(_pickedFile.readAsBytesSync());
        try{
          http.Response _resp= await http.post(
            globals.globBaseTVURL + "?process_as=update_tv_channel_dp",
            body: {
              "user_id": globals.userId,
              "channel_id": _channelID,
              "ext": _fext,
              "image":_imageStr
            }
          );
          if(_resp.statusCode == 200){
            var _respObj= jsonDecode(_resp.body);
            if(_respObj["status"] == "success"){
              _toastText="Saving changes ...";
              _toastCtr.add("kjut");
              File _curDP= File(_appDir.path + "/camtv/$_channelDP");
              if(_channelDP!=""){
                _curDP.exists().then((_fexists) {
                  if(_fexists) _curDP.delete();
                });
              }
              String _serverDP= _respObj["file"];
              List<String> _brkSDP= _serverDP.split("/");
              String _serverDPName= _brkSDP.last;
              File _newDP= File(_appDir.path + "/camtv/$_serverDPName");
              http.get(_serverDP).then((_fetchDPResp){
                if(_fetchDPResp.statusCode == 200){
                  _newDP.writeAsBytes(_fetchDPResp.bodyBytes).then((value) async{
                    Database _locCon= await _dbTables.tvProfile();
                    _locCon.execute("update profile set dp='$_serverDPName' where channel_id='$_channelID'").then((value){
                      _channelDP=_serverDPName;
                      setState(() {

                      });
                    });
                    showLocalToast(
                      text: "Channel DP changed!",
                      duration: Duration(seconds: 5)
                    );
                  });
                }
              });
            }
            else{
              showLocalToast(
                  text: "Unaccepted image type",
                  duration: Duration(seconds: 7)
              );
            }
          }
        }
        catch(ex){
          showLocalToast(
            text: "Kindly ensure that your device has an active internet connection",
            duration: Duration(seconds: 7)
          );
        }
      }
      else{
        showLocalToast(
          text: "Unaccepted file type",
          duration: Duration(seconds: 7)
        );
      }
    }
    catch(ex){
    }
  }//update DP

  updateProfile()async{
    if(_channelNameCtr.text==""){
      showLocalToast(
        text: "Channel name is required",
        duration: Duration(seconds: 3)
      );
      return;
    }
    else if(_briefCtr.text==""){
      showLocalToast(
          text: "An about for this channel is required",
          duration: Duration(seconds: 3)
      );
      return;
    }
    else if(_myInterests.length<1){
      showLocalToast(
          text: "Pick at least a single interest for this channel",
          duration: Duration(seconds: 3)
      );
      return;
    }
    try{
      _showToast=true;
      _toastText="Updating profile ...";
      _toastCtr.add("kjut");
      http.Response _resp= await http.post(
        globals.globBaseTVURL + "?process_as=update_tv_channel_profile",
        body: {
          "user_id": globals.userId,
          "channel_id": _channelID,
          "channel_name": _channelNameCtr.text,
          "website": _websiteCtr.text,
          "brief": _briefCtr.text,
          "interests": jsonEncode(_myInterests)
        }
      );
      if(_resp.statusCode == 200){
        var _respObj= jsonDecode(_resp.body);
        if(_respObj["status"] == "success"){
          String _serverInterest=_respObj["interest"];
          Database _con= await _dbTables.tvProfile();
          _con.execute(
            "update profile set channel_name=?, website=?, brief=?, interests=? where channel_id=?",[
              _channelNameCtr.text,
            _websiteCtr.text, _briefCtr.text, _serverInterest,_channelID
          ]
          );
          showLocalToast(
            text: "Update was successfully completed",
            duration: Duration(seconds: 5)
          );
        }
        else{

        }
      }
    }
    catch(ex){
      showLocalToast(
          text: "Kindly ensure that your device is properly connected to the internet",
          duration: Duration(seconds: 3)
      );
      return;
    }
  }//update profile

  StreamController _profileUpdateNotifier= StreamController.broadcast();
  StreamController _interestChangeNotifier= StreamController.broadcast();
  @override
  void dispose() {
    _profileUpdateNotifier.close();
    _interestChangeNotifier.close();
    _toastCtr.close();
    _channelNameCtr.dispose();
    _websiteCtr.dispose();
    _briefCtr.dispose();
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