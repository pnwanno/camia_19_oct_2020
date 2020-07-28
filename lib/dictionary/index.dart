import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;

import './home.dart';
import '../globals.dart' as globals;
import '../dbs.dart';

enum KDictCurrentPage{
  home,
  word_of_the_day,
  affirmation_of_the_day,
  quote_of_the_week,
  history
}
class LWDictionary extends StatefulWidget{
  _LWDictionary createState(){
    return _LWDictionary();
  }
}

class _LWDictionary extends State<LWDictionary>{


  initState(){
    super.initState();
    initDatabase();
  }

  DBTables _dbTables= DBTables();
  initDatabase()async{
    try{
      List<String> _wordIds= List<String>();
      Database _con= await _dbTables.lwDict();
      var _result= await _con.rawQuery("select word_id from dict_words");
      int _rescount= _result.length;
      for(int _k=0; _k<_rescount; _k++){
        _wordIds.add(_result[_k]["word_id"]);
      }

      //fetch sever content;
      http.post(
        globals.globBaseUrl2 + "?process_as=fetch_dict_words",
        body: {
          "user_id": globals.userId
        }
      ).then((http.Response _resp) {
        if(_resp.statusCode == 200){
          var _respObj= jsonDecode(_resp.body);
          int _respLen= _respObj.length;
          for(int _k=0; _k<_respLen; _k++){
            String _targId= _respObj[_k]["id"];
            if(_wordIds.indexOf(_targId)<0){
              String _dtitle= _respObj[_k]["title"];
              String _ddef= _respObj[_k]["definition"];
              String _dsrc= _respObj[_k]["source"];
              String _bookmarked="no";
              String _dwordid= _respObj[_k]["id"];
              _con.execute("insert into dict_words (title, definition, source_txt, bookmarked, word_id) values (?, ?, ?, ?, ?)", [_dtitle, _ddef, _dsrc, _bookmarked, _dwordid]);
              if(_wordIds.length>1){
                //alert new word
              }
            }
          }
        }
      });
    }
    catch(ex){

    }
  }

  KDictCurrentPage _currentPage=KDictCurrentPage.home;
  BuildContext _pageContext;
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    return WillPopScope(
      child: Scaffold(
        appBar: AppBar(
          title: Container(
            child: Row(
              children: <Widget>[
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage("./images/lw_dict.png"),
                      fit: BoxFit.contain
                    )
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(left: 16),
                  child: Text(
                      "LoveWorld Dictionary",
                    style: TextStyle(
              fontFamily: "ubuntu"
          )
                  ),
                )
              ],
            ),
          ),
        ),
        drawer: Drawer(
          child: ListView(
            children: <Widget>[
              Container(
                margin: EdgeInsets.only(bottom: 9, top: 16),
                child: ListTile(
                  leading: Icon(
                      FlutterIcons.home_ant,
                    color: Colors.blueGrey,
                  ),
                  title: Text(
                      "Home"
                  ),
                  onTap: (){
                    _currentPage= KDictCurrentPage.home;
                    _dictCtr.add("kjut");
                  },
                ),
              ),//home tile
              Container(
                margin: EdgeInsets.only(bottom: 9),
                child: ListTile(
                  leading: Icon(
                      FlutterIcons.book_open_faw5s,
                    color: Colors.blueGrey,
                  ),
                  title: Text(
                      "Word of the day"
                  ),
                  onTap: (){

                  },
                ),
              ),
              Container(
                margin: EdgeInsets.only(bottom: 9),
                child: ListTile(
                  leading: Icon(
                      FlutterIcons.praying_hands_faw5s,
                    color: Colors.blueGrey,
                  ),
                  title: Text(
                      "Affirmation of the day"
                  ),
                  onTap: (){

                  },
                ),
              ),
              Container(
                margin: EdgeInsets.only(bottom: 9),
                child: ListTile(
                  leading: Icon(
                    FlutterIcons.comment_quotes_fou,
                    color: Colors.blueGrey,
                  ),
                  title: Text(
                      "Quote of the week"
                  ),
                  onTap: (){

                  },
                ),
              ),
              Container(
                margin: EdgeInsets.only(bottom: 9),
                child: ListTile(
                  leading: Icon(
                    FlutterIcons.history_faw,
                    color: Colors.blueGrey,
                  ),
                  title: Text(
                      "History"
                  ),
                  onTap: (){

                  },
                ),
              )
            ],
          ),
        ),

        body: StreamBuilder(
          stream: _dictCtr.stream,
          builder: (BuildContext _ctx, AsyncSnapshot _globsnapshot){
            if(_currentPage == KDictCurrentPage.home){
              return DictHome();
            }
            return DictHome();
          },
        ),
      ),
      onWillPop: ()async{
        Navigator.pop(_pageContext);
        return false;
      },
    );
  }

  StreamController _dictCtr= StreamController.broadcast();
  dispose(){
    super.dispose();
    _dictCtr.close();
  }
}