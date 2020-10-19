import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_xlider/flutter_xlider.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../kcache_mgr.dart';
import 'package:cached_video_player/cached_video_player.dart';

import './theme_data.dart' as pageTheme;
import '../dbs.dart';
import '../globals.dart' as globals;
import './index.dart';

class WatchVideo extends StatefulWidget{
  _WatchVideo createState(){
    return _WatchVideo();
  }
  final String postID;
  final String channelID;
  WatchVideo(this.postID, this.channelID);
}

class _WatchVideo extends State<WatchVideo> with SingleTickerProviderStateMixin{

  KjutCacheMgr kjutCacheMgr= KjutCacheMgr();
  Map _availCache={};
  DateTime _cacheExpireDate;
  AnimationController _likeAniCtr;
  Animation<double> _likeAni;
  @override
  void initState() {
    kjutCacheMgr.initMgr().then((value) async{
      _availCache=await kjutCacheMgr.listAvailableCache();
    });
    _cacheExpireDate=DateTime.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch + (7 * 24 * 3600 * 1000));
    _vidData=Map();
    initDir();
    fetchPosts();
    _likeAniCtr= AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );
    _likeAni= Tween(begin: 0.8, end: 1.2).animate(
        CurvedAnimation(
            parent: _likeAniCtr,
            curve: Curves.elasticOut
        ));
    _likeAniCtr.repeat(
      reverse: true,
    );
    initLVEvents();
    _pageListData=List();
    super.initState();
  }//route's init state

  List _pageListData= List();
  bool _fetchingPageContent=false;
  List _existingPids= List();
  fetchPageData()async{
    if(_fetchingPageContent) return;
    _fetchingPageContent=true;
    try{
      http.Response _resp= await http.post(
        globals.globBaseTVURL + "?process_as=fetch_tv_posts",
        body: {
          "user_id" : globals.userId,
          "start": jsonEncode(_existingPids)
        }
      );

      if(_resp.statusCode == 200){
        List _respObj= jsonDecode(_resp.body);
        _pageListData.addAll(_respObj);
        if(!_pageStreamCtr.isClosed)_pageStreamCtr.add("kjut");
        if(_respObj.length>0){
          _fetchingPageContent=false;
          int _respObjLen= _respObj.length;
          otherPageCacheDownload();
          for(int _k=0; _k<_respObjLen; _k++){
            _existingPids.add(_respObj[_k]["post_id"]);
          }
        }
      }
    }
    catch(ex){
      _pageListData.add({
        "error": "network"
      });
      _fetchingPageContent=false;
      if(!_pageStreamCtr.isClosed){
        _pageStreamCtr.add("kjut");
      }
    }
  }//fetches the remaining part of the page from the server

  double _commentLoaderTop=-50;
  bool _pointerDown=false;
  bool _shouldReload=false;
  double _reloadHeight=40;
  initLVEvents(){
    _commentLiCtr.addListener(() {
      if(!_fetchingPostComments){
        if(_commentLiCtr.position.pixels > _commentLiCtr.position.maxScrollExtent - 300){
          fetchComments("post", widget.postID, _postComments.length.toString(), false);
        }
      }

      //reload event for the comment list
      if(_commentLiCtr.position.pixels<0){
        _commentLoaderTop= (-1 * _commentLiCtr.position.pixels) - 25;
        if(_pointerDown == false && _commentLoaderTop>=_reloadHeight-3){
          //the -3 subtracted from the the reload height is just an allowance value to allow basic delay from the user
          _shouldReload=true;
          _postComments=List();
          _replyComments=Map();
          fetchComments("post", widget.postID, _postComments.length.toString(), true);
          Future.delayed(
            Duration(seconds: 2),
              (){
              _commentLoaderTop=-50;
              _shouldReload=false;
              if(!_commentReloadCtr.isClosed)_commentReloadCtr.add("kjut");
              }
          );
        }
        if(!_commentReloadCtr.isClosed)_commentReloadCtr.add("kjut");
      }



      //event for the main list
      _mainListCtr.addListener(() {
        if(!_fetchingPageContent){
          if(_mainListCtr.position.pixels> (_mainListCtr.position.maxScrollExtent - (_screenSize.height * 3))){
            fetchPageData();
          }
        }
      });
    });
  }//initializes the list view events

  String _postUserID="";//used to prevent the user from subscribing to his channel

  String _userDP="";
  Directory _appDir;
  initDir()async{
    _appDir= await getApplicationDocumentsDirectory();
    Database _con= await _dbTables.tvProfile();
    _con.rawQuery("select dp from profile where status='ACTIVE'").then((_resp) {
      if(_resp.length == 1){
        _userDP= _resp[0]["dp"];
        if(!_showCommentGestureTapNotifier.isClosed)_showCommentGestureTapNotifier.add("kjut");
      }
    });
  }

  kCacheDownload(){
    if(_vidData.containsKey("post_path")){
      String _postPath= _vidData["post_path"];
      kjutCacheMgr.downloadFile(_postPath, _cacheExpireDate).then((value)async{
        _availCache=await kjutCacheMgr.listAvailableCache();
        if(!_vplayerCacheAvailNotifier.isClosed){
          _vplayerCacheAvailNotifier.add("kjut");
        }
      });
      String _cdpPath= _vidData["channel_dp"];
      kjutCacheMgr.downloadFile(_cdpPath, _cacheExpireDate).then((value)async{
        _availCache=await kjutCacheMgr.listAvailableCache();
        if(!_playerChannelDPAvailCtr.isClosed){
          _playerChannelDPAvailCtr.add("kjut");
        }
      });
    }
  }

  otherPageCacheDownload(){
    int _kount= _pageListData.length;
    for(int _k=0; _k<_kount; _k++){
      String _posterPath=_pageListData[_k]["poster_path"];
      kjutCacheMgr.downloadFile(_posterPath, _cacheExpireDate).then((value) async{
        _availCache=await kjutCacheMgr.listAvailableCache();
        if(!_pagePosterAvailCtr.isClosed) _pagePosterAvailCtr.add("kjut");
      });
      String _cdpPath=_pageListData[_k]["channel_dp"];
      if(_cdpPath.length>1){
        kjutCacheMgr.downloadFile(_cdpPath, _cacheExpireDate).then((value) async{
          _availCache=await kjutCacheMgr.listAvailableCache();
          if(!_ochannelDPAvailCtr.isClosed) _ochannelDPAvailCtr.add("kjut");
        });
      }
    }
  }
  
  DBTables _dbTables=DBTables();
  Map _vidData= Map();
  bool _showMore=false;
  bool _iLike=false;
  String _likeCount="0";
  String _viewCount="0";
  String _postTime="";
  String _subCount="0";
  bool _isub=false;
  String _commentCount="0";
  String _lastComment="";
  String _lastCommentDP="";
  fetchPosts()async{
    Database _con= await _dbTables.tvProfile();
    var _result= await _con.rawQuery("select * from tv_posts where post_id=?", [widget.postID]);
    if(_result.length>0){
      _vidData= _result[0];
      kCacheDownload();
      _viewCount= _vidData["views"];
      _postTime=_vidData["post_time"];
      _postUserID=_vidData["user_id"];
      if(!_vidAvailableCtr.isClosed)_vidAvailableCtr.add("kjut");
      registerView();
    }
    else{
      try{
        http.Response _resp= await http.post(
          globals.globBaseTVURL + "?process_as=fetch_single_tv_post",
          body: {
            "post_id": widget.postID
          }
        );
        if(_resp.statusCode == 200){
          var _respObj= jsonDecode(_resp.body);
          _vidData= _respObj[0];
          kCacheDownload();
          _viewCount= _vidData["views"];
          _postTime=_vidData["post_time"];
          _postUserID=_vidData["user_id"];
          if(!_vidAvailableCtr.isClosed)_vidAvailableCtr.add("kjut");
          registerView();
        }
      }
      catch(ex){
        showLocalToast(
          text: "Kindly ensure that your device is properly connected to the internet",
          duration: Duration(seconds: 60)
        );
      }
    }
  }//fetch posts

  registerView()async{
    try{
      http.Response _resp= await http.post(
        globals.globBaseTVURL + "?process_as=register_tv_post_view",
        body: {
          "user_id": globals.userId,
          "post_id": widget.postID
        }
      );
      if(_resp.statusCode == 200){
        fetchPageData(); //we are calling this here because we want the current video to be exempted from the video that would be played next
        var _respObj= jsonDecode(_resp.body);
        _viewCount= _respObj["views"];
        _likeCount= _respObj["likes"];
        _postTime= _respObj["post_time"];
        _iLike = _respObj["ilike"] == "yes";

        _subCount= _respObj["sub_count"];
        _isub=_respObj["isub"] == "yes";

        _commentCount= _respObj["comment_count"];
        var _lastCommObj=_respObj["last_comment"];
        _lastComment=_lastCommObj["text"];
        _lastCommentDP=_lastCommObj["dp"];

        if(!_viewCountChangeNotifier.isClosed)_viewCountChangeNotifier.add("kjut");
        if(!_likeChangeNotifier.isClosed)_likeChangeNotifier.add("kjut");
        if(!_postTimeChangeNotifier.isClosed)_postTimeChangeNotifier.add("kjut");
        if(!_subChangeNotifier.isClosed)_subChangeNotifier.add("kjut");
        if(!_showCommentGestureTapNotifier.isClosed)_showCommentGestureTapNotifier.add("kjut");
      }
    }
    catch(ex){
      showLocalToast(
          text: "Unable to refresh content in offline mode",
          duration: Duration(seconds: 12)
      );
    }
  }//register that video has been seen and get basic updates on the video

  registerLike()async{
    try{
      //the await keyword below is necessary to help us catch error - network error
      await http.post(
        globals.globBaseTVURL + "?process_as=like_tv_post",
        body: {
          "user_id": globals.userId,
          "post_id": widget.postID
        }
      );
    }
    catch(ex){
      showLocalToast(
          text: "Can't like in offline mode",
          duration: Duration(seconds: 12)
      );
    }
  }//like post

  channelSub()async{
    try{
      //the await keyword below is necessary to help us catch error - network error
      await http.post(
          globals.globBaseTVURL + "?process_as=sub4channel",
          body: {
            "user_id": globals.userId,
            "channel_id": widget.channelID
          }
      );
    }
    catch(ex){
      showLocalToast(
          text: "Can't subscribe in offline mode",
          duration: Duration(seconds: 12)
      );
    }
  }//subscribe to channel

  showComment(){
    _commentBoxHeight=_screenSize.height * .6;
    if(_playerKey.currentContext!=null){
      RenderBox _rb=_playerKey.currentContext.findRenderObject();
      Size _playersize= _rb.size;
      _commentBoxHeight= _screenSize.height - (_playersize.height + 16);
    }
    _showComments=true;
    if(!_showCommentCtr.isClosed)_showCommentCtr.add("kjut");
    fetchComments("post", widget.postID, "0", true);
  }//to pop out comment box

  hideComment(){
    _commentBoxHeight=0;
    _showComments=false;
    _showCommentCtr.add("kjut");
  }//hides the comment pop up

  String _replyTo="";
  String _replyUsername="";
  postComment()async{
    try{
      if(_commentCtr.text!=""){
        String _commentTxt= _commentCtr.text + "";
        _commentCtr.text="";
        String _locReplyTo= "$_replyTo";
        _replyTo="";
        _replyUsername="";
        _showReplyToCtr.add("kjut");
        http.Response _resp= await http.post(
          globals.globBaseTVURL + "?process_as=post_tv_comment",
          body: {
            "user_id": globals.userId,
            "post_id": widget.postID,
            "comment": _commentTxt,
            "reply_to": _locReplyTo
          }
        );
        if(_resp.statusCode == 200){
          if(_locReplyTo==""){
            fetchComments("post", widget.postID, "0", true);
          }
        }
      }
    }
    catch(ex){
      showLocalToast(
        text: "Comment can not be made offline",
        duration: Duration(seconds: 7)
      );
    }
  }//post comments

  List _postComments= List();
  Map _replyComments= Map();
  Map _commLikeCount=Map();
  Map _commILike=Map();
  String _fetchingRComment="";
  bool _fetchingPostComments=false;
  fetchComments(String _fetchBy, String _val, String _startFrom, bool _reset)async{
    if(_fetchingPostComments && _fetchBy == "post") return;
    if(_fetchingRComment != "" && _fetchBy=="reply") return;
    try{
      if(_fetchBy == "reply") {
        _fetchingRComment=_val;
        _viewReplyCtr.add("kjut");
      }
      else{
        _fetchingPostComments=true;
      }
      http.Response _resp= await http.post(
        globals.globBaseTVURL + "?process_as=fetch_tv_comments",
        body: {
          "fetch_by" : _fetchBy,
          "criteria_val" : _val,
          "start_from" : _startFrom,
          "user_id": globals.userId
        }
      );
      if(_resp.statusCode == 200){
        if(_reset && _fetchBy == "post"){
          _postComments=List();
          var _respObj=jsonDecode(_resp.body);
          _postComments= _respObj;
          _postCommentsLoadedNotifier.add("kjut");
          if(_respObj.length>0){
            _fetchingPostComments=false;
          }
        }
        else if(_reset ==false && _fetchBy == "post"){
          var _respObj=jsonDecode(_resp.body);
          _postComments.addAll(_respObj);
          _postCommentsLoadedNotifier.add("kjut");
          if(_respObj.length>0){
            _fetchingPostComments=false;
          }
        }
        else if(_reset && _fetchBy == "reply"){
          _replyComments["$_val"]=jsonDecode(_resp.body);
          _fetchingRComment="";
          _viewReplyCtr.add("kjut");
        }
        else if(_reset ==false && _fetchBy == "reply"){
          _replyComments["$_val"].addAll(jsonDecode(_resp.body));
          _fetchingRComment="";
          _viewReplyCtr.add("kjut");
        }
      }
    }
    catch(ex){
      
    }
  }//fetch comments

  likeComment(String _commentId)async{
    http.post(
      globals.globBaseTVURL + "?process_as=like_tv_comment",
      body: {
        "user_id": globals.userId,
        "comment_id": _commentId
      }
    );
  }//like comment

  final _playerKey= GlobalKey();
  BuildContext _pageContext;
  Size _screenSize;
  String _deviceTheme="";
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize=MediaQuery.of(_pageContext).size;
    _toastTop= _screenSize.height * .6;
    return WillPopScope(
      child: Scaffold(
        backgroundColor: pageTheme.bgColor,
        floatingActionButton: FloatingActionButton(
          onPressed: (){
            Navigator.of(_pageContext).push(
              MaterialPageRoute(
                builder: (BuildContext _ctx){
                  return CamTV();
                }
              )
            );
          },
          child: Icon(
            FlutterIcons.home_faw
          ),
          backgroundColor: pageTheme.bgColorVar1,
          foregroundColor: pageTheme.fontGrey,
          elevation: 2,
        ),
        body: FocusScope(
          child: Container(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  child: StreamBuilder(
                    stream: _pageStreamCtr.stream,
                    builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                      return ListView.builder(
                        controller:_mainListCtr,
                          itemCount: _pageListData.length + 1,
                          physics: BouncingScrollPhysics(),
                          cacheExtent: _screenSize.height * 5,
                          itemBuilder: (BuildContext _ctx, int _itemIndex){
                            if(_itemIndex == 0){
                              return Container(
                                child: Column(
                                  children: [
                                    Container(
                                      child: StreamBuilder(
                                        stream: _vidAvailableCtr.stream,
                                        builder: (BuildContext _ctx, _vidAvailShot){
                                          if(_vidData.containsKey("post_path")){
                                            String _vidurl=_vidData["post_path"];
                                            double _vidHeight= _screenSize.width/double.tryParse(_vidData["ar"]);
                                            String _locchanneldp=_vidData["channel_dp"];
                                            resetVplayer();
                                            if(_availCache.containsKey(_vidurl)){
                                              _vplayers.add(CachedVideoPlayerController.file(File(_availCache[_vidurl])));
                                              _vplayers.last.initialize().then((value){
                                                initVplayerEvent();
                                                _vplayers.last.seekTo(Duration(seconds: _curPlayerPos));
                                              });
                                            }
                                            else{
                                              _vplayers.add(CachedVideoPlayerController.network(_vidurl));
                                              _vplayers.last.initialize().then((value){
                                                initVplayerEvent();
                                              });
                                            }

                                            return Container(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    key:_playerKey,
                                                    child: Stack(
                                                      children: [
                                                        Container(
                                                          decoration:BoxDecoration(
                                                              color: Color.fromRGBO(24, 24, 24, 1)
                                                          ),
                                                          child: StreamBuilder(
                                                            stream:_vplayerCacheAvailNotifier.stream,
                                                            builder: (BuildContext _ctx, AsyncSnapshot _cacheShot){
                                                              return Container(
                                                                width: _screenSize.width,
                                                                height: _vidHeight,
                                                                child: CachedVideoPlayer(
                                                                    _vplayers.last
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ),//video player displayer
                                                        StreamBuilder(
                                                          stream:_playerPosChangedNotifier.stream,
                                                          builder: (BuildContext _ctx, AsyncSnapshot _bufferShot){
                                                            return Positioned(
                                                              right: 12, top: 12,
                                                              child: Opacity(
                                                                opacity: (_isBuffering || _curPlayerPos == 0) ? 1 : 0,
                                                                child: Container(
                                                                  width: 16,
                                                                  height: 16,
                                                                  alignment: Alignment.center,
                                                                  child: CircularProgressIndicator(
                                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                                                                    strokeWidth: 2,
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),//stream buffer notifier
                                                        StreamBuilder(
                                                          stream:_ctrTapNotifier.stream,
                                                          builder: (BuildContext _ctx, AsyncSnapshot _ctrShot){
                                                            return Positioned.fill(
                                                                child: InkWell(
                                                                  onTap: (){
                                                                    _playerCtrOpacity= _playerCtrOpacity == 0 ? 1 : 0;
                                                                    _ctrTapNotifier.add("kjut");
                                                                  },
                                                                  child: AnimatedOpacity(
                                                                    opacity: _playerCtrOpacity,
                                                                    onEnd: (){
                                                                      Future.delayed(
                                                                          Duration(milliseconds: 2000),
                                                                              (){
                                                                            if(_playerCtrOpacity == 1 && _isplaying){
                                                                              _playerCtrOpacity=0;
                                                                              _ctrTapNotifier.add("kjut");
                                                                            }
                                                                          }
                                                                      );
                                                                    },
                                                                    duration: Duration(
                                                                        milliseconds: 450
                                                                    ),
                                                                    child: Container(
                                                                      decoration: BoxDecoration(
                                                                          color: Color.fromRGBO(48, 48, 48, .2)
                                                                      ),
                                                                      width: _screenSize.width,
                                                                      height: _vidHeight,
                                                                      child: Stack(
                                                                        fit: StackFit.expand,
                                                                        children: [
                                                                          Positioned(
                                                                            width: _screenSize.width,
                                                                            top: (_vidHeight * .5) - 12,
                                                                            child: Container(
                                                                              alignment: Alignment.center,
                                                                              child: Material(
                                                                                color: Colors.transparent,
                                                                                child: InkWell(
                                                                                  onTap: (){
                                                                                    if(_isplaying){
                                                                                      _vplayers.last.pause();
                                                                                      _isplaying=false;
                                                                                      _playerCtrOpacity=1;
                                                                                      _ctrTapNotifier.add("kjut");
                                                                                    }
                                                                                    else{
                                                                                      _isplaying=true;
                                                                                      _vplayers.last.play();
                                                                                      Future.delayed(
                                                                                          Duration(milliseconds: 750),
                                                                                              (){
                                                                                            _playerCtrOpacity=0;
                                                                                            _ctrTapNotifier.add("kjut");
                                                                                          }
                                                                                      );
                                                                                    }
                                                                                  },
                                                                                  child: Ink(
                                                                                    child: _isplaying ? Icon(
                                                                                      FlutterIcons.pause_faw5s,
                                                                                      size: 28,
                                                                                      color: Color.fromRGBO(245, 245, 245, 1),
                                                                                    ):Icon(
                                                                                      FlutterIcons.play_faw5s,
                                                                                      size: 28,
                                                                                      color: Color.fromRGBO(245, 245, 245, 1),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ), //play pause button
                                                                          Positioned(
                                                                            left: 16,
                                                                            bottom: 32,
                                                                            child: Container(
                                                                              child: Text(
                                                                                globals.convSecToHMS(_curPlayerPos) + " / " + globals.convSecToHMS(_curPlayerduration),
                                                                                style: TextStyle(
                                                                                    color: Colors.white,
                                                                                    fontSize: 12
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ),//player time
                                                                          Positioned(
                                                                            right: 16,bottom: 32,
                                                                            child: Material(
                                                                              color: Colors.transparent,
                                                                              child: InkWell(
                                                                                child: Ink(
                                                                                  child: Icon(
                                                                                    FlutterIcons.expand_faw5s,
                                                                                    color: Color.fromRGBO(245, 245, 245, 1),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ),//expand btn
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                )
                                                            );
                                                          },
                                                        ),//basic player controls like play-pause, expand, time
                                                        Positioned(
                                                          bottom: 3,
                                                          left: 0,
                                                          width: _screenSize.width,
                                                          child: Container(
                                                            child: StreamBuilder(
                                                              stream:_playerPosChangedNotifier.stream,
                                                              builder: (BuildContext _ctx, AsyncSnapshot _timelineShot){
                                                                return Container(
                                                                  width: _screenSize.width,
                                                                  padding: EdgeInsets.only(left: 7, right: 7),
                                                                  child: FlutterSlider(
                                                                    rangeSlider: false,
                                                                    values: [_curPlayerPos/1],
                                                                    max: _curPlayerduration/1,
                                                                    min: 0,
                                                                    handlerWidth: 12,
                                                                    handlerHeight: 12,
                                                                    handler: FlutterSliderHandler(
                                                                        child: Container()
                                                                    ),
                                                                    onDragCompleted: (int _dragHandler, _lowerVal, _upperVal){
                                                                      double _lowervalu=_lowerVal;
                                                                      _vplayers.last.seekTo(Duration(seconds: _lowervalu.toInt()));
                                                                    },
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                        ),//player timeline
                                                        StreamBuilder(
                                                          stream:_playerPosChangedNotifier.stream,
                                                          builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                                            if(_curPlayerPos == 0){
                                                              return Positioned.fill(
                                                                child: Container(
                                                                  child: FutureBuilder(
                                                                    future: kjutCacheMgr.downloadFile(_vidData["poster_path"], _cacheExpireDate),
                                                                    builder: (BuildContext _ctx, AsyncSnapshot _fuShot){
                                                                      if(_fuShot.hasData){
                                                                        return Container(
                                                                          width: _screenSize.width,
                                                                          height: _vidHeight,
                                                                          decoration: BoxDecoration(
                                                                              image: DecorationImage(
                                                                                  image: FileImage(File(_fuShot.data))
                                                                              )
                                                                          ),
                                                                        );
                                                                      }
                                                                      return Container(
                                                                        width: _screenSize.width,
                                                                        height: _vidHeight,
                                                                        decoration: BoxDecoration(
                                                                            image: DecorationImage(
                                                                                image: NetworkImage(_vidData["poster_path"])
                                                                            )
                                                                        ),
                                                                      );
                                                                    },
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                            return Positioned(
                                                              left: 0, bottom: 0,
                                                              width: 1,
                                                              child: Container(),
                                                            );
                                                          },
                                                        )
                                                      ],
                                                    ),
                                                  ),
                                                  Container(
                                                    width:_screenSize.width,
                                                    padding:EdgeInsets.only(left: 16, right: 16, top: 5, bottom: 5),
                                                    decoration: BoxDecoration(
                                                        color: pageTheme.bgColorVar1
                                                    ),
                                                    child: Text(
                                                      _vidData["title"],
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                          color: pageTheme.fontColor,
                                                          fontFamily: "ubuntu",
                                                          fontSize: 17
                                                      ),
                                                    ),
                                                  ),//post title
                                                  Container(
                                                    width:_screenSize.width,
                                                    padding: EdgeInsets.only(left: 16, right: 16),
                                                    decoration:BoxDecoration(
                                                        color: pageTheme.bgColorVar1
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Container(
                                                            child: Row(
                                                              children: [
                                                                Container(
                                                                  child: StreamBuilder(
                                                                    stream:_viewCountChangeNotifier.stream,
                                                                    builder: (BuildContext _ctx, _viewShot){
                                                                      return Text(
                                                                        globals.convertToK(int.tryParse(_viewCount)) + " views",
                                                                        style: TextStyle(
                                                                            color: pageTheme.fontGrey,
                                                                            fontSize: 12
                                                                        ),
                                                                      );
                                                                    },
                                                                  ),
                                                                ),//view count display
                                                                Container(
                                                                  margin:EdgeInsets.only(left: 7),
                                                                  child: StreamBuilder(
                                                                    stream:_postTimeChangeNotifier.stream,
                                                                    builder: (BuildContext _ctx, _viewShot){
                                                                      return Text(
                                                                        _postTime,
                                                                        style: TextStyle(
                                                                            color: pageTheme.fontGrey,
                                                                            fontSize: 12
                                                                        ),
                                                                      );
                                                                    },
                                                                  ),
                                                                ), //post time
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        Container(
                                                          alignment: Alignment.centerRight,
                                                          child: StreamBuilder(
                                                            stream:_likeChangeNotifier.stream,
                                                            builder: (BuildContext _ctx, AsyncSnapshot _likeShot){
                                                              return InkWell(
                                                                onTap: (){
                                                                  if(_iLike){
                                                                    _iLike=false;
                                                                    _likeCount= (int.tryParse(_likeCount) - 1).toString();
                                                                  }
                                                                  else{
                                                                    _iLike=true;
                                                                    _likeCount= (int.tryParse(_likeCount) + 1).toString();
                                                                  }
                                                                  _likeChangeNotifier.add("kjut");
                                                                  registerLike();
                                                                },
                                                                child: Ink(
                                                                  child: Container(
                                                                    child: Column(
                                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                                      children: [
                                                                        Container(
                                                                          margin: EdgeInsets.only(bottom: 3),
                                                                          child: _iLike ? ScaleTransition(
                                                                            scale: _likeAni,
                                                                            child: Icon(
                                                                              FlutterIcons.ios_heart_ion,
                                                                              color: pageTheme.profileIcons,
                                                                              size: 13,
                                                                            ),
                                                                          ): Icon(
                                                                            FlutterIcons.heart_evi,
                                                                            color: pageTheme.profileIcons,
                                                                            size: 13,
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          child: Text(
                                                                            globals.convertToK(int.tryParse(_likeCount)) + " likes",
                                                                            style: TextStyle(
                                                                                color: pageTheme.profileIcons,
                                                                                fontSize: 11
                                                                            ),
                                                                          ),
                                                                        )
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        )
                                                      ],
                                                    ),
                                                  ),//post views amd post time
                                                  Container(
                                                    padding:EdgeInsets.only(left:16, right:16),
                                                    margin:EdgeInsets.only(top: 3, bottom: 3),
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.center,
                                                      children: [
                                                        Container(
                                                          child: _locchanneldp.length == 1 ? Container(
                                                            alignment: Alignment.center,
                                                            child: CircleAvatar(
                                                              radius: 20,
                                                              child: Text(
                                                                _locchanneldp,
                                                                style: TextStyle(
                                                                    color: pageTheme.fontColor
                                                                ),
                                                              ),
                                                              backgroundColor: pageTheme.bgColor,
                                                            ),
                                                          )
                                                              :StreamBuilder(
                                                            stream: _playerChannelDPAvailCtr.stream,
                                                            builder: (BuildContext _ctx, AsyncSnapshot _chdpShot){
                                                              if(_availCache.containsKey(_locchanneldp)){
                                                                return Container(
                                                                  alignment: Alignment.center,
                                                                  child: CircleAvatar(
                                                                    radius: 20,
                                                                    backgroundImage: FileImage(File(_availCache[_locchanneldp])),
                                                                  ),
                                                                );
                                                              }
                                                              return Container(
                                                                alignment: Alignment.center,
                                                                child: CircleAvatar(
                                                                  radius: 20,
                                                                  backgroundImage: NetworkImage(_locchanneldp),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ),//channel dp
                                                        Expanded(
                                                          child: Container(
                                                            margin:EdgeInsets.only(left: 12, right: 12),
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Container(
                                                                  margin: EdgeInsets.only(bottom: 3),
                                                                  child: Text(
                                                                    _vidData["channel_name"],
                                                                    style: TextStyle(
                                                                        color: pageTheme.fontColor,
                                                                        fontFamily: "ubuntu"
                                                                    ),
                                                                  ),
                                                                ),//channel name
                                                                Container(
                                                                  child: StreamBuilder(
                                                                    stream:_subChangeNotifier.stream,
                                                                    builder: (BuildContext _ctx, AsyncSnapshot _subCountShot){
                                                                      return Text(
                                                                        globals.convertToK(int.tryParse(_subCount)) + " subscribers",
                                                                        style: TextStyle(
                                                                          color: pageTheme.fontGrey,
                                                                        ),
                                                                      );
                                                                    },
                                                                  ),
                                                                ),//subscriber count
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        Container(
                                                          child: StreamBuilder(
                                                            stream:_subChangeNotifier.stream,
                                                            builder: (BuildContext _ctx, AsyncSnapshot _isubshot){
                                                              if(_postUserID == globals.userId){
                                                                return Container();
                                                              }
                                                              return Material(
                                                                color: Colors.transparent,
                                                                child: InkWell(
                                                                  onTap: (){
                                                                    if(_isub){
                                                                      _isub=false;
                                                                      _subCount= (int.tryParse(_subCount) - 1).toString();
                                                                    }
                                                                    else{
                                                                      _isub=true;
                                                                      _subCount= (int.tryParse(_subCount) + 1).toString();
                                                                    }
                                                                    _subChangeNotifier.add("kjut");
                                                                    channelSub();
                                                                  },
                                                                  child: AnimatedContainer(
                                                                    duration: Duration(milliseconds: 400),
                                                                    decoration: BoxDecoration(
                                                                        color: _isub ? Color.fromRGBO(32, 32, 32, 1) : Colors.blue,
                                                                        borderRadius: BorderRadius.circular(4)
                                                                    ),
                                                                    padding: EdgeInsets.only(left: 9, right: 9, top: 7, bottom: 7),
                                                                    child: Text(
                                                                      _isub ? "UNSUBSCRIBE" : "SUBSCRIBE",
                                                                      style: TextStyle(
                                                                          color: Colors.white
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        )
                                                      ],
                                                    ),
                                                  ),//channel dp, name, subscribers and subscribe btn
                                                  Container(
                                                    child: StreamBuilder(
                                                      stream:_shorMoreCtr.stream,
                                                      builder: (BuildContext _ctx, AsyncSnapshot _viewMoreShot){
                                                        String _locPostText=_vidData["post_text"];
                                                        if(_screenSize.width<420){
                                                          if(_locPostText.length > 90 && _showMore == false){
                                                            _locPostText = _locPostText.substring(0, 90) + "...";
                                                          }
                                                        }
                                                        else{
                                                          if(_locPostText.length > 200 && _showMore==false){
                                                            _locPostText = _locPostText.substring(0, 200) + "...";
                                                          }
                                                        }
                                                        return Container(
                                                          padding: EdgeInsets.only(left: 16, right: 16),
                                                          margin: EdgeInsets.only(top: 7),
                                                          child: Material(
                                                            color: Colors.transparent,
                                                            child: InkWell(
                                                              onTap: (){
                                                                _showMore= !_showMore;
                                                                _shorMoreCtr.add("kjut");
                                                              },
                                                              child: Ink(
                                                                child: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Container(
                                                                      child: RichText(
                                                                        textScaleFactor: MediaQuery.of(_pageContext).textScaleFactor,
                                                                        text: TextSpan(
                                                                            children: globals.parseTextForLinks(_locPostText),
                                                                            style: TextStyle(
                                                                                color: pageTheme.fontGrey
                                                                            )
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    Container(
                                                                      margin: EdgeInsets.only(top: 3),
                                                                      child: _showMore ? Text(
                                                                        "Seen $_viewCount times",
                                                                        style: TextStyle(
                                                                            color: pageTheme.fontGrey,
                                                                            fontSize: 13
                                                                        ),
                                                                      ): Container(),
                                                                    ),
                                                                    Container(
                                                                      margin: EdgeInsets.only(top: 5),
                                                                      child: Text(
                                                                        _showMore ? "Show less" : "Show more",
                                                                        style: TextStyle(
                                                                            color: Colors.blue
                                                                        ),
                                                                      ),
                                                                    )
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ), //post text
                                                  StreamBuilder(
                                                    stream:_showCommentGestureTapNotifier.stream,
                                                    builder: (BuildContext _ctx, AsyncSnapshot _showCommShot){
                                                      if(_userDP != ""){
                                                        return Container(
                                                          margin: EdgeInsets.only(top: 12),
                                                          padding: EdgeInsets.only(top: 3, bottom: 3, left: 16, right: 16),
                                                          decoration: BoxDecoration(
                                                              border: Border(
                                                                  top: BorderSide(
                                                                      color: pageTheme.fontGrey
                                                                  ),
                                                                  bottom: BorderSide(
                                                                      color: pageTheme.fontGrey
                                                                  )
                                                              )
                                                          ),
                                                          child: Material(
                                                            color: Colors.transparent,
                                                            child: InkWell(
                                                              onTap: (){
                                                                showComment();
                                                              },
                                                              child: Container(
                                                                child: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Container(
                                                                      child: Row(
                                                                        crossAxisAlignment: CrossAxisAlignment.center,
                                                                        children: [
                                                                          Expanded(
                                                                            child: Container(
                                                                              child: Text(
                                                                                _lastComment=="" ? "No comments" : _commentCount + " comments",
                                                                                style: TextStyle(
                                                                                    color: pageTheme.fontGrey
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          Container(
                                                                            margin: EdgeInsets.only(left: 12),
                                                                            child: Icon(
                                                                              FlutterIcons.caret_down_faw,
                                                                              color: pageTheme.fontGrey,
                                                                            ),
                                                                          )
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    Container(
                                                                      margin: EdgeInsets.only(top: 5),
                                                                      child: Row(
                                                                        children: [
                                                                          Container(
                                                                            child: (_lastComment =="" && _userDP.length == 1) ?
                                                                            CircleAvatar(
                                                                              radius: 20,
                                                                              child: Text(
                                                                                  _userDP.toUpperCase()
                                                                              ),
                                                                            ): (_lastComment =="" && _userDP.length > 1)?
                                                                            CircleAvatar(
                                                                              radius: 20,
                                                                              backgroundImage: FileImage(File(_appDir.path + "/camtv/$_userDP")),
                                                                            ): (_lastCommentDP.length == 1) ? CircleAvatar(
                                                                              radius: 20,
                                                                              child: Text(
                                                                                  _lastCommentDP.toUpperCase()
                                                                              ),
                                                                            ): CircleAvatar(
                                                                              radius: 20,
                                                                              backgroundImage: NetworkImage(_lastCommentDP),
                                                                            ),
                                                                          ), //last comment dp
                                                                          Expanded(
                                                                            child: Container(
                                                                              margin: EdgeInsets.only(left: 12),
                                                                              child: Text(
                                                                                _lastComment=="" ? "Be the first to comment on this post" : _lastComment,
                                                                                style: TextStyle(
                                                                                    color: pageTheme.fontColor
                                                                                ),
                                                                                maxLines: 2,
                                                                                overflow: TextOverflow.ellipsis,
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
                                                          ),
                                                        );
                                                      }
                                                      return Container();
                                                    },
                                                  )
                                                ],
                                              ),
                                            );
                                          }
                                          return Container(
                                            width: _screenSize.width,
                                            height: 300,
                                            alignment: Alignment.center,
                                            child: CircularProgressIndicator(
                                              valueColor: AlwaysStoppedAnimation<Color>(pageTheme.profileIcons),
                                              strokeWidth: 2,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    _pageListData.length < 1 ? Container(
                                      width: _screenSize.width,
                                      height: 150,
                                      alignment: Alignment.center,
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(pageTheme.fontColor),
                                      ),
                                    ): Container()
                                  ],
                                ),
                              );
                            }
                            else{
                              Map _firstMap={};
                              if(_pageListData.length == 1){
                                _firstMap=_pageListData[0];
                              }
                              if(_firstMap.containsKey("error") && _firstMap["error"] == "network"){
                                return Container(
                                  padding: EdgeInsets.only(left: 24, right: 24),
                                  margin: EdgeInsets.only(top: 36),
                                  alignment: Alignment.center,
                                  child: Column(
                                    children: [
                                      Container(
                                        margin:EdgeInsets.only(bottom: 5),
                                        child: Icon(
                                          FlutterIcons.cloud_off_outline_mco,
                                          color: pageTheme.fontGrey,
                                          size: 48,
                                        ),
                                      ),
                                      Container(
                                        child: Text(
                                          "Kindly ensure that your device is properly connected to the internet",
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
                              Widget _pBlock;
                              Widget _blockMain;
                              Map _blockData=_pageListData[_itemIndex - 1];
                              String _posterPath= _blockData["poster_path"];
                              double _posterHeight= _screenSize.width/double.tryParse(_blockData["ar"]);
                              String _chdpstr= _blockData["channel_dp"];
                              String _blockPostID=_blockData["post_id"];
                              String _blockChannelID=_blockData["channel_id"];
                              String _recommendedAs= _blockData["recommended_as"];
                              Color _recomColor=Colors.blue;
                              String _friendlyRecom="";
                              if(_recommendedAs == "vip"){
                                _friendlyRecom="Cardinal";
                                _recomColor=Colors.red;
                              }
                              else if(_recommendedAs == "sub"){
                                _friendlyRecom="Subscriptions";
                                _recomColor=Colors.deepOrange;
                              }
                              else if(_recommendedAs == "interest"){
                                _friendlyRecom="Shared interest";
                                _recomColor=Colors.green;
                              }
                              else if(_recommendedAs == "other channel vids"){
                                _friendlyRecom="Might like";
                              }
                              else if(_recommendedAs == "also interest"){
                                _friendlyRecom="Might interest";
                              }
                              _blockMain= Container(
                                child: Column(
                                  children: [
                                    Container(
                                      child: Stack(
                                        children: [
                                          Container(
                                            child: StreamBuilder(
                                              stream:_pagePosterAvailCtr.stream,
                                              builder: (BuildContext _ctx, AsyncSnapshot _posterShot){
                                                if(_availCache.containsKey(_posterPath)){
                                                  return Container(
                                                    width: _screenSize.width,
                                                    height: _posterHeight,
                                                    decoration: BoxDecoration(
                                                        image: DecorationImage(
                                                            image: FileImage(File(_availCache[_posterPath])),
                                                            fit: BoxFit.fitWidth
                                                        )
                                                    ),
                                                  );
                                                }
                                                return Container(
                                                  width: _screenSize.width,
                                                  height: _posterHeight,
                                                  decoration: BoxDecoration(
                                                      image: DecorationImage(
                                                          image: NetworkImage(_posterPath),
                                                          fit: BoxFit.fitWidth
                                                      )
                                                  ),
                                                );
                                              },
                                            ),
                                          ),//actual poster
                                          Positioned(
                                            right:12,
                                            bottom:12,
                                            child: Container(
                                              padding:EdgeInsets.only(left:5, right: 5, bottom:3, top:3),
                                              decoration:BoxDecoration(
                                                color: Color.fromRGBO(24, 24, 24, 1),
                                                borderRadius: BorderRadius.circular(3)
                                              ),
                                              child: Text(
                                                globals.convSecToHMS(int.tryParse(_blockData["duration"])),
                                                style: TextStyle(
                                                  color: Colors.white
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned.fill(
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  highlightColor: Colors.transparent,
                                                  onTap: (){
                                                    Navigator.of(context).push(MaterialPageRoute(
                                                      builder: (BuildContext _ctx){
                                                        return WatchVideo(_blockPostID, _blockChannelID);
                                                      }
                                                    ));
                                                  },
                                                  child: Ink(
                                                    width: _screenSize.width,
                                                    height: _posterHeight,
                                                  ),
                                                ),
                                              )
                                          )
                                        ],
                                      ),
                                    ),//poster background
                                    Container(
                                      padding:EdgeInsets.only(left: 16, right: 16),
                                      margin:EdgeInsets.only(top: 12),
                                      child: Row(children: [
                                        Container(
                                          child: _chdpstr.length == 1 ? CircleAvatar(
                                            radius: 20,
                                            child: Text(
                                              _chdpstr.toUpperCase(),
                                              style: TextStyle(
                                                color: pageTheme.fontColor
                                              ),
                                            ),
                                            backgroundColor: pageTheme.bgColorVar1,
                                          ) : StreamBuilder(
                                            stream:_ochannelDPAvailCtr.stream,
                                            builder: (BuildContext _ctx, AsyncSnapshot _dpshot){
                                              if(_availCache.containsKey(_chdpstr)){
                                                return CircleAvatar(
                                                  radius:20,
                                                  backgroundImage: FileImage(File(_availCache[_chdpstr])),
                                                );
                                              }
                                              return CircleAvatar(
                                                radius:20,
                                                backgroundImage: NetworkImage(_chdpstr),
                                              );
                                            },
                                          ),
                                        ),//channel dp
                                        Expanded(
                                          child: Container(
                                            margin: EdgeInsets.only(left: 12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                              Container(
                                                child: Text(
                                                  _blockData["title"],
                                                  style: TextStyle(
                                                    color: pageTheme.fontColor,
                                                    fontFamily: "ubuntu",
                                                    fontSize: 16
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),//post title
                                                Container(
                                                  margin:EdgeInsets.only(top: 3),
                                                  child: Text(
                                                    _blockData["channel_name"],
                                                    style: TextStyle(
                                                        color: pageTheme.profileIcons,
                                                        fontSize: 14
                                                    ),
                                                  ),
                                                ), //channel name
                                                Container(
                                                  margin: EdgeInsets.only(top: 2),
                                                  child: Wrap(
                                                    direction: Axis.horizontal,
                                                    crossAxisAlignment: WrapCrossAlignment.center,
                                                    children: [
                                                      Container(
                                                        child: Text(
                                                          globals.convertToK(int.tryParse(_blockData["likes"])) + " likes",
                                                          style: TextStyle(
                                                              color: pageTheme.profileIcons,
                                                              fontSize: 12
                                                          ),
                                                        ),
                                                      ),//like count
                                                      Container(
                                                        margin: EdgeInsets.only(left: 5, right: 5),
                                                        width: 3, height: 3,
                                                        decoration: BoxDecoration(
                                                            color: pageTheme.profileIcons,
                                                            borderRadius: BorderRadius.circular(7)
                                                        ),
                                                      ),//separator
                                                      Container(
                                                        child: Text(
                                                          globals.convertToK(int.tryParse(_blockData["views"])) + " views",
                                                          style: TextStyle(
                                                              color: pageTheme.profileIcons,
                                                              fontSize: 12
                                                          ),
                                                        ),
                                                      ),//view count
                                                      Container(
                                                        margin: EdgeInsets.only(left: 5, right: 5),
                                                        width: 3, height: 3,
                                                        decoration: BoxDecoration(
                                                            color: pageTheme.profileIcons,
                                                            borderRadius: BorderRadius.circular(7)
                                                        ),
                                                      ),//separator
                                                      Container(
                                                        child: Text(
                                                          _blockData["post_time"],
                                                          style: TextStyle(
                                                              color: pageTheme.profileIcons,
                                                              fontSize: 12
                                                          ),
                                                        ),
                                                      )//post time
                                                    ],
                                                  ),
                                                ), //likes and views, post time
                                                _recommendedAs == "" ?Container()
                                                    : Container(
                                                  margin: EdgeInsets.only(top: 3),
                                                  decoration: BoxDecoration(
                                                      color: _recomColor,
                                                      borderRadius: BorderRadius.circular(5)
                                                  ),
                                                  padding: EdgeInsets.only(left: 3, right: 3, top: 2, bottom: 2),
                                                  child: Text(
                                                    _friendlyRecom,
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10
                                                    ),
                                                  ),
                                                )
                                            ],),
                                          ),
                                        )
                                      ],),
                                    )
                                  ],
                                ),
                              );
                              if(_itemIndex == 1){
                                _pBlock=Column(
                                  children: [
                                    Container(
                                      child: Row(
                                        children: [
                                          Container(
                                            padding:EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16),
                                            child: Text(
                                              "Up next",
                                              style: TextStyle(
                                                color: pageTheme.fontColor,
                                                fontFamily: "ubuntu"
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                    _blockMain
                                  ],
                                );
                              }
                              else{
                                _pBlock= _blockMain;
                              }
                              return Container(
                                padding: EdgeInsets.only(top: 12, bottom: 12),
                                margin: EdgeInsets.only(bottom: 1),
                                child: _pBlock,
                              );
                            }
                          }
                      );
                    },
                  ),
                ),

                StreamBuilder(
                  stream: _toastCtr.stream,
                  builder: (BuildContext _ctx, _snapshot){
                    if(_showToast){
                      return AnimatedPositioned(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        left: _toastLeft, top: _toastTop,
                        child: IgnorePointer(
                          ignoring: true,
                          child: Container(
                            width: _screenSize.width,
                            alignment: Alignment.center,
                            child: TweenAnimationBuilder(
                              tween: Tween<double>(
                                  begin: 0, end: 1
                              ),
                              duration: Duration(milliseconds: 700),
                              curve: Curves.easeInOut,
                              builder: (BuildContext _ctx, double _twVal, _){
                                return Opacity(
                                  opacity: _twVal < 0 ? 0 : _twVal>1?1: _twVal,
                                  child: Container(
                                    width: (_twVal * _screenSize.width) - 96<0 ? 0 : _twVal>1 ? 1 : (_twVal * _screenSize.width) - 96,
                                    padding: EdgeInsets.only(left: 16, right: 16, top: 9, bottom: 9),
                                    decoration: BoxDecoration(
                                        color: pageTheme.toastBGColor,
                                        borderRadius: BorderRadius.circular(16)
                                    ),
                                    child: Container(

                                      child: Text(
                                        _twVal < .7 ? "" : _toastText,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: pageTheme.toastFontColor,
                                            fontSize: (_twVal * 13) + 1
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    }
                    return Container();
                  },
                ),//local toast displayer
                StreamBuilder(
                  stream: _showCommentCtr.stream,
                  builder: (BuildContext _ctx, AsyncSnapshot commentShot){
                    return AnimatedPositioned(
                      left: 0, bottom: 0,
                      width: _screenSize.width,
                      height: _commentBoxHeight,
                      duration: Duration(milliseconds: 450),
                      curve: Curves.easeInOut,
                      child: Container(
                        decoration: BoxDecoration(
                          color: pageTheme.bgColorVar1
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding:EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Container(
                                      child: Text(
                                          "$_commentCount Comments",
                                        style: TextStyle(
                                          color: pageTheme.fontColor
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    margin: EdgeInsets.only(left: 12),
                                    child: Material(
                                      color:Colors.transparent,
                                      child: InkWell(
                                        onTap: (){
                                          hideComment();
                                        },
                                        child: Ink(
                                          child: Icon(
                                            FlutterIcons.close_mco,
                                            color: pageTheme.fontGrey,
                                            size: 36,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),//comment box header
                            Container(
                              padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16),
                              decoration: BoxDecoration(
                                color: pageTheme.bgColor
                              ),
                              child: Text(
                                "Kindly comment with the mind to uplift. Choose the right words and maintain community sanity",
                                style: TextStyle(
                                  color: pageTheme.fontGrey
                                ),
                              ),
                            ),//brief note
                            Container(
                              child: StreamBuilder(
                                stream: _showCommentGestureTapNotifier.stream,
                                builder: (BuildContext _ctx, AsyncSnapshot _commShot){
                                  if(_userDP == ""){
                                    return Container();
                                  }
                                  return Container(
                                    padding: EdgeInsets.only(top: 5, bottom: 5, left: 16, right: 16),
                                    decoration: BoxDecoration(
                                      color: pageTheme.bgColor
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        StreamBuilder(
                                          stream:_showReplyToCtr.stream,
                                          builder: (BuildContext _ctx, AsyncSnapshot _showReplyShot){
                                            if(_replyUsername!=""){
                                              return Container(
                                                padding: EdgeInsets.only(left: 64),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Color.fromRGBO(62, 62, 62, 1),
                                                    borderRadius: BorderRadius.circular(9),
                                                    border: Border.all(
                                                      color: Color.fromRGBO(32, 32, 32, 1)
                                                    ),
                                                  ),
                                                  padding: EdgeInsets.only(left: 9, right: 9, top: 4, bottom: 4),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        child: Text(
                                                          _replyUsername,
                                                          style: TextStyle(
                                                              color: Colors.white,
                                                            fontSize: 11
                                                          ),
                                                        ),
                                                      ),
                                                      Container(
                                                        margin: EdgeInsets.only(left: 5),
                                                        child: Material(
                                                          color: Colors.transparent,
                                                          child: InkWell(
                                                            onTap: (){
                                                              _replyUsername="";
                                                              _replyTo="";
                                                              _showReplyToCtr.add("kjut");
                                                            },
                                                            child: Ink(
                                                              child: Icon(
                                                                FlutterIcons.close_mco,
                                                                color: Colors.white,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }
                                            return Container();
                                          },
                                        ),
                                        Container(
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Container(
                                                alignment: Alignment.center,
                                                child: _userDP.length == 1 ? CircleAvatar(
                                                  radius: 22,
                                                  child: Text(
                                                      _userDP.toUpperCase()
                                                  ),
                                                ):CircleAvatar(
                                                  radius: 22,
                                                  backgroundImage: FileImage(File(_appDir.path + "/camtv/$_userDP")),
                                                ),
                                              ),
                                              Expanded(
                                                child: Container(
                                                  padding: EdgeInsets.only(left: 16, right: 16),
                                                  child: TextField(
                                                    controller: _commentCtr,
                                                    focusNode: _commentNode,
                                                    decoration: InputDecoration(
                                                      hintText: "Comment as ${globals.fullname}",
                                                      hintStyle: TextStyle(
                                                        color: pageTheme.fontGrey,
                                                      ),
                                                      focusedBorder: InputBorder.none,
                                                      enabledBorder: InputBorder.none,
                                                    ),
                                                    minLines: 1,
                                                    maxLines: null,
                                                    style: TextStyle(
                                                        color: pageTheme.fontColor
                                                    ),
                                                    textInputAction: TextInputAction.newline,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                margin: EdgeInsets.only(left: 9),
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: (){
                                                      postComment();
                                                    },
                                                    child: Ink(
                                                      child: Icon(
                                                        FlutterIcons.send_mco,
                                                        size: 24,
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              )
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),//new comment box
                            Expanded(
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
                                        height: double.infinity,
                                        child: Container(
                                          margin: EdgeInsets.only(top: 1),
                                          alignment: Alignment.center,
                                          height: double.infinity,
                                          width: _screenSize.width,
                                          child: StreamBuilder(
                                            stream: _postCommentsLoadedNotifier.stream,
                                            builder: (BuildContext _ctx, AsyncSnapshot _postCommShot){
                                              if(_commentCount=="0"){
                                                return Container(
                                                  padding: EdgeInsets.only(left:16, right: 16, top: 16),
                                                  child: Text(
                                                    "No comments",
                                                    style: TextStyle(
                                                        color: pageTheme.fontGrey
                                                    ),
                                                  ),
                                                );
                                              }
                                              else if(_postComments.length ==0){
                                                return CircularProgressIndicator(
                                                  valueColor: AlwaysStoppedAnimation<Color>(pageTheme.profileIcons),
                                                  strokeWidth: 2,
                                                );
                                              }
                                              return ListView.builder(
                                                  controller: _commentLiCtr,
                                                  physics: BouncingScrollPhysics(),
                                                  padding: EdgeInsets.all(0),
                                                  itemCount: _postComments.length,
                                                  itemBuilder: (BuildContext _ctx, int _commIndex){
                                                    Map _targBlock=_postComments[_commIndex];
                                                    String _targudp=_targBlock["user_dp"];
                                                    return renderComments(_targudp, _targBlock);
                                                  }
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      StreamBuilder(
                                        stream: _commentReloadCtr.stream,
                                        builder: (BuildContext _ctx, AsyncSnapshot _loadShot){
                                          return Positioned(
                                            width: _screenSize.width,
                                            top: _shouldReload ? _reloadHeight : _commentLoaderTop,
                                            child: Opacity(
                                              opacity: 1,
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
                                                  child: _shouldReload ? CircularProgressIndicator(
                                                    valueColor: AlwaysStoppedAnimation<Color>(pageTheme.fontColor),
                                                    strokeWidth: 2,
                                                  ) : CircularProgressIndicator(
                                                    valueColor: AlwaysStoppedAnimation<Color>(pageTheme.fontColor),
                                                    strokeWidth: 2,
                                                    value: (_commentLoaderTop/_reloadHeight),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),//comment list
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
            else{
              _vplayers.forEach((_player){
                _player.pause();
              });
            }
          },
        ),
      ),
      onWillPop: ()async{
        if(_showComments){
          hideComment();
        }
        else Navigator.of(context).pop();
        return false;
      },
    );
  }//route's build method

  List<CachedVideoPlayerController> _vplayers= List<CachedVideoPlayerController>();
  resetVplayer(){
    _vplayers.forEach((element) {
      element.dispose();
    });
    _vplayers=List<CachedVideoPlayerController>();
  }

  StreamController _ctrTapNotifier= StreamController.broadcast();
  double _playerCtrOpacity=0;

  bool _isBuffering=false;
  int _localTimeTracker=0;
  int _lastStoredPlayerPos=0;
  int _curPlayerPos=0;
  int _curPlayerduration=100;
  double _vplayerVolume=1;
  bool _isplaying=true;
  initVplayerEvent(){
    CachedVideoPlayerController _focPlayer= _vplayers.last;
    _curPlayerduration= _focPlayer.value.duration.inSeconds;
    if(_isplaying) _focPlayer.play();
    _focPlayer.setVolume(_vplayerVolume);
    _focPlayer.addListener(() {
      _curPlayerPos=_focPlayer.value.position.inSeconds;
      _isplaying= _focPlayer.value.isPlaying;

      int _localInnerTime= DateTime.now().millisecondsSinceEpoch;
      if(_localInnerTime - _localTimeTracker >=1000){
        _localTimeTracker=_localInnerTime;
        _isBuffering= (_lastStoredPlayerPos == _focPlayer.value.position.inSeconds) && (_isplaying);
        _lastStoredPlayerPos=_focPlayer.value.position.inSeconds;
      }
      if(!_playerPosChangedNotifier.isClosed)
      _playerPosChangedNotifier.add("kjut");

      playEndCheck();
    });
  }//add player events

  bool _endChecked=false;
  playEndCheck(){
    if((_curPlayerPos == _curPlayerduration) && (_endChecked == false)){
      _endChecked=true;
      if(_pageListData.length>0){
        String _nextPostID= _pageListData[0]["post_id"];
        String _nextChannelID= _pageListData[0]["channel_id"];
        Navigator.of(_pageContext).pushReplacement(MaterialPageRoute(
          builder: (BuildContext _ctx){
            return WatchVideo(_nextPostID, _nextChannelID);
          }
        ));
      }
    }
  }//play end check

  bool _showComments=false; double _commentBoxHeight=0;
  StreamController _showCommentCtr= StreamController.broadcast();
  StreamController _pageStreamCtr= StreamController.broadcast();
  StreamController _vidAvailableCtr= StreamController.broadcast();
  StreamController _playerPosChangedNotifier= StreamController.broadcast();
  StreamController _viewCountChangeNotifier= StreamController.broadcast();
  StreamController _postTimeChangeNotifier= StreamController.broadcast();
  StreamController _likeChangeNotifier= StreamController.broadcast();
  StreamController _subChangeNotifier= StreamController.broadcast();
  StreamController _shorMoreCtr= StreamController.broadcast();
  StreamController _showCommentGestureTapNotifier= StreamController.broadcast();
  StreamController _postCommentsLoadedNotifier= StreamController.broadcast();
  StreamController _replyCommentUpdateNotifier= StreamController.broadcast();
  StreamController _commILikeUpdateNotifier=StreamController.broadcast();
  StreamController _showReplyToCtr= StreamController.broadcast();
  StreamController _viewReplyCtr= StreamController.broadcast();
  StreamController _vplayerCacheAvailNotifier= StreamController.broadcast();

  StreamController _pagePosterAvailCtr= StreamController.broadcast();
  StreamController _ochannelDPAvailCtr= StreamController.broadcast();
  StreamController _playerChannelDPAvailCtr= StreamController.broadcast();

  StreamController _commentReloadCtr= StreamController.broadcast();

  ScrollController _commentLiCtr= ScrollController();
  ScrollController _mainListCtr= ScrollController();

  TextEditingController _commentCtr= TextEditingController();
  FocusNode _commentNode=FocusNode();
  @override
  void dispose() {
    resetVplayer();
    _pageStreamCtr.close();
    _vidAvailableCtr.close();
    _playerPosChangedNotifier.close();
    _ctrTapNotifier.close();
    _toastCtr.close();
    _viewCountChangeNotifier.close();
    _postTimeChangeNotifier.close();
    _likeChangeNotifier.close();
    _subChangeNotifier.close();
    _shorMoreCtr.close();
    _showCommentCtr.close();
    _likeAniCtr.dispose();
    _commentCtr.dispose();
    _postCommentsLoadedNotifier.close();
    _replyCommentUpdateNotifier.close();
    _commILikeUpdateNotifier.close();
    _showReplyToCtr.close();
    _viewReplyCtr.close();
    _commentLiCtr.dispose();
    _commentReloadCtr.close();
    _mainListCtr.dispose();
    _vplayerCacheAvailNotifier.close();
    _pagePosterAvailCtr.close();
    _ochannelDPAvailCtr.close();
    _playerChannelDPAvailCtr.close();
    super.dispose();
  }//route's dispose method

  double _toastLeft=0, _toastTop=0;
  StreamController _toastCtr= StreamController.broadcast();
  bool _showToast=false;
  String _toastText="";
  showLocalToast({String text, Duration duration}){
    _showToast=true;
    _toastText=text;
    if(!_toastCtr.isClosed)
    _toastCtr.add("kjut");
    Future.delayed(
        duration,
            (){
          _showToast=false;
          if(!_toastCtr.isClosed)_toastCtr.add("kjut");
        }
    );
  }//show local toast

  Widget renderComments(String _userDP, Map _commentBlock){
    String _commID= _commentBlock["comment_id"];
    _commLikeCount[_commID]=_commentBlock["like_count"];
    _commILike[_commID]=_commentBlock["i_like"] == "yes";
    String _locreplyCount=_commentBlock["reply_count"];
    return Container(
      decoration: BoxDecoration(
          color: pageTheme.bgColor
      ),
      padding: EdgeInsets.only(top: 9, bottom: 9, left: 16, right: 16),
      margin: EdgeInsets.only(bottom: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            child: _userDP.length == 1 ?
            CircleAvatar(
              radius: 20,
              child: Text(
                  _userDP.toUpperCase()
              ),
            ): CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(_userDP),
            ),
          ),//user channel dp
          Expanded(
            child: Container(
              padding: EdgeInsets.only(left: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          child: Text(
                            _commentBlock["fullname"],
                            style: TextStyle(
                                color: pageTheme.fontGrey,
                                fontSize: 11
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        Container(
                          width: 3, height: 3,
                          decoration: BoxDecoration(
                              color: pageTheme.fontGrey,
                              borderRadius: BorderRadius.circular(3)
                          ),
                          margin: EdgeInsets.only(left: 7, right: 7),
                        ),
                        Expanded(
                          child: Container(
                            child: Text(
                              _commentBlock["comment_time"],
                              style: TextStyle(
                                  fontSize: 11,
                                  color: pageTheme.fontGrey
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                      ],
                    ),
                  ), //user fullname and comment time
                  Container(
                    margin: EdgeInsets.only(top: 1),
                    child: RichText(
                      textScaleFactor: MediaQuery.of(_pageContext).textScaleFactor,
                      text: TextSpan(
                          children: globals.parseTextForLinks(_commentBlock["comment"]),
                        style: TextStyle(
                          color: pageTheme.fontColor
                        )
                      ),
                    ),
                  ), //the comment text
                  Container(
                    margin: EdgeInsets.only(top: 7),
                    child: Row(
                      children: [
                        Container(
                          child: StreamBuilder(
                            stream:_commILikeUpdateNotifier.stream,
                            builder: (BuildContext _ctx, AsyncSnapshot _ilikeShot){
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: (){
                                    likeComment(_commID);
                                    if(_commILike[_commID]){
                                      _commILike[_commID]=false;
                                      _commLikeCount[_commID]= (int.tryParse(_commLikeCount[_commID]) - 1).toString();
                                    }
                                    else{
                                      _commILike[_commID]=true;
                                      _commLikeCount[_commID]= (int.tryParse(_commLikeCount[_commID]) + 1).toString();
                                    }
                                    if(!_commILikeUpdateNotifier.isClosed)_commILikeUpdateNotifier.add("kjut");
                                  },
                                  child: Ink(
                                    child: Row(
                                      children: [
                                        Container(
                                          child: _commILike[_commID] ? ScaleTransition(
                                            scale:_likeAni,
                                            child: Icon(
                                              FlutterIcons.ios_heart_ion,
                                              color: pageTheme.profileIcons,
                                              size: 14,
                                            ),
                                          ): Icon(
                                            FlutterIcons.heart_evi,
                                            color: pageTheme.profileIcons,
                                            size: 14,
                                          ),
                                        ),
                                        Container(
                                          margin: EdgeInsets.only(left: 5),
                                          child: Text(
                                            _commLikeCount[_commID]=="0" ? "" : globals.convertToK(int.tryParse(_commLikeCount[_commID])),
                                            style: TextStyle(
                                                color: pageTheme.fontGrey,
                                                fontSize: 14
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),//like comment
                        Container(
                          margin: EdgeInsets.only(left: 12),
                          child: StreamBuilder(
                            stream:_replyCommentUpdateNotifier.stream,
                            builder: (BuildContext _ctx, AsyncSnapshot _ilikeShot){
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: (){
                                    _replyTo="$_commID";
                                    _replyUsername=_commentBlock["fullname"];
                                    if(!_showReplyToCtr.isClosed)_showReplyToCtr.add("kjut");
                                    FocusScope.of(_pageContext).requestFocus(_commentNode);
                                  },
                                  child: Ink(
                                    child: Row(
                                      children: [
                                        Container(
                                            child: Icon(
                                              FlutterIcons.comments_faw5,
                                              color: pageTheme.profileIcons,
                                            )
                                        ),
                                        Container(
                                          margin: EdgeInsets.only(left: 5),
                                          child: Text(
                                            _locreplyCount=="0" ? "" : globals.convertToK(int.tryParse(_locreplyCount)),
                                            style: TextStyle(
                                                color: pageTheme.fontGrey,
                                                fontSize: 14
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),//reply comment
                      ],
                    ),
                  ), //like and reply btns
                  StreamBuilder(
                    stream: _viewReplyCtr.stream,
                    builder: (BuildContext _ctx, AsyncSnapshot _viewReplyShot){
                      if(_locreplyCount!="0" && _replyComments.containsKey("$_commID")){
                        List<Widget> _colChildren=List<Widget>();
                        List _repCommLi= _replyComments[_commID];
                        int _repCommCount= _repCommLi.length;
                        for(int _j=0; _j<_repCommCount; _j++){
                          Map _repBlock=_repCommLi[_j];
                          String _repDP= _repBlock["user_dp"];
                          _colChildren.add(renderComments(_repDP, _repBlock));
                        }
                        return Container(
                          margin: EdgeInsets.only(top: 18),
                          padding: EdgeInsets.only(left: 0, right: 9),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _colChildren,
                          ),
                        );
                      }
                      else if(_fetchingRComment == _commID){
                        return Container(
                          child: TweenAnimationBuilder(
                            duration: Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                            tween: Tween<double>(begin: 0, end: 50),
                            builder: (BuildContext _ctx, double _twVal, _){
                              return Container(
                                height: _twVal,
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(pageTheme.fontGrey),
                                    strokeWidth: 3,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }
                      else if(_locreplyCount!="0"){
                        return Container(
                          margin: EdgeInsets.only(top: 12),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: (){
                                fetchComments("reply", _commID, "0", true);
                              },
                              child: Ink(
                                child: Text(
                                  "View reply (" + globals.convertToK(int.tryParse(_locreplyCount)) + ")",
                                  style: TextStyle(
                                      color: Colors.blue,
                                      fontFamily: "ubuntu"
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      return Container();
                    },
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }//renders the comment block using the data passed-in to it
}