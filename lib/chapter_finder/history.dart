import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:sqflite/sqflite.dart';

import '../dbs.dart';
import 'theme_data.dart' as pageTheme;
import './chapter_details.dart';
class SearchHistory extends StatefulWidget{
  _SearchHistory createState(){
    return _SearchHistory();
  }
}

class _SearchHistory extends State<SearchHistory>{

  @override
  initState(){
    fetchHistory();
    super.initState();
  }

  DBTables _dbTables= DBTables();
  List _pageData= List();
  fetchHistory()async{
    Database _con= await _dbTables.chFinder();
    List _result= await _con.rawQuery("select * from search_history order by cast(time_str as signed) desc");
    int _kount= _result.length;
    for(int _k=0; _k<_kount; _k++){
      DateTime _targTime= DateTime.fromMillisecondsSinceEpoch(int.tryParse(_result[_k]["time_str"]));
      _pageData.add({
        "text": _result[_k]["search_q"],
        "time": _targTime.day.toString() + "/" + _targTime.month.toString() + "/" + _targTime.year.toString() + " " + _targTime.hour.toString() + ":" + _targTime.minute.toString(),
        "id": _result[_k]["id"].toString()
      });
    }
    if(_pageData.length == 0){
      _pageData.add({
        "nodata":"nodata"
      });
    }
    if(!_pageDataAvailNotifier.isClosed)_pageDataAvailNotifier.add("kjut");
  }//fetch history

  BuildContext _pageContext;
  Size _screenSize;
  String _deviceTheme="";
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize= MediaQuery.of(context).size;
    return WillPopScope(
      child: Scaffold(
        backgroundColor: pageTheme.bgColor,
        appBar: AppBar(
          backgroundColor: pageTheme.bgColorVar1,
          title: Text(
            "Search history",
            style: TextStyle(
              color: pageTheme.fontColor
            ),
          ),
          iconTheme: IconThemeData(
            color: pageTheme.fontColor
          ),
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
                    builder: (BuildContext _ctx, AsyncSnapshot _pageShot){
                      if(_pageData.length>0){
                        Map _firstMap=_pageData[0];
                        if(_firstMap.containsKey("nodata")){
                          return Container(
                            padding: EdgeInsets.only(left: 16, right: 16),
                            child: Text(
                              "You do not have any records yet, here",
                              style: TextStyle(
                                color: pageTheme.fontColor,
                                fontStyle: FontStyle.italic
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          itemCount: _pageData.length,
                            itemBuilder: (BuildContext _ctx, int _itemIndex){
                              String _targText= _pageData[_itemIndex]["text"];
                              GlobalKey _dismissKey= GlobalKey();
                              return Dismissible(
                                key: _dismissKey,
                                background: Container(
                                  color: pageTheme.bgColorVar1,

                                ),
                                child: Container(
                                  padding: EdgeInsets.only(left: 16, right: 16),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: ListTile(
                                      leading: Container(
                                        child: Icon(
                                          FlutterIcons.history_mco,
                                          color: pageTheme.fontColor2,
                                        ),
                                      ),
                                      title: Container(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              child: Text(
                                                _targText,
                                                style: TextStyle(
                                                    color: pageTheme.fontColor2
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                      onTap: (){
                                        Navigator.of(context).push(MaterialPageRoute(
                                          builder: (BuildContext _ctx){
                                            return ChapterDetails(_targText);
                                          }
                                        ));
                                      },
                                    ),
                                  ),
                                ),
                              );
                            }
                        );
                      }
                      return Container(
                        alignment: Alignment.center,
                        child: Container(
                          width: 32, height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(pageTheme.fontColor),
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

  StreamController _pageDataAvailNotifier=StreamController.broadcast();
  @override
  void dispose() {
    _pageDataAvailNotifier.close();
    super.dispose();
  }//route's dispose method
}