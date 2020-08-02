import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;

import './home.dart';
import 'word_list.dart';
import './history.dart';
import './wod.dart';
import './affirmation.dart';
import './weekly_quotes.dart';
import '../globals.dart' as globals;
import '../dbs.dart';

enum KDictCurrentPage{
  home,
  word_of_the_day,
  affirmation_of_the_day,
  quote_of_the_week,
  history,
  dictionary
}
class LWDictionary extends StatefulWidget{
  _LWDictionary createState(){
    return _LWDictionary();
  }
  final String switchPage;
  LWDictionary({this.switchPage});
}

class _LWDictionary extends State<LWDictionary>{
  initState(){
    super.initState();
    initDatabase();
    if(widget.switchPage == "dictionary"){
      currentPage= KDictCurrentPage.dictionary;
    }
    else if(widget.switchPage == "wod"){
      currentPage= KDictCurrentPage.word_of_the_day;
    }
    else if(widget.switchPage == "affirmation"){
      currentPage= KDictCurrentPage.affirmation_of_the_day;
    }
    else if(widget.switchPage == "weeklyquotes"){
      currentPage= KDictCurrentPage.quote_of_the_week;
    }
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

  static KDictCurrentPage currentPage=KDictCurrentPage.home;
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
                  child: StreamBuilder(
                    stream: _dictCtr.stream,
                    builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                      if(currentPage == KDictCurrentPage.home){
                        return Text(
                            "LoveWorld Dictionary",
                            style: TextStyle(
                                fontFamily: "ubuntu"
                            )
                        );
                      }
                      else if(currentPage == KDictCurrentPage.history){
                        return Text(
                            "Recent Searches",
                            style: TextStyle(
                                fontFamily: "ubuntu"
                            )
                        );
                      }
                      else if(currentPage == KDictCurrentPage.word_of_the_day){
                        return Text(
                            "Word of the day",
                            style: TextStyle(
                                fontFamily: "sail"
                            )
                        );
                      }
                      else if(currentPage == KDictCurrentPage.affirmation_of_the_day){
                        return Text(
                            "Affirmation Archives",
                            style: TextStyle(
                                fontFamily: "ubuntu"
                            )
                        );
                      }
                      else if(currentPage == KDictCurrentPage.quote_of_the_week){
                        return Text(
                            "Weekly Quotes",
                            style: TextStyle(
                                fontFamily: "sail"
                            )
                        );
                      }
                      else{
                        return Text(
                            "LoveWorld Dictionary",
                            style: TextStyle(
                                fontFamily: "ubuntu"
                            )
                        );
                      }
                    },
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
                    Navigator.pop(_pageContext);
                    currentPage= KDictCurrentPage.home;
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
                    Navigator.pop(context);
                    currentPage=KDictCurrentPage.word_of_the_day;
                    _dictCtr.add("kjut");
                  },
                ),
              ),//word of the day
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
                    Navigator.pop(_pageContext);
                    currentPage=KDictCurrentPage.affirmation_of_the_day;
                    _dictCtr.add("kjut");
                  },
                ),
              ),//affirmation of the day
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
                    Navigator.pop(context);
                    currentPage=KDictCurrentPage.quote_of_the_week;
                    _dictCtr.add("kjut");
                  },
                ),
              ),//quote of the week
              Container(
                margin: EdgeInsets.only(bottom: 9),
                child: ListTile(
                  leading: Icon(
                    FlutterIcons.sort_alphabetical_mco,
                    color: Colors.blueGrey,
                  ),
                  title: Text(
                      "Dictionary"
                  ),
                  onTap: (){
                    Navigator.pop(_pageContext);
                    currentPage=KDictCurrentPage.dictionary;
                    _dictCtr.add("kjut");
                  },
                ),
              ),//dictionary
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
                    Navigator.pop(_pageContext);
                    currentPage=KDictCurrentPage.history;
                    _dictCtr.add("kjut");
                  },
                ),
              )//history
            ],
          ),
        ),

        body: StreamBuilder(
          stream: _dictCtr.stream,
          builder: (BuildContext _ctx, AsyncSnapshot _globsnapshot){
            if(currentPage == KDictCurrentPage.home){
              return DictHome();
            }
            else if(currentPage == KDictCurrentPage.dictionary){
              return DictWords();
            }
            else if(currentPage == KDictCurrentPage.history){
              return SearchHistory();
            }
            else if(currentPage == KDictCurrentPage.word_of_the_day){
              return WOD();
            }
            else if(currentPage == KDictCurrentPage.affirmation_of_the_day){
              return IAffirm();
            }
            else if(currentPage == KDictCurrentPage.quote_of_the_week){
              return WeeklyQuotes();
            }
            return DictHome();
          },
        ),
      ),
      onWillPop: ()async{
        if(currentPage == KDictCurrentPage.home){
          Navigator.pop(_pageContext);
        }
        else{
          currentPage=KDictCurrentPage.home;
          _dictCtr.add("kjut");
        }
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