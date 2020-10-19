import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../globals.dart' as globals;
import 'theme_data.dart' as pageTheme;
import '../dbs.dart';

class ChapterDetails extends StatefulWidget{
  final String searchQuery;
  _ChapterDetails createState(){
    return _ChapterDetails();
  }
  ChapterDetails(this.searchQuery);
}

class _ChapterDetails extends State<ChapterDetails>{

  DBTables _dbTables=DBTables();

  @override
  initState(){
    fetchChapterDetails();
    super.initState();
  }

  Map _pageData;
  fetchChapterDetails()async{
    if(_pageData!=null) return _pageData;
    try{
      http.Response _resp= await http.post(
        globals.globBaseCHFinder + "?process_as=find_chapter",
        body: {
          "search_q": widget.searchQuery
        }
      );
      if(_resp.statusCode == 200){
        Map _respObj= jsonDecode(_resp.body);
        if(_respObj.containsKey("chapter")){
          _pageData=_respObj;
          _pageDataAvailNotifier.add("kjut");

          String _targCHID=_pageData["id"];
          Database _con= await _dbTables.chFinder();
          List _testRes= await _con.rawQuery("select id from chapter_details where chapter_id=?", [_targCHID]);
          if(_testRes.length<1){
            _con.execute("insert into chapter_details (chapter_id, zone, chapter, location, address, contact_person, phone, email, social) values (?, ?, ?, ?, ?, ?, ?, ?, ?)",[
              _targCHID, _pageData["zone"], _pageData["chapter"], _pageData["location"], _pageData["address"], _pageData["person"], _pageData["phone"], _pageData["email"], _pageData["social_media"]
            ]);
            String _kita= DateTime.now().millisecondsSinceEpoch.toString();
            _con.execute("insert into search_history (search_q, time_str) values (?, ?)", [widget.searchQuery, _kita]);
          }
        }
      }
    }
    catch(ex){
      Database _con= await _dbTables.chFinder();
      List _result= await _con.rawQuery("select * from chapter_details where chapter=? or zone=? or location=?", [
        widget.searchQuery, widget.searchQuery, widget.searchQuery
      ]);
      if(_result.length == 1){
        _pageData={
          "zone": _result[0]["zone"],
          "chapter": _result[0]["chapter"],
          "location": _result[0]["location"],
          "address": _result[0]["address"],
          "email": _result[0]["email"],
          "phone": _result[0]["phone"],
          "person": _result[0]["contact_person"],
          "social_media": _result[0]["social"]
        };
      }
    }
  }

  String _deviceTheme="";
  BuildContext _pageContext;
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize=MediaQuery.of(_pageContext).size;
    return WillPopScope(
      child: Scaffold(
        backgroundColor: pageTheme.bgColor,
        appBar: AppBar(
          title: Text(
            "Chapter details",
            style: TextStyle(
              color: Colors.white
            ),
          ),
          iconTheme: IconThemeData(
            color: Colors.white
          ),
          elevation: 0,
          backgroundColor: pageTheme.activeIcon,
        ),
        body: FocusScope(
          child: Container(
            child: Stack(
              children: [
                Container(
                  width: _screenSize.width,
                  height: _screenSize.height,
                  child: StreamBuilder(
                    stream: _pageDataAvailNotifier.stream,
                    builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                      if(_pageData!=null){
                        String _targPhone= _pageData["phone"];
                        //String _targPerson= _pageData["person"];
                        String _targEmail= _pageData["email"];
                        String _targSocial= _pageData["social_media"];
                        String _targAddress= _pageData["address"];
                        return ListView(
                          physics: BouncingScrollPhysics(),
                          children: [
                            Container(
                              width: _screenSize.width,
                              decoration: BoxDecoration(
                                color: pageTheme.activeIcon
                              ),
                              padding: EdgeInsets.only(bottom: 9, top: 9, left: 16, right: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin:EdgeInsets.only(bottom: 3),
                                    child: Text(
                                      "Zone",
                                      style: TextStyle(
                                        color: Color.fromRGBO(245, 245, 245, 1)
                                      ),
                                    ),
                                  ),
                                  Container(
                                    child: Text(
                                      _pageData["zone"].toString().toUpperCase(),
                                      style: TextStyle(
                                          color: Colors.white,
                                        fontFamily: "ubuntu",
                                        fontSize: 18
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),//zone
                            Container(
                              width: _screenSize.width,
                              decoration: BoxDecoration(
                                  color: pageTheme.activeIcon
                              ),
                              padding: EdgeInsets.only(bottom: 9, top: 9, left: 16, right: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin:EdgeInsets.only(bottom: 5),
                                    child: Text(
                                      "Chapter",
                                      style: TextStyle(
                                          color: Color.fromRGBO(245, 245, 245, 1)
                                      ),
                                    ),
                                  ),
                                  Container(
                                    child: Text(
                                      _pageData["chapter"].toString().toUpperCase(),
                                      style: TextStyle(
                                          color: Colors.white,
                                        fontFamily: "ubuntu",
                                        fontSize: 18
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),//chapter
                            Container(
                              width: _screenSize.width,
                              decoration: BoxDecoration(
                                  color: pageTheme.activeIcon
                              ),
                              padding: EdgeInsets.only(bottom: 48, top: 9, left: 16, right: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin:EdgeInsets.only(bottom: 5),
                                    child: Text(
                                      "Location",
                                      style: TextStyle(
                                          color: Color.fromRGBO(245, 245, 245, 1)
                                      ),
                                    ),
                                  ),
                                  Container(
                                    child: Text(
                                      globals.kChangeCase(_pageData["location"], globals.KWordcase.sentence_case),
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontFamily: "ubuntu",
                                          fontSize: 16
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),//Location
                            Container(
                              padding:EdgeInsets.only(left: 16, right: 16),
                              margin:EdgeInsets.only(bottom: 9),
                              child: Container(
                                transform: Matrix4.translationValues(0, -32, 0),
                                padding: EdgeInsets.only(top: 3, bottom: 3),
                                decoration:BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      offset: Offset(0, 1),
                                      color: pageTheme.blurColor,
                                      blurRadius: 2
                                    )
                                  ],
                                  borderRadius: BorderRadius.circular(7),
                                  color: pageTheme.bgColor
                                ),
                                child: Material(
                                  color:Colors.transparent,
                                  child: ListTile(
                                    leading: Container(
                                      child: Icon(
                                        FlutterIcons.phone_faw,
                                        color: pageTheme.activeIcon,
                                      ),
                                    ),
                                    title: Container(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            margin:EdgeInsets.only(bottom: 5),
                                            child: Text(
                                              _targPhone == "" ? "(___) - (___) - (____)" : _targPhone,
                                              style: TextStyle(
                                                color: pageTheme.fontGrey,
                                                fontSize: 16,
                                                fontFamily: "ubuntu"
                                              ),
                                            ),
                                          ),
                                          Container(
                                            child: Text(
                                              "Phone",
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: pageTheme.fontColor2
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                    onTap: (){
                                      if(_targPhone!="")
                                      globals.followLink(_targPhone);
                                    },
                                  ),
                                ),
                              ),
                            ), //phone
                            Container(
                              padding:EdgeInsets.only(left: 16, right: 16),
                              margin:EdgeInsets.only(bottom: 9),
                              child: Container(
                                transform: Matrix4.translationValues(0, -32, 0),
                                padding: EdgeInsets.only(top: 3, bottom: 3),
                                decoration:BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                          offset: Offset(0, 1),
                                          color: pageTheme.blurColor,
                                          blurRadius: 2
                                      )
                                    ],
                                    borderRadius: BorderRadius.circular(7),
                                    color: pageTheme.bgColor
                                ),
                                child: Material(
                                  color:Colors.transparent,
                                  child: ListTile(
                                    leading: Container(
                                      child: Icon(
                                        FlutterIcons.ios_mail_ion,
                                        color: pageTheme.activeIcon,
                                      ),
                                    ),
                                    title: Container(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            margin:EdgeInsets.only(bottom: 5),
                                            child: Text(
                                              _targEmail == "" ? "-@.com" : _targEmail,
                                              style: TextStyle(
                                                  color: pageTheme.fontGrey,
                                                  fontSize: 16,
                                                  fontFamily: "ubuntu"
                                              ),
                                            ),
                                          ),
                                          Container(
                                            child: Text(
                                              "Email address",
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: pageTheme.fontColor2
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                    onTap: (){
                                      if(_targEmail!=""){
                                        globals.followLink(_targEmail);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ), //email
                            Container(
                              padding:EdgeInsets.only(left: 16, right: 16),
                              margin:EdgeInsets.only(bottom: 9),
                              child: Container(
                                transform: Matrix4.translationValues(0, -32, 0),
                                padding: EdgeInsets.only(top: 3, bottom: 3),
                                decoration:BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                          offset: Offset(0, 1),
                                          color: pageTheme.blurColor,
                                          blurRadius: 2
                                      )
                                    ],
                                    borderRadius: BorderRadius.circular(7),
                                    color: pageTheme.bgColor
                                ),
                                child: Material(
                                  color:Colors.transparent,
                                  child: ListTile(
                                    leading: Container(
                                      child: Icon(
                                        FlutterIcons.ios_chatbubbles_ion,
                                        color: pageTheme.activeIcon,
                                      ),
                                    ),
                                    title: Container(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            margin:EdgeInsets.only(bottom: 5),
                                            child: Text(
                                              _targSocial == "" ? "www.com" : _targSocial,
                                              style: TextStyle(
                                                  color: pageTheme.fontGrey,
                                                  fontSize: 16,
                                                  fontFamily: "ubuntu"
                                              ),
                                            ),
                                          ),
                                          Container(
                                            child: Text(
                                              "Social link",
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: pageTheme.fontColor2
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                    onTap: (){
                                      if(_targSocial!=""){
                                        globals.followLink(_targSocial);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ), //social
                            Container(
                              padding:EdgeInsets.only(left: 16, right: 16),
                              margin:EdgeInsets.only(bottom: 9),
                              child: Container(
                                transform: Matrix4.translationValues(0, -32, 0),
                                padding: EdgeInsets.only(top: 3, bottom: 3),
                                decoration:BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                          offset: Offset(0, 1),
                                          color: pageTheme.blurColor,
                                          blurRadius: 2
                                      )
                                    ],
                                    borderRadius: BorderRadius.circular(7),
                                    color: pageTheme.bgColor
                                ),
                                child: Material(
                                  color:Colors.transparent,
                                  child: ListTile(
                                    leading: Container(
                                      child: Icon(
                                        FlutterIcons.map_marked_alt_faw5s,
                                        color: pageTheme.activeIcon,
                                      ),
                                    ),
                                    title: Container(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            margin:EdgeInsets.only(bottom: 5),
                                            child: Text(
                                              _targAddress == "" ? "###" : _targAddress,
                                              style: TextStyle(
                                                  color: pageTheme.fontGrey,
                                                  fontSize: 16,
                                                  fontFamily: "ubuntu"
                                              ),
                                            ),
                                          ),
                                          Container(
                                            child: Text(
                                              "Contact address",
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: pageTheme.fontColor2
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ), //address
                          ],
                        );
                      }
                      return Container(
                        width: _screenSize.width,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: pageTheme.activeIcon
                        ),
                        child: Container(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(pageTheme.bgColor),
                          ),
                        ),
                      );
                    },
                  ),
                )
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
        Navigator.of(context).pop();
        return false;
      },
    );
  }//route's build method

  StreamController _pageDataAvailNotifier= StreamController.broadcast();
  @override
  void dispose() {
    _pageDataAvailNotifier.close();
    super.dispose();
  }
}