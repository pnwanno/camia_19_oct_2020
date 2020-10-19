import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_sim_country_code/flutter_sim_country_code.dart';
import 'package:path_provider/path_provider.dart';

import '../dbs.dart';
import './theme_data.dart' as pageTheme;
import '../globals.dart' as globals;

class Contacts extends StatefulWidget{
  _Contacts createState(){
    return _Contacts();
  }
}

class _Contacts extends State<Contacts>{

  @override
  initState(){
    fetchContacts();
    super.initState();
  }//route's init state

  Directory _appDir;

  List _contacts=List();
  DBTables _dbTables= DBTables();
  bool _contactsLoaded=false;
  fetchContacts()async{
    _appDir= await getApplicationDocumentsDirectory();
    Database _con= await _dbTables.dm();
    _contactsLoaded=true;
    if(!_pageDataAvailNotifier.isClosed){
      _pageDataAvailNotifier.add("kjut");
    }
  }//fetch contacts

  BuildContext _pageContext;
  String _deviceTheme="";
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext= context;
    _screenSize=MediaQuery.of(context).size;
    _toastTop=_screenSize.height * .6;
    return WillPopScope(
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: pageTheme.bgColor,
            appBar: AppBar(
              backgroundColor: pageTheme.appBarColor,
              elevation: 0,
              title: Text(
                "Contacts",
                style: TextStyle(
                  color: pageTheme.appBarFColor
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
                      child: Container(
                        child: Icon(
                          FlutterIcons.search1_ant,
                          color: pageTheme.appBarFColor,
                          size: 20,
                        )
                      )
                    ),
                  ),
                ),//search Icon
                Container(
                  margin: EdgeInsets.only(right: 16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                        onTap: (){
                          refreshContacts();
                        },
                        child: Container(
                            child: Icon(
                              FlutterIcons.refresh_mco,
                              color: pageTheme.appBarFColor,
                            )
                        )
                    ),
                  ),
                )//refresh Icon
              ],
            ),

            body: Listener(
              child: FocusScope(
                child: Container(
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: pageTheme.appBarColor
                        ),
                        padding: EdgeInsets.only(top: 7),
                        child: Container(
                          width: _screenSize.width, height: _screenSize.height,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: pageTheme.bgColor
                          ),
                          child: StreamBuilder(
                            stream: _pageDataAvailNotifier.stream,
                            builder: (BuildContext _ctx, AsyncSnapshot _pageShot){
                              if(_contactsLoaded){
                                if(_contacts.length == 0 ){
                                  return Container(
                                    alignment: Alignment.center,
                                    width: _screenSize.width,
                                    height: _screenSize.height,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          child: Icon(
                                            FlutterIcons.contacts_ant,
                                            color: pageTheme.fontGrey,
                                            size: 32,
                                          ),
                                        ),
                                        Container(
                                          padding:EdgeInsets.only(left: 16, right: 16, top: 5, bottom: 5),
                                          child: Text(
                                            "None of your contacts currently use the BLW GALAXY App",
                                            textAlign:TextAlign.center,
                                            style: TextStyle(
                                              color: pageTheme.fontGrey,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.only(left: 16, right: 16),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: (){
                                                refreshContacts();
                                              },
                                              child: Wrap(
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                children: [
                                                  Container(
                                                    child: Icon(
                                                      FlutterIcons.refresh_mco,
                                                      color: pageTheme.fontGrey,
                                                    ),
                                                  ),
                                                  Container(
                                                    margin:EdgeInsets.only(left: 5),
                                                    child: Text(
                                                      "Tap to refresh this page",
                                                      style: TextStyle(
                                                        color: pageTheme.fontGrey
                                                      ),
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  );
                                }
                              }
                              return Container(
                                alignment: Alignment.center,
                                width: _screenSize.width,
                                height: _screenSize.height,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(pageTheme.fontColor),
                                ),
                              );
                            },
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
        ],
      ),
      onWillPop: ()async{
        Navigator.of(_pageContext).pop();
        return false;
      },
    );
  }//route's build method

  String _uCountry="";
  refreshContacts()async{
    _contactsLoaded=false;
    _pageDataAvailNotifier.add("kjut");
    var _locContacts=await ContactsService.getContacts(withThumbnails: false);
    List<Contact> _locContactLi= _locContacts.toList();
    int _kount= _locContactLi.length;
    List<String> _testedNos= List();
    Map _contactMap={};
    for(int _k=0; _k<_kount; _k++){
      Contact _targContact=_locContactLi[_k];
      if(_targContact.phones.isNotEmpty){
        String _targPhone= _targContact.phones.first.value;
        String _strippedPhone= _targPhone.replaceAll(RegExp("[^0-9]"), "");
        if(_testedNos.indexOf(_strippedPhone)<0){
          _testedNos.add(_strippedPhone);
          _contactMap[_strippedPhone]= _targContact.displayName;
        }
      }
    }
    try{
      _uCountry= await FlutterSimCountryCode.simCountryCode;
      http.Response _resp= await http.post(
        globals.globBaseDMAPI + "?process_as=test_phone_no",
        body: {
          "phone_no": jsonEncode(_testedNos),
          "country_code": _uCountry
        }
      );
      if(_resp.statusCode == 200){
        //fetch all existing contacts
        List<String> _existingPhones=[];
        Database _con= await _dbTables.dm();
        List _phoneQResult= await _con.rawQuery("select user_phone from contacts");
        int _phoneQResCount= _phoneQResult.length;
        for(int _k=0; _k<_phoneQResCount; _k++){
          _existingPhones.add(_phoneQResult[_k]["user_phone"]);
        }

        //_con.execute("insert into contacts (user_id, username, display_name, account_fullname, user_phone, dp, file_name, about) values (?, ?, ?, ?, ?, ?, ?, ?)",[
        //  _targRespObj["user_id"], _targRespObj["username"], _targDisplayName, _targRespObj["fullname"], _targPhone, _targContactDP, _targContactFname, _targRespObj["about"]
        //]);

        List _respObj= jsonDecode(_resp.body);
        int _respKount= _respObj.length;
        for(int _k=0; _k<_respKount; _k++){
          String _targPhone= _respObj[_k]["phone"];
          String _targDP= _respObj[_k]["dp"];
          String _targContactFileName="";
          if(_targDP.length>1){
            List<String> _brkDP= _targDP.split("/");
            _targContactFileName= _brkDP.last;
            File _dpfname= File(_appDir.path + "/dm/dp/$_targContactFileName");
          }
          if(_existingPhones.indexOf(_targPhone)>-1){

          }
          else{

          }
        }
      }
    }
    catch(ex){
      showLocalToast(
        text: "Can't refresh in offline mode",
        duration: Duration(seconds: 3)
      );
    }
  }//refresh Contacts

  StreamController _pageDataAvailNotifier= StreamController.broadcast();
  @override
  void dispose() {
    _toastCtr.close();
    _pageDataAvailNotifier.close();
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