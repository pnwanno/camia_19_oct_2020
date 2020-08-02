import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:sqflite/sqflite.dart';

import '../dbs.dart';
import './search_result.dart';

class DictSearch extends StatefulWidget{
  _DictSearch createState(){
    return _DictSearch();
  }
}

class _DictSearch extends State<DictSearch>{
  DBTables _dbTables= DBTables();
  @override
  void initState() {
    super.initState();
    fetchSearchHistory();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      RenderBox _rb= _appBarKey.currentContext.findRenderObject();
      _suggestionListHeight= _screenSize.height - (_rb.size.height);
      _itemSuggestNotifier.add("kjut");
    });
  }//route's init state

  List<String> _historyLi=List<String>();
  List<String> _suggestions= List<String>();
  Database _searchCon;
  searchDB()async{
    _suggestions=List<String>();
    if(_searchCtr.text == ""){
      _suggestions= _historyLi;
      _itemSuggestNotifier.add("kjut");
    }
    else{
      int _histcount= _historyLi.length;
      for(int _k=0; _k< _histcount; _k++){
        if(_historyLi[_k].indexOf(RegExp(_searchCtr.text, caseSensitive: false)) == 0){
          _suggestions.add(_historyLi[_k]);
        }
      }
      String _qText=_searchCtr.text + "%";
      var _result=await _searchCon.rawQuery("select * from dict_words where title like ? limit 20", [_qText]);
      int _resCount= _result.length;
      for(int _k=0; _k<_resCount; _k++){
        if(_historyLi.indexOf(_result[_k]["title"])<0) {
          _suggestions.add(_result[_k]["title"]);
        }
      }
      _itemSuggestNotifier.add("kjut");
    }
  }//search db

  fetchSearchHistory()async{
    Database _con=await _dbTables.lwDict();
    _searchCon= await _dbTables.lwDict();
    var _result= await _con.rawQuery("select title from search_history order by title asc");
    int _count= _result.length;
    for(int _k=0; _k<_count; _k++){
      _historyLi.add(_result[_k]["title"]);
      _suggestions.add(_result[_k]["title"]);
    }
    _itemSuggestNotifier.add("kjut");
  }

    buildLiChildren(){
    List<Widget> _liChildren= List<Widget>();
    int _count= _suggestions.length;
    for(int _k=0; _k< _count; _k++){
      String _targText=_suggestions[_k];
      bool _inHistory= _historyLi.indexOf(_targText)>-1;
      _liChildren.add(
          Container(
            decoration: BoxDecoration(
                border:Border(
                    bottom: BorderSide(
                        color: Colors.grey
                    )
                )
            ),
            child: ListTile(
              title: Text(
                  _targText
              ),
              trailing: Icon(
                  (_inHistory) ? FlutterIcons.history_faw : FlutterIcons.search1_ant
              ),
              onTap: (){
                Navigator.of(_pageContext).push(
                  MaterialPageRoute(
                    builder: (BuildContext _routeCtx){
                      return DictSearchResult(_targText, calledFrom: "search",);
                    }
                  )
                );
              },
            ),
          )
      );
    }
    return _liChildren;
  }

  BuildContext _pageContext;
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize= MediaQuery.of(_pageContext).size;
    return Scaffold(
      body: Container(
        child: ListView(
          children: <Widget>[
            Container(
              key: _appBarKey,
              color: Colors.blue,
              child: Column(
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
                                autofocus: true,
                                controller: _searchCtr,
                                decoration: InputDecoration(
                                    hintText: "Search dictionary ...",
                                    hintStyle: TextStyle(
                                      color: Colors.grey
                                    ),
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none
                                ),
                                onChanged: (String _curText){
                                  searchDB();
                                },
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),//pseudo app bar

            StreamBuilder(
              stream: _itemSuggestNotifier.stream,
              builder: (BuildContext _suggext, _sugShot){
                return Container(
                  height: _suggestionListHeight,
                  child: Column(
                    children: buildLiChildren(),
                  ),
                );
              }
            )//suggestion box
          ],
        ),
      ),
    );
  }//route's build method

  StreamController _itemSuggestNotifier= StreamController.broadcast();
  final GlobalKey _appBarKey= GlobalKey();
  double _suggestionListHeight=200;
  TextEditingController _searchCtr= TextEditingController();
  @override
  void dispose() {
    super.dispose();
    _searchCtr.dispose();
    _itemSuggestNotifier.close();
  }//route's dispose method
}