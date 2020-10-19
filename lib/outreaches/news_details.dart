import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:http/http.dart' as http;
import 'package:cached_video_player/cached_video_player.dart';
import 'package:flutter_xlider/flutter_xlider.dart';

import '../kcache_mgr.dart';
import '../globals.dart' as globals;
import 'theme_data.dart' as pageTheme;

class NewsDetails extends StatefulWidget{
  _NewsDetails createState(){
    return _NewsDetails();
  }
  final String newsID;
  NewsDetails(this.newsID);
}

class _NewsDetails extends State<NewsDetails>{
  @override
  initState(){
    initCacheMgr();
    addLVEvents();
    super.initState();
  }//route's init state

  double _scrollTop=0;
  addLVEvents(){
    _mainLVCtr.addListener(() {
      _scrollTop=_mainLVCtr.position.pixels;
      _floatingHeaderPosChangeNotifier.add("kjut");
    });
  }//add main Listview events

  KjutCacheMgr _kjutCacheMgr= KjutCacheMgr();
  Map _availCache=Map();
  initCacheMgr()async{
    _kjutCacheMgr.initMgr();
    _availCache= await _kjutCacheMgr.listAvailableCache();
    fetchPageData();
  }//init cache manager

  int _curHeaderSlide=0;
  initHeaderPVCtrEvent(){
    _headerPVCtr.addListener(() {
      double _curLocPage=_headerPVCtr.page;
      if(_curLocPage.floor() == _curLocPage){
        _curHeaderSlide= _curLocPage.toInt();
        _headerSlideChangeNotifier.add("kjut");
      }
    });
  }//init header page view ctr events

  List _newsRows= List();
  Map _newsHead= Map();
  fetchPageData()async{
    try{
      http.Response _resp= await http.post(
          globals.globBaseNewsAPI + "?process_as=fetch_news_details",
          body: {
            "user_id": globals.userId,
            "news_id" : widget.newsID
          }
      );
      if(_resp.statusCode == 200){
        var _respObj= jsonDecode(_resp.body);
        _newsHead= _respObj["head"];
        _newsRows= _respObj["body"];
        if(!_pageContentAvailNotifier.isClosed){
          resetVPlayers();
          _pageContentAvailNotifier.add("kjut");
        }
      }
    }
    catch(ex){
      if(!_pageContentAvailNotifier.isClosed){
        _newsRows.add({
          "error": "nointernet"
        });
        _pageContentAvailNotifier.add("kjut");
      }
    }
  }//fetchpagedata

  Map<String, CachedVideoPlayerController> _vplayers=Map<String, CachedVideoPlayerController>();
  Map<String, Map> _playerPPT= Map<String, Map>();
  StreamController _playPauseEventNotifier= StreamController.broadcast();
  resetVPlayers()async{
    _vplayers.forEach((elKey, el)async{
      await el.dispose();
    });
    _vplayers= Map<String, CachedVideoPlayerController>();
  }//reset vplayers

  initPlayerPPT(String _videoID){
    if(!_playerPPT.containsKey(_videoID)){
      _playerPPT[_videoID]= {
        "hideIcon": false,
        "isPlaying": false,
        "duration": 100,
        "position": 0
      };
    }
  }
  showHidePlayIcon(String _videoID){
    if(_playerPPT[_videoID]["hideIcon"]){
      _playerPPT[_videoID]["hideIcon"]=false;
      Future.delayed(
          Duration(milliseconds: 1500),
              (){
            if(_playerPPT[_videoID].containsKey("isPlaying") && _playerPPT[_videoID]["isPlaying"]){
              _playerPPT[_videoID]["hideIcon"]=true;
              if(!_playPauseEventNotifier.isClosed){
                _playPauseEventNotifier.add("kjut");
              }
            }
          }
      );
    }
    else {
      _playerPPT[_videoID]["hideIcon"]=true;
    }
    _playPauseEventNotifier.add("kjut");
  }

  double _floatingHeaderTop=0;
  Size _screenSize;
  String _deviceTheme="";
  @override
  Widget build(BuildContext context) {
    _screenSize=MediaQuery.of(context).size;
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
                  child: StreamBuilder(
                    stream: _pageContentAvailNotifier.stream,
                    builder: (BuildContext _ctx, AsyncSnapshot _mainshot){
                      if(_newsRows.length >0){
                        Map _firstMap= _newsRows[0];
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
                        return Container(
                          width: _screenSize.width,
                          height: _screenSize.height,
                          child: ListView.builder(
                              controller: _mainLVCtr,
                              cacheExtent: _screenSize.height * 5,
                              physics: BouncingScrollPhysics(),
                              itemCount: _newsRows.length + 1,
                              itemBuilder: (BuildContext _ctx, int _itemIndex){
                                if(_itemIndex == 0){
                                  String _mediaPath= _newsHead["media_path"];
                                  double _ar= double.tryParse(_newsHead["ar"]);
                                  double _mediaHeight= _screenSize.width/_ar;
                                  String _newsDate= _newsHead["news_date"];
                                  String _dpStr= _newsHead["dp"];
                                  List<String> _dps= _dpStr.split(",");
                                  List<Widget> _pageChildren= List<Widget>();
                                  int _dpCount= _dps.length;
                                  for(int _k=0; _k<_dpCount; _k++){
                                    String _locMediaPath=_mediaPath + "/" + _dps[_k];
                                    if(!_availCache.containsKey(_locMediaPath)){
                                      _kjutCacheMgr.downloadFile(_locMediaPath, DateTime.now().add(Duration(days: 7)));
                                    }
                                    _pageChildren.add(
                                        Container(
                                          width: _screenSize.width,
                                          height: _mediaHeight,
                                          decoration: BoxDecoration(
                                              image: DecorationImage(
                                                  image: _availCache.containsKey(_locMediaPath) ? FileImage(File(_availCache[_locMediaPath])) : NetworkImage(_locMediaPath),
                                                fit: BoxFit.cover
                                              )
                                          ),
                                        )
                                    );
                                  }
                                  if(_dpCount>1){
                                    initHeaderPVCtrEvent();
                                  }
                                  return Container(
                                    margin: EdgeInsets.only(bottom: 16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          margin:EdgeInsets.only(bottom: 5, top: 16),
                                          padding: EdgeInsets.only(left: 12, right: 12),
                                          child: Text(
                                            _newsHead["title"],
                                            style: TextStyle(
                                                color: pageTheme.fontColor,
                                                fontSize: 20
                                            ),
                                          ),
                                        ),//news title

                                        Container(
                                          padding:EdgeInsets.only(left: 12, right: 12),
                                          margin:EdgeInsets.only(bottom: 16),
                                          child: Text(
                                            _newsDate,
                                            style: TextStyle(
                                                color: pageTheme.fontColor2,
                                                fontSize: 13
                                            ),
                                          ),
                                        ),//news date

                                        Container(
                                          child: Stack(
                                            children: [
                                              Container(
                                                width: _screenSize.width,
                                                height: _mediaHeight,
                                                child: PageView(
                                                  controller: _headerPVCtr,
                                                  physics: BouncingScrollPhysics(),
                                                  children: _pageChildren,
                                                ),
                                              ),
                                              Positioned(
                                                left: 0, bottom: 12,
                                                child: _dpCount>1 ? Container(
                                                  width: _screenSize.width,
                                                  child: StreamBuilder(
                                                    stream:_headerSlideChangeNotifier.stream,
                                                    builder: (BuildContext _ctx, AsyncSnapshot _hslideshot){
                                                      List<Widget> _pvchildren= List<Widget>();
                                                      for(int _j=0; _j<_dpCount; _j++){
                                                        _pvchildren.add(Container(
                                                          width: _j == _curHeaderSlide ? 9 : 5, height: _j == _curHeaderSlide ? 9 : 5,
                                                          margin: EdgeInsets.only(right: 5),
                                                          decoration: BoxDecoration(
                                                              color: _j == _curHeaderSlide ? Colors.white : Color.fromRGBO(200, 200, 200, 1)
                                                          ),
                                                        ));
                                                      }
                                                      return Container(
                                                        alignment: Alignment.center,
                                                        child: Container(
                                                          decoration: BoxDecoration(
                                                              color: Color.fromRGBO(20, 20, 20, .4)
                                                          ),
                                                          padding: EdgeInsets.only(left: 7, right: 7, top: 5, bottom: 5),
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: _pvchildren,
                                                            mainAxisSize: MainAxisSize.min,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ): Container(),
                                              )
                                            ],
                                          ),
                                        )//media slide
                                      ],
                                    ),
                                  );
                                }
                                Map _rowMap= _newsRows[_itemIndex - 1];
                                String _blockID= _rowMap["id"];
                                if(_rowMap["type"] == "TEXT"){
                                  return Container(
                                    padding: EdgeInsets.only(left: 12, right: 12),
                                    margin: EdgeInsets.only(bottom: 24),
                                    child: Text(
                                      _rowMap["content"],
                                      style: TextStyle(
                                          color: pageTheme.fontColor,
                                          fontSize: 16,
                                          fontFamily: "courgette",
                                          height: 1.4
                                      ),
                                    ),
                                  );
                                }
                                else if(_rowMap["type"] == "MEDIA"){
                                  String _dpString= _rowMap["content"];
                                  List<String> _dps= _dpString.split(",");
                                  double _ar= double.tryParse(_rowMap["ar"]);
                                  double _mediaHeight=_screenSize.width/_ar;
                                  List<Widget> _pageChildren= List<Widget>();
                                  String _mediaPath= _rowMap["media_path"];
                                  int _dpCount= _dps.length;
                                  for(int _j=0; _j<_dpCount; _j++){
                                    String _videoID= "$_blockID-$_j";
                                    String _locMediaPath=_mediaPath + "/" + _dps[_j];
                                    if(_locMediaPath.endsWith("mp4")){
                                      initPlayerPPT(_videoID);
                                      if(_availCache.containsKey(_locMediaPath)){
                                        _vplayers[_videoID]=CachedVideoPlayerController.file(File(_locMediaPath));
                                      }
                                      else{
                                        _vplayers[_videoID]=CachedVideoPlayerController.network(_locMediaPath);
                                      }
                                      CachedVideoPlayerController _locVplayer= _vplayers[_videoID];

                                      _locVplayer.initialize().then((value) {
                                        _locVplayer.setLooping(true);
                                        _playerPPT[_videoID]["duration"]= _locVplayer.value.duration.inSeconds;
                                        _locVplayer.addListener(() {
                                          if(_locVplayer.value.isPlaying){
                                            _playerPPT[_videoID]["position"]= _locVplayer.value.position.inSeconds;
                                            _playerPosChangeNotifier.add(_videoID);
                                          }
                                        });
                                      });
                                      _pageChildren.add(Container(
                                        child: Stack(
                                          children: [
                                            Container(
                                              width: _screenSize.width,
                                              height: _mediaHeight,
                                              alignment: Alignment.center,
                                              child: CachedVideoPlayer(
                                                  _locVplayer
                                              ),
                                            ),
                                            StreamBuilder(
                                              stream: _playPauseEventNotifier.stream,
                                              builder: (BuildContext _ctx, AsyncSnapshot _pausePlayShot){
                                                return AnimatedOpacity(
                                                  opacity: (_playerPPT.containsKey(_videoID) && _playerPPT[_videoID].containsKey("hideIcon") && _playerPPT[_videoID]["hideIcon"]) ? 0 : 1,
                                                  duration: Duration(milliseconds: 300),
                                                  child: GestureDetector(
                                                    onTap: (){
                                                      showHidePlayIcon(_videoID);
                                                    },
                                                    child: Container(
                                                      width: _screenSize.width,
                                                      height: _mediaHeight,
                                                      color: Color.fromRGBO(20, 20, 20, .2),
                                                      alignment: Alignment.center,
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                            color: Color.fromRGBO(50, 50, 50, .6),
                                                            shape: BoxShape.circle
                                                        ),
                                                        padding: EdgeInsets.all(16),
                                                        child: Material(
                                                          color: Colors.transparent,
                                                          child: InkWell(
                                                            onTap: (){
                                                              if(_locVplayer.value.isPlaying){
                                                                _locVplayer.pause();
                                                                _playerPPT[_videoID]["isPlaying"]=false;
                                                                _playerPPT[_videoID]["hideIcon"]=false;
                                                              }
                                                              else{
                                                                _locVplayer.play();
                                                                _playerPPT[_videoID]["isPlaying"]=true;
                                                                _playerPPT[_videoID]["hideIcon"]=false;
                                                                Future.delayed(
                                                                    Duration(milliseconds: 2000),
                                                                        (){
                                                                      if(_playerPPT[_videoID]["isPlaying"] && _playPauseEventNotifier.isClosed == false){
                                                                        _playerPPT[_videoID]["hideIcon"]=true;
                                                                        _playPauseEventNotifier.add("kjut");
                                                                      }
                                                                    }
                                                                );
                                                              }
                                                              //showHidePlayIcon(_videoID);
                                                              _playPauseEventNotifier.add("kjut");
                                                            },
                                                            highlightColor: Colors.transparent,
                                                            child: Ink(
                                                              child: Icon(
                                                                (_playerPPT.containsKey(_videoID) && _playerPPT[_videoID].containsKey("isPlaying") && _playerPPT[_videoID]["isPlaying"]) ? FlutterIcons.pause_mco : FlutterIcons.play_mco,
                                                                color: Color.fromRGBO(245, 245, 245, 1),
                                                                size: 36,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),//play pause displayer
                                            Positioned(
                                              width: _screenSize.width,
                                              left: 0, bottom: 16,
                                              child: Container(
                                                padding: EdgeInsets.only(left: 5, right: 5),
                                                child: StreamBuilder(
                                                  stream: _playerPosChangeNotifier.stream,
                                                  builder: (BuildContext _ctx, AsyncSnapshot _posSliderShot){
                                                    if(_playerPPT.containsKey(_videoID)){
                                                      return Container(
                                                        child: FlutterSlider(
                                                          values: [_playerPPT[_videoID]["position"]/1],
                                                          min: 0,
                                                          max: _playerPPT[_videoID]["duration"]/1,
                                                          handler: FlutterSliderHandler(
                                                              decoration: BoxDecoration(
                                                                  color: Colors.white
                                                              ),
                                                              child: Container()
                                                          ),
                                                          handlerWidth: 12,
                                                          handlerHeight: 12,
                                                          onDragCompleted: (int _curHandle, _lv, _uv){
                                                            double _lvVal=_lv;
                                                            int _lvValInt= _lvVal.toInt();
                                                            if(_locVplayer.value.initialized){
                                                              _locVplayer.seekTo(Duration(seconds: _lvValInt));
                                                            }
                                                          },
                                                        ),
                                                      );
                                                    }
                                                    return Container();
                                                  },
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                      ));
                                    }
                                    else{
                                      _pageChildren.add(Container(
                                        width: _screenSize.width,
                                        height: _mediaHeight,
                                        decoration: BoxDecoration(
                                            image: DecorationImage(
                                                image: _availCache.containsKey(_locMediaPath) ?
                                                FileImage(File(_availCache[_locMediaPath])): NetworkImage(_locMediaPath),
                                                fit: BoxFit.cover
                                            )
                                        ),
                                      ));
                                    }
                                  }
                                  _innerBlockPageCtrs[_blockID]=PageController();
                                  PageController _locPageCtr= _innerBlockPageCtrs[_blockID];
                                  _blockCurPages[_blockID]=0;
                                  _locPageCtr.addListener(() {
                                    double _locBlockPage= _locPageCtr.page;
                                    if(_locBlockPage.floor() == _locBlockPage){
                                      int _locBlockPageInt= _locBlockPage.toInt();
                                      String _storeCurrPage=_blockCurPages[_blockID].toString();
                                      _blockCurPages[_blockID]= _locBlockPageInt;
                                      _blockPagesChangedNotifier.add(_blockID);
                                      String _pageIDStr="$_blockID-$_storeCurrPage";
                                      if(_vplayers.containsKey(_pageIDStr)){
                                        if(_vplayers[_pageIDStr].value.isPlaying){
                                          _vplayers[_pageIDStr].pause();
                                          if(_playerPPT.containsKey(_pageIDStr)){
                                            _playerPPT[_pageIDStr]["hideIcon"]=false;
                                            _playerPPT[_pageIDStr]["isPlaying"]=false;
                                            _playPauseEventNotifier.add("kjut");
                                          }
                                        }
                                      }
                                    }
                                  });
                                  return Container(
                                    margin: EdgeInsets.only(bottom: 16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: _screenSize.width,
                                          height: _mediaHeight,
                                          child: PageView(
                                            controller: _locPageCtr,
                                            physics: BouncingScrollPhysics(),
                                            children: _pageChildren,
                                          ),
                                        ),//the media
                                        StreamBuilder(
                                          stream: _blockPagesChangedNotifier.stream,
                                          builder: (BuildContext _ctx, AsyncSnapshot _blockpageshot){
                                            if(_dpCount>1){
                                              List<Widget> _rowChildren= List<Widget>();
                                              for(int _j=0; _j<_dpCount; _j++){
                                                _rowChildren.add(
                                                    Container(
                                                      width: 15,
                                                      height: 3,
                                                      margin: EdgeInsets.only(right: 5),
                                                      decoration: BoxDecoration(
                                                          color: _blockCurPages[_blockID] == _j ? Colors.red : pageTheme.fontColor2
                                                      ),
                                                    )
                                                );
                                              }
                                              return Container(
                                                margin: EdgeInsets.only(top: 5),
                                                width: _screenSize.width,
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: _rowChildren,
                                                ),
                                              );
                                            }
                                            return Container();
                                          },
                                        ),//page indicator if page more than one
                                      ],
                                    ),
                                  );
                                }
                                return Container(

                                );
                              }
                          ),
                        );
                      }
                      return Container(
                        width: _screenSize.width,
                        height: _screenSize.height,
                        alignment: Alignment.center,
                        child: Container(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(pageTheme.fontColor),
                            strokeWidth: 3,
                          ),
                        ),
                      );//page loading
                    },
                  ),
                ),
                StreamBuilder(
                  stream: _floatingHeaderPosChangeNotifier.stream,
                  builder: (BuildContext _ctx, AsyncSnapshot _headershot){
                    return Positioned(
                      left: 0,
                      top: _floatingHeaderTop,
                      width: _screenSize.width,
                      child: Container(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedContainer(
                              width: _screenSize.width,
                              height: 40,
                              color: (_scrollTop > 14 && _newsRows.length>0) ? Colors.red : Colors.transparent,
                              duration: Duration(milliseconds: 400),
                            ),
                            AnimatedOpacity(
                              duration: Duration(milliseconds: 400),
                              opacity: (_scrollTop>14 && _newsRows.length>0) ? 1 : 0,
                              child: _newsRows.length>0 ? Container(
                                padding: EdgeInsets.only(left: 12, right: 12, top: 5),
                                decoration: BoxDecoration(
                                    color: pageTheme.bgColor
                                ),
                                width: _screenSize.width,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin:EdgeInsets.only(bottom: 3),
                                      child: Text(
                                        _newsHead["title"],
                                        style: TextStyle(
                                            fontSize: 20,
                                            color: pageTheme.fontColor,
                                            fontFamily: "ubuntu"
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.only(bottom: 12),
                                      child: Text(
                                        _newsHead["news_date"],
                                        style: TextStyle(
                                            color: pageTheme.fontColor2,
                                            fontSize: 13
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ): Container(),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),//floating header
              ],
            ),
          ),
          autofocus: true,
          onFocusChange: (bool _isFocused){
            if(_isFocused){
              if(MediaQuery.of(context).platformBrightness == Brightness.light){
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
        Navigator.pop(context);
        return false;
      },
    );
  }//route's build method

  Map<String, PageController> _innerBlockPageCtrs= Map<String, PageController>();
  Map<String, int> _blockCurPages= Map<String, int>();
  StreamController _blockPagesChangedNotifier= StreamController.broadcast();

  StreamController _pageContentAvailNotifier= StreamController.broadcast();
  PageController _headerPVCtr= PageController();
  StreamController _headerSlideChangeNotifier= StreamController.broadcast();
  ScrollController _mainLVCtr= ScrollController();
  StreamController _floatingHeaderPosChangeNotifier= StreamController.broadcast();
  StreamController _playerPosChangeNotifier= StreamController.broadcast();
  @override
  void dispose() {
    _pageContentAvailNotifier.close();
    _headerPVCtr.dispose();
    _headerSlideChangeNotifier.close();

    _vplayers.forEach((elKey, element) {
      element.dispose();
    });
    _playPauseEventNotifier.close();
    _mainLVCtr.dispose();
    _floatingHeaderPosChangeNotifier.close();
    _blockPagesChangedNotifier.close();
    _innerBlockPageCtrs.forEach((key, value) {
      value.dispose();
    });
    _playerPosChangeNotifier.close();
    super.dispose();
  }//route's dispose method
}