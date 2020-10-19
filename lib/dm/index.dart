import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter_sim_country_code/flutter_sim_country_code.dart';

import '../dbs.dart';
import '../globals.dart' as globals;
import 'theme_data.dart' as pageTheme;
import './contacts.dart';

class DM extends StatefulWidget{
  _DM createState(){
    return _DM();
  }
}

class _DM extends State<DM>with SingleTickerProviderStateMixin{

  List<String> _tabListString=["chats", "groups", "status"];
  TabController _tabController;
  @override
  initState(){
    initTabs();
    initProfile();
    super.initState();
  }//route's init state

  DBTables _dbTables= DBTables();
  Directory _appDir;
  initProfile()async{
    _appDir= await getApplicationDocumentsDirectory();
    Directory _dmDir= Directory(_appDir.path + "/dm");
    await _dmDir.create();
    Directory _dpDir= Directory(_dmDir.path + "/dp");
    _dpDir.create();
    Database _con= await _dbTables.dm();
    List _result= await _con.rawQuery("select * from profile limit 1");
    if(_result.length<1){
      tryCreateMyProfile();
    }

    //check to see if any contacts ever existed
    List _contactRes= await _con.rawQuery("select id from contacts limit 1");
    if(_contactRes.length<1){
      var _contactPermStatus= await Permission.contacts.status;
      if(_contactPermStatus.isGranted){
        updateContactsDB();
      }
      else{
        var _contactPermReq=await Permission.contacts.request();
        if(_contactPermReq.isGranted){
          updateContactsDB();
        }
        else{
          showLocalToast(
            text: "Access to your contacts will help to determine which of your contacts currently use the BLW GALAXY App",
            duration: Duration(seconds: 40)
          );
        }
      }
    }
  }//init local data and profile

  String _uCountry="";
  updateContactsDB()async{
    try{
      _uCountry=await FlutterSimCountryCode.simCountryCode;
    }
    catch(ex){}
    Iterable<Contact> _contacts= await ContactsService.getContacts(withThumbnails: false);
    List<Contact> _contactLi= _contacts.toList();
    int _kount= _contactLi.length;
    List _testedNos= [];
    Map _testNosDB={};
    Database _con= await _dbTables.dm();
    for(int _k=0; _k<_kount; _k++){
      if(_contactLi[_k].phones.isNotEmpty){
        String _no= _contactLi[_k].phones.first.value;
        String _strippedNo= _no.replaceAll(RegExp("[^0-9]", caseSensitive: false), "");
        if(_testedNos.indexOf(_strippedNo)<1){
          _testedNos.add(_strippedNo);
          _testNosDB[_strippedNo]={"name": _contactLi[_k].displayName};
        }
      }
    }
    try{
      http.Response _resp=await http.post(
          globals.globBaseDMAPI + "?process_as=test_phone_no",
          body: {
            "phone_no": jsonEncode(_testedNos),
            "country_code": _uCountry
          }
      );
      if(_resp.statusCode == 200){
        List _respObj= jsonDecode(_resp.body);
        int _respCount= _respObj.length;
        for(int _k=0; _k<_respCount; _k++){
          var _targRespObj= _respObj[_k];
          String _targPhone= _targRespObj["phone"];
          String _targDisplayName= "";
          String _rawPhone= _targRespObj["raw_phone"];

          if(_testNosDB.containsKey(_rawPhone)){
            _targDisplayName= _testNosDB[_rawPhone]["name"];
          }
          String _targContactDP= _targRespObj["dp"];
          String _targContactFname="";
          if(_targContactDP.length>1){
            List<String> _brkDP= _targContactDP.split("/");
            _targContactFname= _brkDP.last;
            http.get(_targContactDP).then((_contactGetDPResp) {
              if(_contactGetDPResp.statusCode == 200){
                File _cdpFname= File(_appDir.path + "/dm/dp/$_targContactFname");
                _cdpFname.writeAsBytes(_contactGetDPResp.bodyBytes);
              }
            });
          }
          _con.execute("insert into contacts (user_id, username, display_name, account_fullname, user_phone, dp, file_name, about) values (?, ?, ?, ?, ?, ?, ?, ?)",[
            _targRespObj["user_id"], _targRespObj["username"], _targDisplayName, _targRespObj["fullname"], _targPhone, _targContactDP, _targContactFname, _targRespObj["about"]
          ]);

        }
      }
    }
    catch(ex){

    }
  }//update contact database

  String _localUname="";
  tryCreateMyProfile()async{
    try{
      http.Response _resp= await http.post(
          globals.globBaseDMAPI + "?process_as=try_create_dm_profile",
          body: {
            "user_id": globals.userId
          }
      );
      if(_resp.statusCode == 200){
        Map _respObj= jsonDecode(_resp.body);
        Database _con= await _dbTables.dm();
        List _result=await _con.rawQuery("select * from profile limit 1");
        if(_result.length<1){
          _localUname= _respObj["username"];
          String _dp= _respObj["dp"];
          String _fileName="";
          if(_dp.length>1){
            List<String> _brkDP= _dp.split("/");
            _fileName= _brkDP.last;
            http.get(_dp).then((_locDPGetResp){
              if(_locDPGetResp.statusCode ==200){
                File _saveFName= File(_appDir.path + "/dm/dp/$_fileName");
                _saveFName.exists().then((_fexist) {
                  if(_fexist==false){
                    _saveFName.writeAsBytes(_locDPGetResp.bodyBytes);
                  }
                });
              }
            });
          }
          _con.execute("insert into profile (username, fullname, dp, file_name, about, phone) values (?, ?, ?, ?, ?, ?)", [
            _localUname, _respObj["fullname"], _dp, _fileName, _respObj["about"], _respObj["phone"]
          ]);
        }
      }
    }
    catch(ex){
      showLocalToast(
        text: "Can't create account - Connect your device to the internet",
        duration: Duration(seconds: 7)
      );
    }
  }//try to create my profile

  List<Widget> _tabList= List<Widget>();
  List<Widget> _tabListView= List<Widget>();
  int _currentTab=0;
  StreamController _tabChangedNotifier= StreamController.broadcast();
  initTabs(){
    int _tabCount= _tabListString.length;
    for(int _k=0; _k<_tabCount; _k++){
      _tabList.add(
        StreamBuilder(
          stream: _tabChangedNotifier.stream,
          builder: (BuildContext _ctx, AsyncSnapshot _tabshot){
            return Container(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: (){
                    _tabController.animateTo(
                      _k
                    );
                  },
                  child: Text(
                    _tabListString[_k].toUpperCase(),
                    style: TextStyle(
                      color: _currentTab == _k ? pageTheme.appBarFColorActive : pageTheme.appBarFColor
                    ),
                  ),
                ),
              ),
            );
          },
        )
      );
      _tabListView.add(Container(
        child: StreamBuilder(
          builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
            return Container();
          },
        ),
      ));
    }
    _tabController= TabController(
      length: _tabCount,
      vsync: this
    );
    _tabController.addListener(() {
      _currentTab= _tabController.index;
      if(!_tabChangedNotifier.isClosed) _tabChangedNotifier.add("kjut");
    });
  }//init tabs

  BuildContext _pageContext;
  Size _screenSize;
  String _deviceTheme="";
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize= MediaQuery.of(_pageContext).size;
    _toastTop=_screenSize.height * .6;
    return WillPopScope(
      child: Stack(
        children: [
          Scaffold(
              backgroundColor: pageTheme.bgColor,
              appBar: AppBar(
                backgroundColor: pageTheme.appBarColor,
                title: Text(
                  "DM",
                  style: TextStyle(
                      color: pageTheme.appBarFColor,
                      fontSize: 16
                  ),
                ),
                actions: [
                  Container(
                    margin: EdgeInsets.only(right: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: (){

                        },
                        child: Icon(
                          FlutterIcons.search1_ant,
                          color: pageTheme.appBarFColor,
                        ),
                      ),
                    ),
                  ),//search icon
                  Container(
                    margin: EdgeInsets.only(right: 7),
                    padding: EdgeInsets.only(left: 12, right: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: (){
                          _showMainMenu=true;
                          _mainMenuCtr.add("kjut");
                        },
                        child: Icon(
                          FlutterIcons.dots_vertical_mco,
                          color: pageTheme.appBarFColor,
                        ),
                      ),
                    ),
                  )//ellipsis
                ],
                bottom: TabBar(
                  controller: _tabController,
                  tabs: _tabList,
                  isScrollable: true,
                  labelPadding: EdgeInsets.only(top: 7, bottom: 7, right: 20, left: 20),
                  indicatorColor: pageTheme.appBarFColor,
                  onTap: (int _tabBarIndex){
                    if(_showMainMenu){
                      hideMainMenu();
                    }
                  },
                ),
                elevation: 0,
              ),
              floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
              floatingActionButton: FloatingActionButton(
                onPressed: (){
                  Navigator.of(_pageContext).push(
                    MaterialPageRoute(
                        builder: (BuildContext _ctx){
                          return Contacts();
                        }
                    )
                  );
                },
                child: Icon(
                    FlutterIcons.message_text_mco
                ),
                backgroundColor: pageTheme.fabBGColor,
                foregroundColor: Colors.white,
              ),
              body: Listener(
                onPointerDown: (_){
                  if(_showMainMenu){
                    hideMainMenu();
                  }
                },
                child: FocusScope(
                  child: Container(
                    child: Stack(
                      overflow: Overflow.visible,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: pageTheme.appBarColor,
                          ),
                          padding: EdgeInsets.only(top: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                                borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(16),
                                    topLeft: Radius.circular(16)
                                )
                            ),
                            width: _screenSize.width,
                            height: _screenSize.height,
                            child: TabBarView(
                              controller: _tabController,
                              children: _tabListView,
                              physics: BouncingScrollPhysics(),
                            ),
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
                                                color: Color.fromRGBO(34, 45, 54, 1),
                                                borderRadius: BorderRadius.circular(16)
                                            ),
                                            child: Container(

                                              child: Text(
                                                _twVal < .7 ? "" : _toastText,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    color: Colors.white,
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
                        ),//local toast displayer
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
              )
          ),
          StreamBuilder(
            stream: _mainMenuCtr.stream,
              builder: (BuildContext _ctx, AsyncSnapshot _menuShot){
                if(_showMainMenu){
                  return Positioned(
                    right: 12, top: 60,
                      child: TweenAnimationBuilder(
                        tween: Tween<double>(
                          begin: 0, end: 120
                        ),
                        duration: Duration(
                          milliseconds: 350
                        ),
                        builder: (BuildContext _ctx, double _twVal, _){
                          return Container(
                            width: _twVal > 0 ? (_twVal * (200/120)) : 0, height: _twVal,
                            decoration: BoxDecoration(
                                color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  offset: Offset(1, 1),
                                  color: Color.fromRGBO(150, 150, 150, 1),
                                  blurRadius: 12
                                )
                              ],
                              borderRadius: BorderRadius.circular(7)
                            ),
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                Container(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: (){

                                      },
                                      child: Container(
                                        padding: EdgeInsets.only(left: 18, right: 12, top: 10, bottom: 10),
                                        child: Text(
                                            "Profile",
                                          style: TextStyle(
                                            fontSize: 18
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),//profile
                                Container(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: (){

                                      },
                                      child: Container(
                                        padding: EdgeInsets.only(left: 18, right: 12, top: 10, bottom: 10),
                                        child: Text(
                                          "New Group",
                                          style: TextStyle(
                                              fontSize: 18
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),//new group
                                Container(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: (){

                                      },
                                      child: Container(
                                        padding: EdgeInsets.only(left: 18, right: 12, top: 10, bottom: 10),
                                        child: Text(
                                          "Contacts",
                                          style: TextStyle(
                                              fontSize: 18
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )//contacts
                              ],
                            ),
                          );
                        },
                      )
                  );
                }
                return Container();
              }
          )//global top-right menu
        ],
      ),
      onWillPop: ()async{
        if(_showMainMenu){
          hideMainMenu();
        }
        else Navigator.of(_pageContext).pop();
        return false;
      },
    );
  }//route's build method

  StreamController _mainMenuCtr= StreamController.broadcast();
  bool _showMainMenu=false;
  hideMainMenu(){
    _showMainMenu=false;
    if(!_mainMenuCtr.isClosed){
      _mainMenuCtr.add("kjut");
    }
  }

  @override
  dispose(){
    _tabController.dispose();
    _tabChangedNotifier.close();
    _toastCtr.close();
    _mainMenuCtr.close();
    super.dispose();
  }//route's dispose method

  double _toastLeft=0, _toastTop=0;
  StreamController _toastCtr= StreamController.broadcast();
  bool _showToast=false;
  String _toastText="";
  showLocalToast({String text, Duration duration}){
    _showToast=true;
    _toastText=text;
    if(!_toastCtr.isClosed) _toastCtr.add("kjut");
    Future.delayed(
        duration,
            (){
          _showToast=false;
          if(!_toastCtr.isClosed)_toastCtr.add("kjut");
        }
    );
  }//show local toast
}