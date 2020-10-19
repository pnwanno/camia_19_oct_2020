import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:http/http.dart' as http;

import '../kcache_mgr.dart';
import '../globals.dart' as globals;
import 'theme_data.dart' as pageTheme;
import 'news_details.dart';

class Search extends StatefulWidget{
  _Search createState(){
    return _Search();
  }
}

class _Search extends State<Search>{

  @override
  initState(){
    initCacheMgr();
    super.initState();
  }

  Map _availCache= Map();
  KjutCacheMgr _kjutCacheMgr=KjutCacheMgr();
  initCacheMgr()async{
    _kjutCacheMgr.initMgr();
    _availCache= await _kjutCacheMgr.listAvailableCache();
  }

  List _pageData= List();
  fetchSuggestions()async{
    _pageData=List();
    try{
      if(_searchTxtCtr.text.length>1){
        http.Response _resp= await http.post(
          globals.globBaseNewsAPI + "?process_as=news_search_suggestions",
          body: {
            "user_id": globals.userId,
            "query" : _searchTxtCtr.text,
            "category": "Conferences"
          }
        );
        if(_resp.statusCode == 200){
          List _respObj= jsonDecode(_resp.body);
          if(_respObj.length>0){
            _pageData.addAll(_respObj);
            if(!_suggestionAvailNotifier.isClosed){
              _suggestionAvailNotifier.add("kjut");
            }
          }
          else{
            _pageData.add({
              "nodata": "nodata"
            });
            if(!_suggestionAvailNotifier.isClosed){
              _suggestionAvailNotifier.add("kjut");
            }
          }
        }
      }
    }
    catch(ex){
      _pageData.add({
        "error": "network"
      });
      if(!_suggestionAvailNotifier.isClosed){
        _suggestionAvailNotifier.add("kjut");
      }
    }
  }//fetch suggestions

  BuildContext _pageContext;
  Size _screenSize;
  String _deviceTheme="";
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize= MediaQuery.of(_pageContext).size;
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.red
                        ),
                      ),
                      Container(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: pageTheme.fontGrey
                              )
                            )
                          ),
                          padding: EdgeInsets.only(left: 12, right: 12, top: 9),
                          child: TextField(
                            focusNode: _searchNode,
                            style: TextStyle(
                              color: pageTheme.fontColor
                            ),
                            controller: _searchTxtCtr,
                            decoration: InputDecoration(
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              hintText: "Search Conferences",
                              hintStyle: TextStyle(
                                color: pageTheme.fontGrey
                              ),
                              prefixIcon: Icon(
                                FlutterIcons.search1_ant,
                                size: 14,
                                color: pageTheme.fontGrey,
                              )
                            ),
                            onChanged: (_){
                              fetchSuggestions();
                            },
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          child: StreamBuilder(
                            stream: _suggestionAvailNotifier.stream,
                            builder: (BuildContext _ctx, AsyncSnapshot _pageShot){
                              if(_pageData.length>0){
                                Map _firstMap= _pageData[0];
                                if(_firstMap.containsKey("error")){
                                  return Container(
                                    padding: EdgeInsets.only(left: 16, right: 16),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          child: Icon(
                                            FlutterIcons.cloud_off_outline_mco,
                                            size: 32,
                                            color: pageTheme.fontGrey,
                                          ),
                                        ),
                                        Container(
                                          child: Text(
                                            globals.noInternet,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: pageTheme.fontGrey
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  );
                                }
                                else if(_firstMap.containsKey("nodata")){
                                  return Container(
                                    padding: EdgeInsets.only(left: 12, right: 12, top: 16),
                                    child: Text(
                                      "No item match your search request",
                                      style: TextStyle(
                                        color: pageTheme.fontGrey
                                      ),
                                    ),
                                  );
                                }
                                else{
                                  return ListView.builder(
                                    padding: EdgeInsets.only(top: 0),
                                    physics: BouncingScrollPhysics(),
                                      itemCount: _pageData.length,
                                      itemBuilder: (BuildContext _ctx, int _itemIndex){
                                      Map _blockData= _pageData[_itemIndex];
                                      double _ar= double.tryParse(_blockData["ar"]);
                                      double _mediaHeight= (_screenSize.width * .3)/_ar;
                                      String _mediaPath= _blockData["media_path"];
                                      String _dp="$_mediaPath/" + _blockData["dp"];
                                        return Container(
                                          decoration: BoxDecoration(
                                            color: pageTheme.indexHeaderBG
                                          ),
                                          margin: EdgeInsets.only(bottom: 1),
                                          padding: EdgeInsets.only(top: 12, bottom: 12),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: (){
                                                Navigator.of(_pageContext).push(
                                                  CupertinoPageRoute(
                                                    builder: (BuildContext _ctx){
                                                      return NewsDetails(_blockData["news_id"]);
                                                    }
                                                  )
                                                );
                                              },
                                              child: Container(
                                                padding: EdgeInsets.only(left: 12, right: 12),
                                                child: Row(
                                                 children: [
                                                   Expanded(
                                                     child: Container(
                                                       padding: EdgeInsets.only(right: 12),
                                                       child: Column(
                                                         crossAxisAlignment: CrossAxisAlignment.start,
                                                         children: [
                                                           Container(
                                                             child: Text(
                                                               _blockData["title"],
                                                               maxLines: 3,
                                                               overflow: TextOverflow.ellipsis,
                                                               style: TextStyle(
                                                                 color: pageTheme.indexHeaderTitle
                                                               ),
                                                             ),
                                                           ),
                                                           Container(
                                                             margin: EdgeInsets.only(top: 3),
                                                             child: Row(
                                                               children: [
                                                                 Container(
                                                                   margin:EdgeInsets.only(right: 7),
                                                                   child: Text(
                                                                     _blockData["news_date"],
                                                                     style: TextStyle(
                                                                       fontSize: 12,
                                                                       color: pageTheme.indexHeaderDate
                                                                     ),
                                                                   ),
                                                                 ),
                                                                 Container(
                                                                   child: Text(
                                                                     "read ...",
                                                                     style: TextStyle(
                                                                       color: pageTheme.indexHeaderSubTitle,
                                                                       fontSize: 12
                                                                     ),
                                                                   ),
                                                                 )
                                                               ],
                                                             ),
                                                           )
                                                         ],
                                                       ),
                                                     ),
                                                   ),
                                                   Container(
                                                     width: _screenSize.width * .3,
                                                     height: _mediaHeight,
                                                     decoration: BoxDecoration(
                                                       image: DecorationImage(
                                                         image: _availCache.containsKey(_dp) ? FileImage(File(_availCache[_dp])) : NetworkImage(_dp)
                                                       )
                                                     ),
                                                   )
                                                 ],
                                                )
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                  );
                                }
                              }
                              return Container(
                                alignment: Alignment.center,
                                padding: EdgeInsets.only(left: 16, right: 16),
                                child: Text(
                                  "Type some texts to start your search",
                                  style: TextStyle(
                                    color: pageTheme.fontGrey
                                  ),
                                ),
                              );
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
          autofocus: true,
          onFocusChange: (bool _isFocused){
            if(_isFocused){
              FocusScope.of(_pageContext).requestFocus(_searchNode);
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
        Navigator.of(_pageContext).pop();
        return false;
      },
    );
  }//route's build method

  FocusNode _searchNode= FocusNode();
  TextEditingController _searchTxtCtr= TextEditingController();
  StreamController _suggestionAvailNotifier= StreamController.broadcast();
  @override
  void dispose() {
    _searchTxtCtr.dispose();
    _suggestionAvailNotifier.close();
    super.dispose();
  }//route's build method
}