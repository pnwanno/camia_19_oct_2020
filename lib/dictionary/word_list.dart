import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../dbs.dart';
import './search_result.dart';
class DictWords extends StatefulWidget{
  _DictWords createState(){
    return _DictWords();
  }
}

class _DictWords extends State<DictWords> with SingleTickerProviderStateMixin{
  List<String> _tabListStr=["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"];

  TabController _tabController;
  List<Widget> _tabChildren= List<Widget>();
  List<Widget> _tVChildren= List<Widget>();
  @override
  void initState() {
    super.initState();
    initTBCtr();
  }//route's init state method

  int _curTab=0;
  initTBCtr(){
    int _licount= _tabListStr.length;
    for(int _k=0; _k<_licount; _k++){
      _tabChildren.add(
          StreamBuilder(
            stream: _tabChangedNotifier.stream,
            builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
              return AnimatedContainer(
                duration: Duration(milliseconds: 400),
                curve: Curves.linear,
                padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
                decoration: BoxDecoration(
                    color: _curTab == _k ? Colors.white : Color.fromRGBO(220, 220, 220, 1),
                    borderRadius: BorderRadius.circular(12)
                ),
                child: Text(
                  _tabListStr[_k],
                  style: TextStyle(
                      color: _curTab == _k ? Colors.blue : Colors.grey
                  ),
                ),
              );
            },
          )
      );
      _tVChildren.add(
          FutureBuilder(
            future: fetchLocalWords(_tabListStr[_k]),
            builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
              if(_snapshot.hasData){
                return _snapshot.data;
              }
              else{
                return Container(
                  alignment: Alignment.center,
                  height: 300,
                  child: CircularProgressIndicator(),
                );
              }
            },
          )
      );
    }
    _tabController=TabController(
        length: _licount,
        vsync: this
    );
    _tabController.addListener(() {
      _curTab= _tabController.index;
      _tabChangedNotifier.add("kjut");
    });
    _tbStreamCtr.add("kjut");
    _tVStreamCtr.add("kjut");
  }//initializes the tb controller and the tb children
  
  DBTables _dbTables= DBTables();
  fetchLocalWords(String wordQ)async{
    Database _con= await _dbTables.lwDict();
    String _targQ="$wordQ%";
    var _result= await _con.rawQuery("select title from dict_words where title like ?", [_targQ]);
    int _count= _result.length;
    return Container(
      padding: EdgeInsets.only(top: 16, left: 16, right: 16),
      child: ListView.builder(
          itemCount: _count+1,
          itemBuilder: (BuildContext _ctx, int _itemIndex){
            if(_itemIndex == 0){
              return Container(
                child: Column(
                  children: <Widget>[
                    Container(
                      margin: EdgeInsets.only(bottom: 16),
                      child: Text(
                        wordQ,
                        style: TextStyle(
                            fontFamily: "sail",
                            fontSize: 32,
                          color: Colors.black
                        ),
                      ),
                    )
                  ],
                ),
              );
            }
            else{
              return Container(
                margin: EdgeInsets.only(bottom: 7),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(248, 248, 248, .7),
                  boxShadow: [
                    BoxShadow(
                      offset: Offset(0, 1),
                      color: Color.fromRGBO(230, 230, 230, 1),
                      blurRadius: 2
                    )
                  ],
                  borderRadius: BorderRadius.circular(12)
                ),
                child: ListTile(
                  onTap: (){
                    Navigator.of(context).push(CupertinoPageRoute(
                      builder: (BuildContext _routeCtx){
                        return DictSearchResult(_result[_itemIndex - 1]["title"], calledFrom: "dictionary",);
                      }
                    ));
                  },
                  title: Text(
                      _result[_itemIndex - 1]["title"],
                    style: TextStyle(
                      color: Colors.black
                    ),
                  ),
                ),
              );
            }
          }
      ),
    );
  }//fetch local words

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(246, 248, 246, 1),
      body: Container(
        child: Column(
          children: <Widget>[
            Container(
              padding: EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: Colors.lightBlueAccent,
              ),
              child: StreamBuilder(
                stream: _tbStreamCtr.stream,
                builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                  return TabBar(
                    tabs: _tabChildren,
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: Colors.transparent,
                  );
                },
              ),
            ),

            Expanded(
              child: Container(
                child: StreamBuilder(
                  stream: _tVStreamCtr.stream,
                  builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                    if(_snapshot.hasData){
                      debugPrint("kjut has data $_tVChildren");
                    }
                    return TabBarView(
                      controller: _tabController,
                      children: _tVChildren,
                    );
                  },
                ),
              ),
            )
          ],
        ),
      ),
    );
  }//route's build method

  StreamController _tbStreamCtr= StreamController.broadcast();
  StreamController _tVStreamCtr= StreamController.broadcast();
  StreamController _tabChangedNotifier= StreamController.broadcast();
  @override
  void dispose() {
    super.dispose();
    _tabController.dispose();
    _tVStreamCtr.close();
    _tbStreamCtr.close();
    _tabChangedNotifier.close();
  }//route's dispose method
}