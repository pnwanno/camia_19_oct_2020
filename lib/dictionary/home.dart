import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;

import '../dbs.dart';
import '../globals.dart' as globals;
import './search.dart';
import './search_result.dart';
import './index.dart';
import './affirmation_details.dart';

class DictHome extends StatefulWidget{
  _DictHome createState(){
    return _DictHome();
  }
}

class _DictHome extends State<DictHome>{
  @override
  initState(){
    super.initState();
    _homeLiCtr.addListener(() {
    });
    fetchWordofDay();
    fetchQOW();
    fetchTodayAffirmation();
  }

  DBTables _dbTables= DBTables();
  StreamController _globqowCtr= StreamController.broadcast();
  StreamController _globaffirmCtr= StreamController.broadcast();
  StreamController _globwodCtr= StreamController.broadcast();
  bool _fetchedwod=false;
  fetchWordofDay()async{
    try{
      DateTime _kita=DateTime.now();
      String _tdy= _kita.day.toString().padLeft(2, "0") + "-" + _kita.month.toString().padLeft(2, "0") + "-" + _kita.year.toString();
      Database _con= await _dbTables.lwDict();
      _con.rawQuery("select * from day_word where day='$_tdy'").then((_result){
        if(_result.length == 1){
          String _wrd= _result[0]["title"];
          String _def= _result[0]["definition"];
          _globwodCtr.add({
            "word": _wrd,
            "definition": _def
          });
        }
        else{
          http.post(
              globals.globBaseUrl2 + "?process_as=get_dict_word_of_the_day"
          ).then((_resp){
            try{
              if(_resp.statusCode == 200){
                var _respObj= jsonDecode(_resp.body);
                String _wordId= _respObj["word_id"];
                _con.rawQuery("select * from dict_words where word_id='$_wordId'").then((_result2) {
                  if(_result2.length==1){
                    String _loctitle= _result2[0]["title"];
                    String _locdef= _result2[0]["definition"];
                    String _locsrc= _result2[0]["source_txt"];
                    String _locwid=_result2[0]["word_id"];
                    _con.execute("insert into day_word (title, definition, source_txt, word_id, day) values (?, ?, ?, ?, ?)", [_loctitle, _locdef, _locsrc, _locwid, _tdy]);
                    _globwodCtr.add({
                      "word": _loctitle,
                      "definition": _locdef
                    });
                  }
                  else localWOD();
                });
              }
            }
            catch(ex){
              localWOD();
            }
          });
        }
      });
    }
    catch(ex){
      localWOD();
    }
  }//word of day

  localWOD()async{
    Database _con= await _dbTables.lwDict();
    var _result= await _con.rawQuery("select * from dict_words order by random() limit 1");
    if(_result.length == 1){
      _fetchedwod=true;
      String _wrd= _result[0]["title"];
      String _def= _result[0]["definition"];
      _globwodCtr.add({
        "word": _wrd,
        "definition": _def
      });
    }
    else{
      if(!_fetchedwod){
        Future.delayed(
            Duration(seconds: 7),
                (){
              fetchWordofDay();
            }
        );
      }
    }
  }

  getWeekOfYear(){
    DateTime _kita=DateTime.now();
    int d=DateTime.parse("${_kita.year}-01-01").millisecondsSinceEpoch;
    int t= _kita.millisecondsSinceEpoch;
    double daydiff= (t- d)/(1000 * (3600 * 24));
    double week= daydiff/7;
    return (week.ceil());
  }//get week of the year

  fetchQOW()async{
    try{
      Database _con= await _dbTables.lwDict();
      int woy= getWeekOfYear();
      _con.rawQuery("select * from weekly_quotes where week='$woy'").then((_result){
        if(_result.length == 1){
          _globqowCtr.add({
            "by": _result[0]["quote_by"],
            "quote": _result[0]["quote"]
          });
        }
        else{
          try{
            http.post(
                globals.globBaseUrl2 + "?process_as=get_quote_of_the_week"
            ).then((http.Response _resp) {
              if(_resp.statusCode == 200 && _resp.body!=""){
                try{
                  var _respObj= jsonDecode(_resp.body);
                  String _quoteBy=_respObj["by"];
                  String _quote=_respObj["quote"];
                  String _quoteWeek=_respObj["week"];

                  _globqowCtr.add({
                    "by": _quoteBy,
                    "quote": _quote
                  });
                  _con.execute("insert into weekly_quotes (quote_by, quote, week) values (?, ?, ?)", [_quoteBy, _quote, _quoteWeek]);
                }
                catch(ex){

                }
              }
            });
          }
          catch(ex){

          }
        }
      });
    }
    catch(ex){
      
    }
  }//fetch quote of the week from the server

  String getdmyFromTimeStr(int _milliStr){
    DateTime dt= DateTime.fromMillisecondsSinceEpoch(_milliStr);
    return dt.day.toString().padLeft(2, "0") + "-" + dt.month.toString().padLeft(2, "0") + "-" + dt.year.toString();
  }

  fetchTodayAffirmation()async{
    try{
      Database _con= await _dbTables.lwDict();
      DateTime _kita=DateTime.now();
      String _tdy= getdmyFromTimeStr(_kita.millisecondsSinceEpoch);

      _con.rawQuery("select * from affirmations where day='$_tdy'").then((_result){
        if(_result.length == 1){
          _globaffirmCtr.add({
            "affirmation": _result[0]["text"],
            "id": "${_result[0]["id"]}"
          });
        }
        else{
          try{
            http.post(
                globals.globBaseUrl2 + "?process_as=get_affirmation_of_day"
            ).then((http.Response _resp) {
              if(_resp.statusCode == 200 && _resp.body!=""){
                try{
                  var _respObj= jsonDecode(_resp.body);
                  String _affirm=_respObj["affirm"];
                  String _day=_respObj["day"];
                  _con.execute("insert into affirmations (text, day) values (?, ?)", [_affirm, _day]).then((value) {
                    _con.rawQuery("select * from affirmations order by id desc limit 1").then((_res) {
                      _globaffirmCtr.add({
                        "affirmation": _affirm,
                        "id": "${_res[0]["id"]}"
                      });
                    });
                  });
                }
                catch(ex){

                }
              }
            });
          }
          catch(ex){

          }
        }
      });
    }
    catch(ex){

    }
  }//fetch today affirmation

  Future<Widget> fetchTopSearches()async{
    try{
      http.Response _resp= await http.post(
        globals.globBaseUrl2 + "?process_as=trending_dictionary_word"
      );
      if(_resp.statusCode == 200 && _resp.body!=""){
        var _respObj= jsonDecode(_resp.body);
        int _count= _respObj.length;
        List<Widget> _colChildren= List<Widget>();
        for(int _k=0; _k<_count; _k++){
          _colChildren.add(
            GestureDetector(
              onTap: (){
                Navigator.push(
                  _homeContext,
                  CupertinoPageRoute(
                    builder: (BuildContext _ctx){
                      return DictSearchResult(_respObj[_k]["word"], calledFrom: "home",);
                    }
                  )
                );
              },
              child: Container(
                margin: EdgeInsets.only(bottom: 7),
                child: Wrap(
                  children: <Widget>[
                    Container(
                      child: Container(
                        child: Text(
                            _respObj[_k]["word"]
                        ),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(left: 7),
                      child: Text(
                        convertToK(int.tryParse(_respObj[_k]["count"])) + " searches",
                        style: TextStyle(
                            fontFamily: "ubuntu",
                          color: Colors.blueGrey
                        ),
                      ),
                    )
                  ],
                ),
              ),
            )
          );
        }
        return Container(
          padding: EdgeInsets.only(left: 16, right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                margin: EdgeInsets.only(bottom: 12),
                child: Text(
                  "Top Searches",
                  style: TextStyle(
                    fontFamily: "Ubuntu",
                    color: Colors.deepOrange
                  ),
                ),
              ),//top searches label

              Container(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _colChildren,
                ),
              )
            ],
          ),
        );
      }
      return Container();
    }
    catch(ex){
      return Container();
    }
  }

  double _globpostop=0;
  BuildContext _homeContext;
  Size _homeSize;
@override
  Widget build(BuildContext context) {
  _homeContext=context;
  _homeSize= MediaQuery.of(_homeContext).size;
    return Scaffold(
      body: FocusScope(
        autofocus: true,
        child: Container(
          decoration: BoxDecoration(
            color: Color.fromRGBO(245, 245, 245, 1)
          ),
          child: Stack(
            children: <Widget>[
              Container(
                padding: EdgeInsets.only(bottom: 16),
                child: ListView(
                  controller: _homeLiCtr,
                  children: <Widget>[
                    Container(
                      height: 100, width: _homeSize.width,
                    ),
                    StreamBuilder(
                      stream: _globwodCtr.stream,
                      builder: (BuildContext _wodCtx, AsyncSnapshot _wodShot){
                        return GestureDetector(
                          onTap: (){
                            Navigator.push(_homeContext, CupertinoPageRoute(
                              builder: (BuildContext _ctx){
                                return LWDictionary(switchPage: "wod",);
                              }
                            ));
                          },
                          child: Container(
                            decoration: BoxDecoration(
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                      color: Color.fromRGBO(200, 200, 200, 1),
                                      offset: Offset(0,1)
                                  )
                                ]
                            ),
                            padding: EdgeInsets.only(top: 16, bottom: 16, left: 20, right: 20),
                            margin: EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  child: Text(
                                    "Word of the day",
                                    style: TextStyle(
                                        color: Colors.blueGrey,
                                        fontFamily: "pacifico",
                                        fontSize: 20
                                    ),
                                  ),
                                ),
                                _wodShot.hasData ?
                                Container(
                                  padding: EdgeInsets.only(top: 12, bottom: 12),
                                  decoration: BoxDecoration(

                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Container(
                                        padding: EdgeInsets.only(bottom: 5),
                                        margin: EdgeInsets.only(bottom: 12),
                                        width: _homeSize.width,
                                        decoration: BoxDecoration(
                                            border: Border(
                                                bottom: BorderSide(
                                                    color: Colors.grey
                                                )
                                            )
                                        ),
                                        child: Text(
                                          globals.kChangeCase(_wodShot.data["word"], globals.KWordcase.proper_case),
                                          style: TextStyle(
                                              fontFamily: "ubuntu",
                                              fontSize: 18
                                          ),
                                        ),
                                      ),

                                      Container(
                                        child: Text(
                                          globals.kChangeCase(_wodShot.data["definition"], globals.KWordcase.sentence_case),
                                          style: TextStyle(
                                              fontSize: 16
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                ):
                                Container()
                              ],
                            ),
                          ),
                        );
                      },
                    ), //word of the day

                    StreamBuilder(
                      stream: _globqowCtr.stream,
                      builder: (BuildContext _wodCtx, AsyncSnapshot _quoteShot){
                        return GestureDetector(
                          onTap: (){
                            Navigator.of(_homeContext).push(MaterialPageRoute(
                              builder: (BuildContext _ctx){
                                return LWDictionary(switchPage: "weeklyquotes",);
                              }
                            ));
                          },
                          child: Container(
                            decoration: BoxDecoration(
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                      color: Color.fromRGBO(200, 200, 200, 1),
                                      offset: Offset(0,1)
                                  )
                                ]
                            ),
                            padding: EdgeInsets.only(top: 16, bottom: 16, left: 20, right: 20),
                            margin: EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  child: Text(
                                    "Quote of the week",
                                    style: TextStyle(
                                        color: Colors.blueGrey,
                                        fontFamily: "pacifico",
                                        fontSize: 20
                                    ),
                                  ),
                                ),
                                _quoteShot.hasData ?
                                Container(
                                  padding: EdgeInsets.only(top: 12, bottom: 12),
                                  decoration: BoxDecoration(
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Container(
                                        padding: EdgeInsets.only(bottom: 5),
                                        margin: EdgeInsets.only(bottom: 12),
                                        width: _homeSize.width,
                                        decoration: BoxDecoration(
                                            border: Border(
                                                bottom: BorderSide(
                                                    color: Colors.grey
                                                )
                                            )
                                        ),
                                        child: Text(
                                          globals.kChangeCase(_quoteShot.data["by"], globals.KWordcase.proper_case),
                                          style: TextStyle(
                                              fontFamily: "ubuntu",
                                              fontSize: 18
                                          ),
                                        ),
                                      ),

                                      Container(
                                        child: Text(
                                          globals.kChangeCase(_quoteShot.data["quote"], globals.KWordcase.sentence_case),
                                          style: TextStyle(
                                              fontSize: 16
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                ):
                                Container()
                              ],
                            ),
                          ),
                        );
                      },
                    ), //quote of the week

                    StreamBuilder(
                      stream: _globaffirmCtr.stream,
                      builder: (BuildContext _affCtx, AsyncSnapshot _affShot){
                        return GestureDetector(
                          onTap: (){
                            Navigator.of(_homeContext).push(MaterialPageRoute(
                              builder: (BuildContext _ctx){
                                return LWDictionary(switchPage: "affirmation",);
                              }
                            ));
                          },
                          child: Container(
                            decoration: BoxDecoration(
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                      color: Color.fromRGBO(200, 200, 200, 1),
                                      offset: Offset(0,1)
                                  )
                                ]
                            ),
                            padding: EdgeInsets.only(top: 16, bottom: 16, left: 20, right: 20),
                            margin: EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  child: Text(
                                    "Today's Affirmation",
                                    style: TextStyle(
                                        color: Colors.blueGrey,
                                        fontFamily: "pacifico",
                                        fontSize: 20
                                    ),
                                  ),
                                ),
                                _affShot.hasData ?
                                Container(
                                  padding: EdgeInsets.only(top: 12, bottom: 12),
                                  decoration: BoxDecoration(
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Container(
                                        padding: EdgeInsets.only(bottom: 5),
                                        margin: EdgeInsets.only(bottom: 12),
                                        width: _homeSize.width,
                                        decoration: BoxDecoration(
                                            border: Border(
                                                bottom: BorderSide(
                                                    color: Colors.grey
                                                )
                                            )
                                        ),
                                        child: Text(
                                          globals.kChangeCase(_affShot.data["affirmation"], globals.KWordcase.proper_case),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 16
                                          ),
                                        ),
                                      ),

                                      Container(
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkResponse(
                                              onTap: (){
                                                Navigator.push(_homeContext, MaterialPageRoute(
                                                  builder: (BuildContext _ctx){
                                                    return AffirmationDetails(_affShot.data["id"]);
                                                  }
                                                ));
                                              },
                                                child: Text(
                                                  "Read more ...",
                                                  style: TextStyle(
                                                      fontSize: 16
                                                  ),
                                                )
                                            ),
                                          )
                                      )
                                    ],
                                  ),
                                ):
                                Container()
                              ],
                            ),
                          ),
                        );
                      },
                    ), //daily affirmation

                    Container(
                      margin: EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 12),
                      child: GestureDetector(
                        onTap: (){
                          Navigator.of(_homeContext).push(
                              MaterialPageRoute(
                                  builder: (BuildContext _ctx){
                                    return LWDictionary(switchPage: "dictionary",);
                                  }
                              )
                          );
                        },
                        child: Container(
                          width: _homeSize.width,
                          padding: EdgeInsets.only(top: 9, bottom: 9),
                          decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12)
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Container(
                                margin: EdgeInsets.only(right: 12),
                                child: Text(
                                  "Dictionary",
                                  style: TextStyle(
                                      fontFamily: "ubuntu",
                                      color: Colors.white
                                  ),
                                ),
                              ),
                              Container(
                                child: Icon(
                                  FlutterIcons.open_book_ent,
                                  color: Colors.white,
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),

                    FutureBuilder(
                      future: fetchTopSearches(),
                      builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                        if(_snapshot.hasData){
                          return _snapshot.data;
                        }
                        else{
                          return Container();
                        }
                      },
                    ),

                  ],
                ),
              ),
              Positioned(
                left: 0, top: _globpostop,
                width: _homeSize.width,
                child: Container(
                  width: _homeSize.width,
                  padding: EdgeInsets.only(left:18, right: 18, top: 18, bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                  ),
                  child: Column(
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.only(left: 12, right: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5)
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              child: Icon(
                                FlutterIcons.search1_ant
                              ),
                              margin: EdgeInsets.only(right: 12),
                            ),
                            Expanded(
                              child: Container(
                                child: TextField(
                                  readOnly: true,
                                    decoration: InputDecoration(
                                        hintStyle: TextStyle(
                                            color: Colors.grey
                                        ),
                                        hintText: "Search dictionary ...",
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none
                                    ),
                                  onTap: (){
                                    Navigator.of(_homeContext).push(
                                      CupertinoPageRoute(
                                        builder: (BuildContext _searchCtx){
                                          return DictSearch();
                                        }
                                      )
                                    );
                                  },
                                ),
                              ),
                            )
                          ],
                        )
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
        onFocusChange: (bool _isFocused){

        },
      ),
    );
  }//route's build method

  ScrollController _homeLiCtr= ScrollController();
  @override
  void dispose() {
    super.dispose();
    _homeLiCtr.dispose();
    _globwodCtr.close();
    _globqowCtr.close();
    _globaffirmCtr.close();
  }

  convertToK(int val){
    List<String> units=["K", "M", "B"];
    double remain = val/1000;
    int counter=-1;
    if(remain>1) counter++;
    while(remain>999){
      counter++;
      remain /=1000;
    }
    if(counter>-1) return remain.toStringAsFixed(1) + units[counter];
    return "$val";
  }//convert to k m or b
}