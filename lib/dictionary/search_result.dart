import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_icons/flutter_icons.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;

import '../dbs.dart';
import '../globals.dart' as globals;
import './search.dart';

class DictSearchResult extends StatefulWidget{
  _DictSearchResult createState(){
    return _DictSearchResult();
  }
  final String searchStr;
  final calledFrom;
  DictSearchResult(this.searchStr, {this.calledFrom});
}

class _DictSearchResult extends State<DictSearchResult>{
  BuildContext _pageContext;
  Size _screenSize;
  
  @override
  void initState() {
    super.initState();
    searchWord();
  }//route's init state
  DBTables _dbTables= DBTables();
  searchWord()async{
    String _searchTerm= widget.searchStr;
    Database _con= await _dbTables.lwDict();
    _con.rawQuery("select * from dict_words where title=?", [_searchTerm]).then((_result) {
      if(_result.length>0){
        _wrdSearchCtr.add({
          "def": globals.kChangeCase(_result[0]["definition"], globals.KWordcase.sentence_case),
          "source_text" : globals.kChangeCase(_result[0]["source_txt"], globals.KWordcase.sentence_case)
        });
        String _wordId= _result[0]["word_id"];
        //add to search history if not there
        _con.rawQuery("select * from search_history where title=?", [_searchTerm]).then((_histResult) {
          if(_histResult.length<1){
            String _kita= DateTime.now().millisecondsSinceEpoch.toString();
            _con.execute("insert into search_history (title, word_id, time_str) values (?, ?, ?)", [_searchTerm, _wordId, _kita]);
          }
        });
        saveSearchGlobally(_wordId);
      }
    });
  }//local search word

  saveSearchGlobally(String wordId){
    http.post(
      globals.globBaseUrl2 + "?process_as=save_dict_word_search",
      body: {
        "user_id": globals.userId,
        "word_id": wordId
      }
    );
  }
  
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize= MediaQuery.of(_pageContext).size;
    return Scaffold(
      body: Container(
        child: ListView(
          children: <Widget>[
            Container(
              color: Colors.blue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: _screenSize.width,
                    padding: EdgeInsets.only(top: 12, bottom: 12, left: 24, right: 16),
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.lightBlue,
                      boxShadow: [
                        BoxShadow(
                            offset: Offset(0,2),
                            color: Color.fromRGBO(20, 20, 20, .3),
                            blurRadius: 2
                        )
                      ],
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          margin: EdgeInsets.only(right: 16),
                          width: 48, height: 32,
                          decoration: BoxDecoration(
                              image: DecorationImage(
                                  image: AssetImage("./images/lw_dict.png"),
                                  fit: BoxFit.contain
                              )
                          ),
                        ),
                        Container(
                          child: Text(
                            "LoveWorld Dictionary",
                            style: TextStyle(
                                color: Colors.white,
                                fontFamily: "ubuntu",
                                fontSize: 20
                            ),
                          ),
                        )
                      ],
                    ),
                  ),//false app bar
                  Container(
                    padding: EdgeInsets.only(left: 20, right: 20, bottom: 16),
                    child: Container(
                      width: _screenSize.width,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(7)
                      ),
                      padding: EdgeInsets.only(left: 20, right: 20),
                      child: Row(
                        children: <Widget>[
                          Container(
                            margin: EdgeInsets.only(right:12),
                            child: Icon(
                              FlutterIcons.search1_ant,
                              color: Colors.grey,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              child: TextField(
                                readOnly: true,
                                onTap: (){
                                  if(widget.calledFrom == "search"){
                                    Navigator.pop(_pageContext);
                                  }
                                  else{
                                    Navigator.of(_pageContext).push(
                                      MaterialPageRoute(
                                        builder: (BuildContext _ctx){
                                          return DictSearch();
                                        }
                                      )
                                    );
                                  }
                                },
                                decoration: InputDecoration(
                                    hintText: "Search dictionary ...",
                                    hintStyle: TextStyle(
                                        color: Colors.grey
                                    ),
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(top: 16,),
                    padding: EdgeInsets.only(left: 36, right: 24, bottom: 16),
                    child: Text(
                      widget.searchStr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontFamily: "ubuntu"
                      ),
                    ),
                  )
                ],
              ),
            ),//pseudo app bar

            Container(
              margin: EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 50, height: 1,
                          decoration: BoxDecoration(
                            color: Colors.grey
                          ),
                        ),
                        Container(
                          child: Text(
                            widget.searchStr,
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: "ubuntu"
                            ),
                          ),
                        )
                      ],
                    ),
                  ),//the word
                  StreamBuilder(
                    stream:_wrdSearchCtr.stream,
                    builder: (BuildContext _ctx, AsyncSnapshot _defShot){
                      return Container(
                        margin: EdgeInsets.only(top: 12),
                        padding: EdgeInsets.only(left: 24, right: 24),
                        child: (_defShot.hasData) ? Text(
                            _defShot.data["def"],
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ): Container(),
                      );
                    },
                  ),//the definition
                  StreamBuilder(
                    stream:_wrdSearchCtr.stream,
                    builder: (BuildContext _ctx, AsyncSnapshot _srcShot){
                      return Container(
                        margin: EdgeInsets.only(top: 12),
                        padding: EdgeInsets.only(left: 24, right: 24),
                        child: Wrap(
                          direction: Axis.horizontal,
                          children: <Widget>[
                            Container(
                              child: Text(
                                "Source",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ),
                            Container(
                              margin:EdgeInsets.only(left: 5),
                              child: (_srcShot.hasData) ? Text(
                                _srcShot.data["source_text"],
                                softWrap: true,
                              ): Container(),
                            )
                          ],
                        ),
                      );
                    },
                  ),//source text
                ],
              ),
            ),//actual word definition
          ],
        ),
      ),
    );
  }//route's build method

  StreamController _wrdSearchCtr= StreamController.broadcast();
  @override
  void dispose() {
    super.dispose();
    _wrdSearchCtr.close();
  }//route's dispose method
}