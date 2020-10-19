import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import "package:flutter/material.dart";
import 'package:flutter_icons/flutter_icons.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../globals.dart' as globals;
import './theme_data.dart' as pageTheme;
import 'chapter_details.dart';
import '../dbs.dart';

class SearchChapter extends StatefulWidget{
  _SearchChapter createState(){
    return _SearchChapter();
  }
}

class _SearchChapter extends State<SearchChapter>{

  DBTables _dbTables=DBTables();
  @override
  initState(){
    fetchHistory();
    super.initState();
  }//route's init state

  List _suggestions= List();
  //bool _fetchingSuggestion=false;
  fetchSuggestions()async{
    _pageState="suggestion";

    if(_searchCtr.text.length>1){
      //_fetchingSuggestion=true;
      try{
        http.Response _resp=await http.post(
          globals.globBaseCHFinder + "?process_as=get_suggestion",
          body: {
            "start": _suggestions.length.toString(),
            "query": _searchCtr.text
          }
        );
        if(_resp.statusCode == 200){
          List _respObj= jsonDecode(_resp.body);
          //_fetchingSuggestion=false;
          if(_respObj.length == 0 && _suggestions.length == 0){
            _suggestions=["No match was found for your query"];
          }
          else{
            _suggestions.addAll(_respObj);
          }
          _pageDataAvailNotifier.add("kjut");
        }
      }
      catch(ex){
        //_fetchingSuggestion=false;
        _suggestions=[globals.noInternet];
        if(!_pageDataAvailNotifier.isClosed)_pageDataAvailNotifier.add("kjut");
      }
    }
  }//fetch suggestions

  String _pageState="history";
  List<String> _searchHistory=List<String>();
  fetchHistory()async{
    Database _con= await _dbTables.chFinder();
    List _result= await _con.rawQuery("select search_q from search_history order by cast(time_str as signed) desc limit 100");
    int _kount= _result.length;
    for(int _k=0; _k<_kount; _k++){
      _searchHistory.add(_result[_k]["search_q"]);
    }
    _pageState="history";
    if(!_pageDataAvailNotifier.isClosed)_pageDataAvailNotifier.add("kjut");
  }//fetch local history

  BuildContext _pageContext;
  Size _screenSize;
  String _deviceTheme="";
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize=MediaQuery.of(_pageContext).size;
    return WillPopScope(
      child: Scaffold(
        backgroundColor: pageTheme.bgColor,
        body: FocusScope(
          child: Container(
            child: Stack(
              children: [
                Container(
                  width: _screenSize.width,
                  height: _screenSize.height,
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.only(left: 16, right: 16),
                        margin: EdgeInsets.only(top: 65),
                        child: Container(
                          decoration: BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(
                                      color: pageTheme.borderColor
                                  )
                              ),
                          ),
                          width: _screenSize.width - 32,
                          height: 45,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                padding:EdgeInsets.only(left: 48, right: 16),
                                child: Hero(
                                  tag: "search_box",
                                  child: Material(
                                    color: Colors.transparent,
                                    child: TextField(
                                      decoration: InputDecoration(
                                          hintText: "Search for a chapter",
                                          focusedBorder: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          hintStyle: TextStyle(
                                              fontStyle: FontStyle.italic,
                                              color: pageTheme.fontGrey
                                          )
                                      ),
                                      style: TextStyle(
                                          color: pageTheme.fontColor2
                                      ),
                                      autofocus: true,
                                      controller: _searchCtr,
                                      onChanged: (_){
                                        _suggestions=List();
                                        fetchSuggestions();
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 9,
                                top: 18,
                                child: Hero(
                                  tag: "finder_logo",
                                  child: Container(
                                    width: 32, height: 15,
                                    decoration: BoxDecoration(
                                        image: DecorationImage(
                                            image: AssetImage("./images/chapter_finder.png")
                                        )
                                    ),
                                  ),
                                ),
                              )
                            ],
                          ),
                        )
                      ),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.only(left: 16, right: 16),
                          margin: EdgeInsets.only(top: 32),
                          child: StreamBuilder(
                            stream: _pageDataAvailNotifier.stream,
                            builder: (BuildContext _ctx, AsyncSnapshot _pageShot){
                              if(_pageState=="history"){
                                return ListView.builder(
                                  padding: EdgeInsets.only(top: 0),
                                  itemCount: _searchHistory.length+1,
                                    itemBuilder: (BuildContext _ctx, int _itemIndex){
                                      if(_itemIndex == 0){
                                        return Container(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                      border: Border(
                                                          bottom: BorderSide(
                                                              color: pageTheme.bgColorVar1
                                                          )
                                                      )
                                                  ),
                                                  padding: EdgeInsets.only(bottom: 7),
                                                  child: Container(
                                                    child: Text(
                                                      "RECENT SEARCHES",
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: pageTheme.fontGrey
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              _searchHistory.length == 0 ? Container(
                                                margin:EdgeInsets.only(top: 5),
                                                child: Text(
                                                  "You do have any search history",
                                                  style: TextStyle(
                                                    color: pageTheme.fontColor2,
                                                    fontStyle: FontStyle.italic
                                                  ),
                                                ),
                                              ):Container()
                                            ],
                                          ),
                                        );
                                      }
                                      return Container(
                                        margin: EdgeInsets.only(bottom: 7),
                                        child: ListTile(
                                          leading: Container(
                                            child: Icon(
                                              FlutterIcons.history_mco,
                                              color: pageTheme.fontColor2,
                                              size: 18,
                                            ),
                                          ),
                                          title: Container(
                                            child: Text(
                                              _searchHistory[_itemIndex - 1],
                                              style: TextStyle(
                                                  color: pageTheme.fontGrey
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          onTap: (){
                                            if(_searchHistory[_itemIndex-1]!=globals.noInternet && _searchHistory[_itemIndex-1] != "No match was found for your query"){
                                              Navigator.of(context).push(CupertinoPageRoute(
                                                  builder: (BuildContext _ctx){
                                                    return ChapterDetails(_searchHistory[_itemIndex - 1]);
                                                  }
                                              ));
                                            }
                                          },
                                        ),
                                      );
                                    }
                                );
                              }
                              else if (_pageState == "suggestion"){
                                return ListView.builder(
                                  physics: BouncingScrollPhysics(),
                                  cacheExtent: _screenSize.height,
                                  padding: EdgeInsets.only(top: 0),
                                  itemCount: _suggestions.length,
                                    itemBuilder: (BuildContext _ctx, int _itemIndex){
                                      return Container(
                                        margin: EdgeInsets.only(bottom: 7),
                                        child: ListTile(
                                          leading: Container(
                                            child: Icon(
                                              FlutterIcons.search1_ant,
                                              color: pageTheme.fontColor2,
                                              size: 18,
                                            ),
                                          ),
                                          title: Container(
                                            child: Text(
                                              _suggestions[_itemIndex],
                                              style: TextStyle(
                                                color: pageTheme.fontGrey
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          onTap: (){
                                            if(_suggestions[_itemIndex]!=globals.noInternet && _suggestions[_itemIndex] != "No match was found for your query"){
                                              Navigator.of(context).push(CupertinoPageRoute(
                                                  builder: (BuildContext _ctx){
                                                    return ChapterDetails(_suggestions[_itemIndex]);
                                                  }
                                              ));
                                            }
                                          },
                                        ),
                                      );
                                    }
                                );
                              }
                              return Container();
                            },
                          ),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
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

  TextEditingController _searchCtr=TextEditingController();
  StreamController _pageDataAvailNotifier =StreamController.broadcast();
  @override
  void dispose() {
    _searchCtr.dispose();
    _pageDataAvailNotifier.close();
    super.dispose();
  }
}