import "dart:async";
import 'dart:io';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../dbs.dart';
import '../globals.dart' as globals;
import './profile.dart';

class EditWallProfile extends StatefulWidget{
  _EditWallProfile createState(){
    return _EditWallProfile();
  }
}

class _EditWallProfile extends State<EditWallProfile>{
  @override
  initState(){
    super.initState();
    fetchData();
    int _interestCount= _interestCat.length;
    for(int _k=0; _k<_interestCount; _k++){
      String _targInterst= _interestCat[_k];
      _interestChildren.add(
        StreamBuilder(
          stream: _interestChangedNotifier.stream,
          builder: (BuildContext _ctx, _interestShot){
            return Container(
              width: _screenSize.width > 450 ? _screenSize.width/2.2 : double.infinity,
              margin: EdgeInsets.only(right: 7, bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkResponse(
                  onTap: (){
                    if(_myInterests.indexOf(_targInterst)>-1){
                      _myInterests.remove(_targInterst);
                    }
                    else{
                      if(_myInterests.length == 5){
                        showQuickToast("Only 5 fields can be selected", Duration(seconds: 3));
                      }
                      else _myInterests.add(_targInterst);
                    }
                    _interestChangedNotifier.add("kjut");
                  },
                  child: Container(
                    padding: EdgeInsets.only(left: 9, right: 9, top: 5, bottom: 5),
                    decoration: BoxDecoration(
                        color: Color.fromRGBO(30, 30, 30, 1),
                        borderRadius: BorderRadius.circular(7)
                    ),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(7)
                          ),
                          child: Checkbox(
                            onChanged: (bool _isChecked){
                              if(_isChecked){
                                if(_myInterests.length == 5) showQuickToast("Only 5 fields can be selected", Duration(seconds: 3));
                                else _myInterests.add(_targInterst);
                              }
                              else _myInterests.remove(_targInterst);
                              _interestChangedNotifier.add("kjut");
                            },
                            value: _myInterests.indexOf(_targInterst) > -1,
                          ),
                        ),
                        Container(
                          margin: EdgeInsets.only(left: 12),
                          child: Text(
                            _targInterst,
                            maxLines: 2,
                            softWrap: true,
                            style: TextStyle(
                                color: Colors.white
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        )
      );
    }
  }//route's init state

  showQuickToast(String _text, Duration duration){
    _showToast=true;
    _toastText=_text;
    _localToastCtr.add("kjut");
    Future.delayed(
        duration,
        (){
          _showToast=false;
          _localToastCtr.add("kjut");
        }
    );
  }

  List<Widget> _interestChildren= List<Widget>();
  List<String> _interestCat;

  Directory _appDir;
  String _userDP="";
  DBTables _dbTables= DBTables();
  List _userData= List();
  List<String> _myInterests= List();
  fetchData()async{
    _interestCat=globals.interestCat;
    _appDir= await getApplicationDocumentsDirectory();
    Database _con= await _dbTables.myProfileCon();
    _userData=await _con.rawQuery("select * from user_profile where status='active'");
    if(_userData.length == 1){
      _userDP=_userData[0]["dp"];
      if(_userDP.length>1){
        _userDP= _appDir.path + "/wall_dir/$_userDP";
      }
      String _interestString= _userData[0]["interests"];
      if(_interestString.length>0)_myInterests=_interestString.split(",");
      _usernameCtr.text= _userData[0]["username"];
      _websiteCtr.text= _userData[0]["website"];
      _briefCtr.text= _userData[0]["brief"];
      _localDataAvailableNotifier.add("kjut");
    }
  }//fetch data

  changeDp()async{
    _showToast=true;
    try{
      File _selected= await FilePicker.getFile(
        type: FileType.image,
        onFileLoading: (fps){
          _toastText="Loading image ...";
        }
      );
      String _selpath= _selected.path;
      List<String> _brkpath= _selpath.split("/");
      String _selname= _brkpath.last;
      List<String> _brkname= _selname.split(".");
      String _selext=_brkname.last;
      List<String> _acceptedExts=["jpg", "jpeg", "png", "gif"];
      String _b64Str= base64Encode(_selected.readAsBytesSync());
      if(_acceptedExts.indexOf(_selext)>-1){
        _toastText="Saving online";
        _localToastCtr.add("kjut");
        http.Response _resp= await http.post(
          globals.globBaseUrl + "?process_as=update_wall_dp",
          body: {
            "user_id": globals.userId,
            "ext": _selext,
            "image": _b64Str
          }
        );
        if(_resp.statusCode == 200){
          var _respObj= jsonDecode(_resp.body);
          if(_respObj["status"] == "error"){
            showQuickToast("Unaccepted Image file", Duration(seconds: 5));
          }
          else if(_respObj["status"] == "success"){
            _toastText="Saving locally";
            _localToastCtr.add("kjut");
            Database _con= await _dbTables.myProfileCon();

            //delete the former dp
            var _res= await _con.rawQuery("select dp from user_profile where status='active'");
            if(_res.length>0){
              String _olddpname= _res[0]["dp"];
              File _olddpf= File(_appDir.path + "/wall_dir/$_olddpname");
              _olddpf.exists().then((bool _fexists){
                if(_fexists) _olddpf.delete();
              });
            }

            String _locfname= _respObj["filename"];
            _con.execute("update user_profile set dp=? where status='active'", [_locfname]);
            _userDP= _appDir.path + "/wall_dir/$_locfname";
            File _userDPF= File(_userDP);
            _userDPF.writeAsBytesSync(_selected.readAsBytesSync());
            showQuickToast("DP Changed!", Duration(seconds: 2));
          }
        }
      }
      else{
        showQuickToast("Unaccepted Image file", Duration(seconds: 5));
      }
    }
    catch(ex){
      showQuickToast("Device offline - kindly get connected and try again", Duration(seconds: 5));
    }
  }// change dp

  bool _saving=false;
  saveProfile()async{
    if(_myInterests.length<1){
      showQuickToast("Pick at least one field of interest", Duration(seconds: 5));
    }
    else if(_usernameCtr.text == ""){
      showQuickToast("Username is required", Duration(seconds: 5));
    }
    else{
      try{
        if(_saving == false){
          _saving=true;
          String _locInterest= jsonEncode(_myInterests);
          _showToast=true;
          _toastText="Saving, please wait ...";
          _localToastCtr.add("kjut");
          http.Response _resp= await http.post(
              globals.globBaseUrl +"?process_as=update_wall_profile",
              body: {
                "user_id" : globals.userId,
                "username": _usernameCtr.text,
                "website" : _websiteCtr.text,
                "brief": _briefCtr.text,
                "interests": _locInterest
              }
          );

          if(_resp.statusCode == 200){
            var _respObj= jsonDecode(_resp.body);
            if(_respObj["status"] == "success"){
              Database _con= await _dbTables.myProfileCon();
              _con.execute("update user_profile set username=?, website=?, brief=?, interests=? where status='active'", [
                _usernameCtr.text,
                _websiteCtr.text,
                _briefCtr.text,
                _myInterests.join(",")
              ]);
              showQuickToast("Update was successful!", Duration(seconds: 3));
            }
            else if(_respObj["status"] == "error"){
              showQuickToast(_respObj["message"], Duration(seconds: 5));
            }
            _saving=false;
          }
        }
      }
      catch(ex){
        _saving=false;
        showQuickToast("Kindly ensure that your device is connected to the internet", Duration(seconds: 5));
      }
    }
  }//save profile

  StreamController _localDataAvailableNotifier= StreamController.broadcast();

  BuildContext _pageContext;
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize= MediaQuery.of(_pageContext).size;
    return WillPopScope(
      child: Scaffold(
        backgroundColor: Color.fromRGBO(32, 32, 32, 1),
        appBar: AppBar(
          backgroundColor: Color.fromRGBO(26, 26, 26, 1),
          title: Text(
            "Edit Profile"
          ),
          actions: [
            Container(
              child: Material(
                color: Colors.transparent,
                child: InkResponse(
                  onTap: (){
                    saveProfile();
                  },
                  child: Icon(
                    FlutterIcons.content_save_edit_mco,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.only(left: 12, right: 24),
              child: Material(
                color: Colors.transparent,
                child: InkResponse(
                  onTap: (){
                    Navigator.of(_pageContext).push(
                      MaterialPageRoute(
                        builder: (BuildContext _ctx){
                          return WallProfile(globals.userId, username: _userData[0]["username"],);
                        }
                      )
                    );
                  },
                  child: Icon(
                    FlutterIcons.user_fea,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          ],
        ),

        body: FocusScope(
          child: Container(
            width: _screenSize.width, height: _screenSize.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  padding: EdgeInsets.only(top: 24, left: 16, right: 16),
                  child: StreamBuilder(
                    stream: _localDataAvailableNotifier.stream,
                    builder: (BuildContext _ctx, _snapshot){
                      if(_snapshot.hasData){
                        return ListView(
                          physics: BouncingScrollPhysics(),
                          children: [
                            StreamBuilder(
                              stream:_dpchangeNotifier.stream,
                              builder: (BuildContext _ctx, AsyncSnapshot _dpshot){
                                return GestureDetector(
                                  onTap: (){
                                    changeDp();
                                  },
                                  child: Container(
                                    margin: EdgeInsets.only(bottom: 24),
                                    child: Column(
                                      children: [
                                        Container(
                                          margin: EdgeInsets.only(bottom: 12),
                                          alignment: Alignment.center,
                                          child: _userDP.length == 1 ?
                                          CircleAvatar(
                                            radius: 32,
                                            backgroundColor: Colors.orangeAccent,
                                            child: Text(
                                                _userDP.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 32,
                                                color: Colors.white
                                              ),
                                            ),
                                          ):CircleAvatar(
                                            radius: 32,
                                            backgroundImage: FileImage(File(_userDP)),
                                          ),
                                        ),
                                        Container(
                                          child: Text(
                                              "Change Profile Photo",
                                            style: TextStyle(
                                              color: Colors.blue
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),//dp and dp changer

                            Container(
                              margin:EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin:EdgeInsets.only(bottom: 5, left: 12),
                                    child: Text(
                                      "Username",
                                      style: TextStyle(
                                        color: Color.fromRGBO(120, 120, 120, 1)
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding:EdgeInsets.only(left: 12, right: 12),
                                    decoration:BoxDecoration(
                                      color: Color.fromRGBO(30, 30, 30, 1),
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Color.fromRGBO(60, 60, 60, 1)
                                        )
                                      )
                                    ),
                                    child: TextField(
                                      controller:_usernameCtr,
                                      decoration: InputDecoration(
                                        hintText: "Username",
                                        hintStyle: TextStyle(
                                          color: Colors.grey
                                        ),
                                        focusedBorder: InputBorder.none,
                                        enabledBorder: InputBorder.none
                                      ),
                                      style: TextStyle(
                                        color: Colors.white
                                      ),
                                      onEditingComplete: (){
                                        FocusScope.of(_pageContext).requestFocus(_websiteNode);
                                      },
                                      textInputAction:TextInputAction.next,
                                    ),
                                  )
                                ],
                              ),
                            ),//username
                            Container(
                              margin:EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin:EdgeInsets.only(bottom: 5, left: 12),
                                    child: Text(
                                      "Website",
                                      style: TextStyle(
                                          color: Color.fromRGBO(120, 120, 120, 1)
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding:EdgeInsets.only(left: 12, right: 12),
                                    decoration:BoxDecoration(
                                        color: Color.fromRGBO(30, 30, 30, 1),
                                        border: Border(
                                            bottom: BorderSide(
                                                color: Color.fromRGBO(60, 60, 60, 1)
                                            )
                                        )
                                    ),
                                    child: TextField(
                                      controller:_websiteCtr,
                                      decoration: InputDecoration(
                                          hintText: "Website or social link",
                                          hintStyle: TextStyle(
                                              color: Colors.grey
                                          ),
                                          focusedBorder: InputBorder.none,
                                          enabledBorder: InputBorder.none
                                      ),
                                      style: TextStyle(
                                          color: Colors.white
                                      ),
                                      onEditingComplete: (){
                                        FocusScope.of(_pageContext).requestFocus(_briefNode);
                                      },
                                      textInputAction:TextInputAction.next,
                                      focusNode: _websiteNode,
                                    ),
                                  )
                                ],
                              ),
                            ),//website
                            Container(
                              margin:EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin:EdgeInsets.only(bottom: 5, left: 12),
                                    child: Text(
                                      "About you",
                                      style: TextStyle(
                                          color: Color.fromRGBO(120, 120, 120, 1)
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding:EdgeInsets.only(left: 12, right: 12),
                                    decoration:BoxDecoration(
                                        color: Color.fromRGBO(30, 30, 30, 1),
                                        border: Border(
                                            bottom: BorderSide(
                                                color: Color.fromRGBO(60, 60, 60, 1)
                                            )
                                        )
                                    ),
                                    child: TextField(
                                      controller:_briefCtr,
                                      decoration: InputDecoration(
                                          hintText: "Say something about this account",
                                          hintStyle: TextStyle(
                                              color: Colors.grey
                                          ),
                                          focusedBorder: InputBorder.none,
                                          enabledBorder: InputBorder.none
                                      ),
                                      style: TextStyle(
                                          color: Colors.white
                                      ),
                                      focusNode: _briefNode,
                                      textInputAction: TextInputAction.newline,
                                      minLines: 3,
                                      maxLines: null,
                                    ),
                                  )
                                ],
                              ),
                            ),//brief,

                            Container(
                              margin:EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin:EdgeInsets.only(left: 12),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "I am interested in ... ",
                                          style: TextStyle(
                                              color: Color.fromRGBO(180, 180, 180, 1),
                                              fontFamily: "pacifico",
                                              fontSize: 16
                                          ),
                                        ),
                                        Container(
                                          child: Text(
                                            "(maximum of 5 selections)",
                                            style: TextStyle(
                                              color: Color.fromRGBO(100, 100, 100, 1),
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width:double.infinity,
                                    margin:EdgeInsets.only(top: 12),
                                    padding:EdgeInsets.only(left: 12, right: 12, top: 12),
                                    decoration:BoxDecoration(
                                        color: Color.fromRGBO(32, 32, 32, 1),
                                        border: Border(
                                            bottom: BorderSide(
                                                color: Color.fromRGBO(60, 60, 60, 1)
                                            )
                                        )
                                    ),
                                    child: Wrap(
                                      direction: Axis.horizontal,
                                      children: _interestChildren,
                                      alignment: WrapAlignment.start,
                                    ),
                                  )
                                ],
                              ),
                            ),//interests,
                          ],
                        );
                      }
                      return Container();
                    },
                  ),
                ),

                Positioned(
                  left: 0, top:_screenSize.height * .4,
                  width: _screenSize.width,
                  child: IgnorePointer(
                    ignoring: true,
                    child: StreamBuilder(
                      stream: _localToastCtr.stream,
                      builder: (BuildContext _ctx, AsyncSnapshot _toastshot){
                        if(_showToast){
                          return TweenAnimationBuilder(
                            tween: Tween<double>(begin: 0, end :1),
                            duration: Duration(milliseconds: 700),
                            curve: Curves.easeInOut,
                            builder: (BuildContext _cts, double _twval , _){
                              return Opacity(
                                opacity: _twval,
                                child: Container(
                                  alignment: Alignment.center,
                                  child: Container(
                                    padding: EdgeInsets.only(left: 16, right: 16, top: 9, bottom: 9),
                                    decoration: BoxDecoration(
                                        color: Color.fromRGBO(20, 20, 20, 1),
                                        borderRadius: BorderRadius.circular(9)
                                    ),
                                    child: Text(
                                      _toastText,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: Colors.white
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
                  ),
                )
              ],
            ),
          ),
        ),
      ),
      onWillPop: ()async{
        Navigator.of(_pageContext).pop();
        return false;
      },
    );
  }//route's build method

  bool _showToast=false;
  String _toastText="";
  StreamController _dpchangeNotifier= StreamController.broadcast();
  StreamController _localToastCtr= StreamController.broadcast();
  TextEditingController _usernameCtr= TextEditingController();
  TextEditingController _websiteCtr= TextEditingController();
  FocusNode _websiteNode= FocusNode();
  TextEditingController _briefCtr= TextEditingController();
  FocusNode _briefNode= FocusNode();

  StreamController _interestChangedNotifier= StreamController.broadcast();
  @override
  void dispose() {
    _localDataAvailableNotifier.close();
    _localToastCtr.close();
    _dpchangeNotifier.close();
    _usernameCtr.dispose();
    _websiteCtr.dispose();
    _briefCtr.dispose();
    _interestChangedNotifier.close();
    super.dispose();
  }// route's dispose method

}