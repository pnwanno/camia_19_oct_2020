import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_icons/flutter_icons.dart';
import 'package:sqflite/sqflite.dart';

import '../globals.dart' as globals;
import './theme_data.dart' as pageTheme;
import '../kcache_mgr.dart';
import '../dbs.dart';
import './news_details.dart';
import './search.dart';

class Outreaches extends StatefulWidget{
  _Outreaches createState(){
    return _Outreaches();
  }
}

class _Outreaches extends State<Outreaches>{

  initState(){
    _cacheExpireTime= DateTime.now().add(Duration(days: 7));
    initCache();
    addLVEvents();
    super.initState();
  }//route's init state

  double _reloadHeight=80;
  double _mainLVLoaderTop=-50;
  bool _pointerDown=false;
  bool _shouldReloadMain=false;
  StreamController _mainReloaderCtr= StreamController.broadcast();
  ScrollController _mainLVCtr=ScrollController();
  addLVEvents(){
    _mainLVCtr.addListener(() {
      //event to reload page
      if(_mainLVCtr.position.pixels<0){
        _mainLVLoaderTop= (-1 * _mainLVCtr.position.pixels) - 25;
        if(_pointerDown == false && _mainLVLoaderTop>=_reloadHeight-3){
          //the -3 subtracted from the the reload height is just an allowance value to allow basic delay from the user
          _shouldReloadMain=true;
          //reload method goes here
          _updateLocal=true;
          _isFetching=false;
          //_pageData=List();
          fetchPageContent();
          //fetchLocal();

          Future.delayed(
              Duration(seconds: 2),
                  (){
                _mainLVLoaderTop=0;
                _shouldReloadMain=false;
                if(!_mainReloaderCtr.isClosed)_mainReloaderCtr.add("kjut");
              }
          );
        }
        if(!_mainReloaderCtr.isClosed)_mainReloaderCtr.add("kjut");
      }

      //event to fetch older content
      if(_isFetching == false){
        if(_mainLVCtr.position.pixels > _mainLVCtr.position.maxScrollExtent - (_screenSize.height * 2)){
          fetchPageContent();
        }
      }
    });
  }//add list view events

  DBTables _dbTables= DBTables();
  fetchLocal()async{
    Database _con= await _dbTables.cmNews();
    List _result= await _con.rawQuery("select * from cm_news where category='Outreaches' order by cast(news_date_str as signed) desc");
    int _kount= _result.length;
    if(_kount>0){
      _pageData=List();
      _pageData.addAll(_result);
      if(!_pageContentAvailNotifier.isClosed) _pageContentAvailNotifier.add("kjut");
    }
  }//fetch local data

  KjutCacheMgr _kjutCacheMgr= KjutCacheMgr();
  Map _availCache= Map();
  DateTime _cacheExpireTime= DateTime.now();
  initCache()async{
    _kjutCacheMgr.initMgr();
    _availCache= await _kjutCacheMgr.listAvailableCache();
    _updateLocal=true;
    fetchPageContent();
    fetchLocal();
  }//init cache

  cacheDownload()async{
    int _kount= _pageData.length;
    for(int _k=0; _k<_kount; _k++){
      Map _dataBlock= _pageData[_k];
      String _mediaPath= _dataBlock["media_path"];
      List<String> _brkDP= _dataBlock["dp"].toString().split(",");
      int _dpKount= _brkDP.length;
      for(int _j=0; _j<_dpKount; _j++){
        String _mediaFullPath=_mediaPath + "/" + _brkDP[_j];
        if(!_availCache.containsKey(_mediaFullPath)){
          _kjutCacheMgr.downloadFile(_mediaFullPath, _cacheExpireTime).then((value)async{
            _availCache= await _kjutCacheMgr.listAvailableCache();
            if(!_mediaAvailNotifier.isClosed) _mediaAvailNotifier.add("kjut");
          });
        }
      }
    }
  }//download and save to cache

  List _pageData=List();
  bool _isFetching=false;
  bool _updateLocal=false;
  fetchPageContent()async{
    if(_isFetching==false){
      _isFetching=true;
      try{
        http.Response _resp= await http.post(
            globals.globBaseNewsAPI + "?process_as=fetch_outreaches",
            body: {
              "user_id" : globals.userId,
              "start": _pageData.length.toString()
            }
        );
        if(_resp.statusCode == 200){
          List _respObj= jsonDecode(_resp.body);
          if(_respObj.length == 0 && _pageData.length==0){
            _pageData.add({
              "nodata": "nodata"
            });
            _pageContentAvailNotifier.add("kjut");
          }
          else if(_respObj.length>0){
            _isFetching=false;
            cacheDownload();
            //populate the local database
            if(_updateLocal){
              populateDB(_resp.body);
            }
          }
        }
      }
      catch(ex){
        _isFetching=false;
        //_pageData.add({
        //  "error": "nointernet"
        //});
        //_pageContentAvailNotifier.add("kjut");
      }
    }
  }//fetch page content

  populateDB(String _dataStr)async{
    //get existing data
    List<String> _existingID= List<String>();
    Database _con= await _dbTables.cmNews();
    List _result= await _con.rawQuery("select news_id from cm_news");
    int _resultCount= _result.length;
    for(int _k=0; _k<_resultCount; _k++){
      _existingID.add(_result[_k]["news_id"]);
    }

    List _dataObj= jsonDecode(_dataStr);
    int _kount = _dataObj.length;
    bool _foundNew=false;
    String _newsCategory="Outreaches";
    for(int _k=0; _k<_kount; _k++){
      Map _dataMap= _dataObj[_k];
      String _newsID=_dataMap["id"];
      if(_existingID.indexOf(_newsID)<0){
        _foundNew=true;
        _existingID.add(_newsID);
        if(_existingID.length>50){
          List _oldestnewsres= await _con.rawQuery("select id from cm_news order by cast(news_date_str as signed) asc limit 1");
          String _oldestnewsID= _oldestnewsres[0]["id"].toString();
          _con.execute("delete from cm_news where id=?", [_oldestnewsID]);
        }
        await _con.execute("insert into cm_news (category, title, media_path, dp, ar, news_date, news_id, news_date_str) values (?, ?, ?, ?, ?, ?, ?, ?)",[
          _newsCategory, _dataMap["title"], _dataMap["media_path"], _dataMap["dp"], _dataMap["ar"],
          _dataMap["news_date"],_newsID, _dataMap["news_date_str"]
        ]);
      }

    }
    if(_foundNew){
      fetchLocal();
    }
  }//populate local db

  int _curpageHNews=0;
  addPVCtrEvents(){
    _headNewsPageCtr.addListener(() {
      double _locPage= _headNewsPageCtr.page;
      if(_locPage.floor() == _locPage){
        _curpageHNews=_locPage.toInt();
        _headNewsPageChangeNotifier.add("kjut");
      }
    });
  }

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
          child: Listener(
            onPointerDown: (_){
              _pointerDown=true;
            },
            onPointerUp: (_){
              _pointerDown=false;
            },
            child: Container(
              child: Stack(
                children: [
                  Container(
                    width: _screenSize.width,
                    height: _screenSize.height,
                    child: StreamBuilder(
                      stream: _pageContentAvailNotifier.stream,
                      builder: (BuildContext _ctx, AsyncSnapshot _pageshot){
                        if(_pageData.length>0){
                          Map _firstMap=_pageData[0];
                          if(_firstMap.containsKey("error")){
                            return Container(
                              alignment: Alignment.center,
                              padding: EdgeInsets.only(left: 16, right: 16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                      margin:EdgeInsets.only(bottom: 3),
                                      child: Icon(
                                        FlutterIcons.cloud_off_outline_mco,
                                        size: 36,
                                        color: pageTheme.fontGrey,
                                      )
                                  ),
                                  Container(
                                    child: Text(
                                      globals.noInternet,
                                      style: TextStyle(
                                          color: pageTheme.fontGrey
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                ],
                              ),
                            );
                          }
                          else if(_firstMap.containsKey("nodata")){
                            return Container(
                              alignment: Alignment.center,
                              padding: EdgeInsets.only(left: 16, right: 16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                      margin:EdgeInsets.only(bottom: 3),
                                      child: Icon(
                                        FlutterIcons.newspaper_mco,
                                        size: 36,
                                        color: pageTheme.fontGrey,
                                      )
                                  ),
                                  Container(
                                    child: Text(
                                      "No content to show here",
                                      style: TextStyle(
                                          color: pageTheme.fontGrey
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                ],
                              ),
                            );
                          }
                          else{
                            return Container(
                              width: _screenSize.width,
                              height: _screenSize.height,
                              child: ListView.builder(
                                  controller: _mainLVCtr,
                                  physics: BouncingScrollPhysics(),
                                  itemCount: _pageData.length,
                                  cacheExtent: _screenSize.height * 3,
                                  itemBuilder: (BuildContext _ctx, int _itemIndex){
                                    Map _blockData= _pageData[_itemIndex];
                                    String _mediaPath= _blockData["media_path"];
                                    String _dpStr= _blockData["dp"];
                                    List<String> _dps= _dpStr.split(",");
                                    double _targAR= double.tryParse(_blockData["ar"]);
                                    double _mediaHeight=_screenSize.width/_targAR;
                                    String _newsID= _blockData["news_id"];
                                    if(_itemIndex == 0){
                                      List<Widget> _pvChildren= List<Widget>();
                                      int _kount= _dps.length;
                                      for(int _k=0; _k<_kount; _k++){
                                        String _targMediaPath=_mediaPath + "/" + _dps[_k];
                                        _pvChildren.add(
                                            StreamBuilder(
                                              stream: _mediaAvailNotifier.stream,
                                              builder: (BuildContext _ctx, AsyncSnapshot _mediashot){
                                                return Container(
                                                  decoration: BoxDecoration(
                                                      image: DecorationImage(
                                                          image: _availCache.containsKey(_targMediaPath)?
                                                          FileImage(File(_availCache[_targMediaPath])):
                                                          NetworkImage(_targMediaPath),
                                                          fit: BoxFit.cover
                                                      )
                                                  ),
                                                );
                                              },
                                            )
                                        );
                                      }
                                      addPVCtrEvents();
                                      return GestureDetector(
                                        onTap: (){
                                          Navigator.of(context).push(
                                              MaterialPageRoute(
                                                  builder: (BuildContext _ctx){
                                                    return NewsDetails(_newsID);
                                                  }
                                              )
                                          );
                                        },
                                        child: Container(
                                          padding: EdgeInsets.only(top: 7,  bottom: 7),
                                          decoration: BoxDecoration(
                                              color: pageTheme.indexHeaderBG
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: _screenSize.width,
                                                height: _mediaHeight,
                                                child: Container(
                                                  child: Stack(
                                                    children: [
                                                      Container(
                                                        width: _screenSize.width,
                                                        height: _mediaHeight,
                                                        child: PageView(
                                                          controller: _headNewsPageCtr,
                                                          physics: BouncingScrollPhysics(),
                                                          children: _pvChildren,
                                                        ),
                                                      ),
                                                      Positioned(
                                                        bottom: 12,
                                                        left: 0,
                                                        child: _kount>1 ?
                                                        Container(
                                                          width: _screenSize.width,
                                                          alignment: Alignment.center,
                                                          child: StreamBuilder(
                                                            stream: _headNewsPageChangeNotifier.stream,
                                                            builder: (BuildContext _ctx, AsyncSnapshot _scrollshot){
                                                              List<Widget> _rowChildren= List<Widget>();
                                                              for(int _j=0; _j<_kount; _j++){
                                                                _rowChildren.add(
                                                                    Container(
                                                                      margin: EdgeInsets.only(right: 3),
                                                                      width: 5, height: 5,
                                                                      decoration: BoxDecoration(
                                                                          borderRadius: BorderRadius.circular(5),
                                                                          color: _j == _curpageHNews ? Color.fromRGBO(220, 220, 100, 1) : Color.fromRGBO(200, 200, 200, 1)
                                                                      ),
                                                                    )
                                                                );
                                                              }
                                                              return Container(
                                                                padding: EdgeInsets.only(left: 5, top: 3, bottom: 3),
                                                                decoration: BoxDecoration(
                                                                    color: Color.fromRGBO(120, 120, 100, .5),
                                                                    borderRadius: BorderRadius.circular(3)
                                                                ),
                                                                child: Row(
                                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: _rowChildren,
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ): Container(),
                                                      )
                                                    ],
                                                  ),
                                                ),
                                              ),//dp slide
                                              Container(
                                                padding: EdgeInsets.only(left: 12, right: 12),
                                                margin: EdgeInsets.only(top: 7),
                                                child: Text(
                                                  _blockData["title"],
                                                  style: TextStyle(
                                                      color: pageTheme.indexHeaderTitle,
                                                      fontSize: 18,
                                                      fontFamily: "ubuntu"
                                                  ),
                                                ),
                                              ),//title
                                              Container(
                                                margin: EdgeInsets.only(top: 1),
                                                padding: EdgeInsets.only(left: 12, right: 12),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      child: Text(
                                                        _blockData["news_date"],
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color: pageTheme.indexHeaderDate,
                                                            fontFamily: "ubuntu"
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      margin: EdgeInsets.only(left: 12),
                                                      child: Text(
                                                        "read more...",
                                                        style: TextStyle(
                                                            color: pageTheme.indexHeaderSubTitle,
                                                            fontSize: 11,
                                                            fontFamily: "ubuntu"
                                                        ),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              )
                                            ],
                                          ),
                                        ),
                                      );
                                    }

                                    return Container(
                                      margin: EdgeInsets.only(top: 1),
                                      decoration: BoxDecoration(
                                          color: pageTheme.bgColor2
                                      ),
                                      padding: EdgeInsets.only(bottom: 12, top: 12),
                                      child: GestureDetector(
                                        onTap: (){
                                          Navigator.of(context).push(
                                              MaterialPageRoute(
                                                  builder: (BuildContext _ctx){
                                                    return NewsDetails(_newsID);
                                                  }
                                              )
                                          );
                                        },
                                        child: Container(
                                          child: Column(
                                            children: [
                                              Container(
                                                padding:EdgeInsets.only(left: 12, right: 12),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Container(
                                                        margin:EdgeInsets.only(right:12),
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Container(
                                                                child:Text(
                                                                  _blockData["title"],
                                                                  style: TextStyle(
                                                                    color: pageTheme.indexHeaderTitle,
                                                                    fontSize: 14,
                                                                  ),
                                                                  maxLines: 3,
                                                                  overflow: TextOverflow.ellipsis,
                                                                )
                                                            ),//post title
                                                            Container(
                                                              margin: EdgeInsets.only(top: 5),
                                                              child: Row(
                                                                children: [
                                                                  Container(
                                                                    child: Text(
                                                                      _blockData["news_date"],
                                                                      style: TextStyle(
                                                                          color: pageTheme.indexHeaderDate,
                                                                          fontSize: 11,
                                                                          fontFamily: "ubuntu"
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  Container(
                                                                    margin: EdgeInsets.only(left: 12),
                                                                    child: Text(
                                                                      "read more...",
                                                                      style: TextStyle(
                                                                          color: pageTheme.indexHeaderSubTitle,
                                                                          fontSize: 11,
                                                                          fontFamily:"ubuntu"
                                                                      ),
                                                                    ),
                                                                  )
                                                                ],
                                                              ),
                                                            )//post time and read more
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      width: _screenSize.width * .3,
                                                      height: _mediaHeight * .3,
                                                      child: StreamBuilder(
                                                        stream: _mediaAvailNotifier.stream,
                                                        builder: (BuildContext _ctx, AsyncSnapshot _mediashot){
                                                          String _targMediaPath="$_mediaPath/" + _dps[0];
                                                          return Container(
                                                              width: _screenSize.width * .3,
                                                              height: _mediaHeight * .3,
                                                              decoration: BoxDecoration(
                                                                  image: DecorationImage(
                                                                      image: _availCache.containsKey(_targMediaPath)?
                                                                      FileImage(File(_availCache[_targMediaPath])) :NetworkImage(_targMediaPath),
                                                                      fit: BoxFit.cover
                                                                  )
                                                              )
                                                          );
                                                        },
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                              ),
                            );
                          }
                        }
                        return Container(
                          alignment: Alignment.center,
                          child: Container(
                            width: 30, height: 30,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(pageTheme.fontGrey),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 64, left: 0,
                    width: _screenSize.width,
                    child: Container(
                      padding: EdgeInsets.only(left: 12, right: 12),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: (){

                          },
                          child: Container(
                            decoration: BoxDecoration(
                                color: pageTheme.fontGrey.withOpacity(.3),
                                borderRadius: BorderRadius.circular(7)
                            ),
                            padding: EdgeInsets.only(left: 12, right: 12),
                            child: TextField(
                              onTap: (){
                                Navigator.of(_pageContext).push(MaterialPageRoute(
                                    builder: (BuildContext _ctx){
                                      return Search();
                                    }
                                ));
                              },
                              decoration: InputDecoration(
                                  hintText: "Search outreaches",
                                  hintStyle: TextStyle(
                                      color: Colors.white
                                  ),
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  prefixIcon: Icon(
                                    FlutterIcons.search1_ant,
                                    color: Colors.white,
                                    size: 20,
                                  )
                              ),
                              readOnly: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),//search outreaches
                  StreamBuilder(
                    stream: _mainReloaderCtr.stream,
                    builder: (BuildContext _ctx, AsyncSnapshot _loadShot){
                      return Positioned(
                        width: _screenSize.width,
                        top: _shouldReloadMain ? _reloadHeight : _mainLVLoaderTop,
                        child: Opacity(
                          opacity: (_mainLVLoaderTop < 40) && !_shouldReloadMain ? 0 : 1,
                          child: Container(
                            alignment: Alignment.center,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: pageTheme.bgColor,
                                shape: BoxShape.circle,
                              ),
                              padding: EdgeInsets.all(5),
                              child: _shouldReloadMain ? CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(pageTheme.fontGrey),
                                strokeWidth: 2,
                              ) : CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(pageTheme.fontGrey),
                                strokeWidth: 2,
                                value: (_mainLVLoaderTop/_reloadHeight),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ), //reload cue control
                ],
              ),
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
        Navigator.of(_pageContext).pop();
        return false;
      },
    );
  }//route's build method

  StreamController _pageContentAvailNotifier= StreamController.broadcast();
  StreamController _mediaAvailNotifier= StreamController.broadcast();
  StreamController _headNewsPageChangeNotifier= StreamController.broadcast();
  PageController _headNewsPageCtr=PageController();
  dispose(){
    _pageContentAvailNotifier.close();
    _mediaAvailNotifier.close();
    _headNewsPageChangeNotifier.close();
    _headNewsPageCtr.dispose();
    _mainLVCtr.dispose();
    _mainReloaderCtr.close();
    super.dispose();
  }//route's dispose method
}