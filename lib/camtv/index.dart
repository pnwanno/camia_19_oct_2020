import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'package:cached_video_player/cached_video_player.dart';

import '../kcache_mgr.dart';
import './theme_data.dart' as pageTheme;
import '../globals.dart' as globals;
import '../dbs.dart';
import './my_channel.dart';
import './watch_video.dart';
import './history.dart';
import './liked_posts.dart';
import 'subscriptions.dart';
import './add_video.dart';

class CamTV extends StatefulWidget{
  _CamTV createState(){
    return _CamTV();
  }
}

class _CamTV extends State<CamTV>{
  Directory _appDir;
  Directory _tvDir;
  DBTables _dbTables= DBTables();

  Widget _channeldp=Container();
  String _globalChannelName="";
  String _globalChannelId="";

  DateTime _cacheExpireDate;
  @override
  void initState() {
    _cacheExpireDate= DateTime.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch + (7 * 24 * 3600 * 1000));
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _toastTop= _screenSize.height * .4;
    });
    _pageData=List();
    fetchPosts();
    addLVEvents();
    super.initState();
  }//route's init state

  double _reloadHeight=50;
  double _mainLVLoaderTop=-50;
  bool _pointerDown=false;
  bool _shouldReloadMain=false;
  StreamController _mainReloaderCtr= StreamController.broadcast();
  addLVEvents(){
    _pageListScrollCtr.addListener(() {
      //events to play videos on scroll
      List<String> _mostViable= List<String>();
      List<String> _viable= List<String>();
      if(_pageListScrollCtr.position.pixels>-1){
        _pageItemKeys.forEach((key, value) {
          if(value.currentContext!=null){
            RenderBox _rb= value.currentContext.findRenderObject();
            Offset _targOffset=_rb.localToGlobal(Offset.zero);
            Size _targSize= _rb.size;
            if(_targOffset.dy>0 && (_targOffset.dy + _targSize.height)<_screenSize.height){
              _mostViable.add(key);
            }
            else if(_targOffset.dy > 0 && _targOffset.dy<_screenSize.height){
              _viable.add(key);
            }
            else if((_targOffset.dy + _targSize.height) > 0 && (_targOffset.dy + _targSize.height)<_screenSize.height){
              _viable.add(key);
            }
          }
        });
        if(_mostViable.length>0){
          if(_curPost!=_mostViable[0]){
            _curPost=_mostViable[0];
            if(!_vplayerChangeNotifier.isClosed)_vplayerChangeNotifier.add("kjut");
          }
        }
      }

      //event to reload page
      if(_pageListScrollCtr.position.pixels<0){
        _mainLVLoaderTop= (-1 * _pageListScrollCtr.position.pixels) - 25;
        if(_pointerDown == false && _mainLVLoaderTop>=_reloadHeight-3){
          //the -3 subtracted from the the reload height is just an allowance value to allow basic delay from the user
          _shouldReloadMain=true;
          //reload method goes here
          if(_vplayers.length>0){
            _vplayers.last.pause().then((value){
              _existingPIDs=List();
              _pageData=List();
              fetchPosts();
            });
          }

          Future.delayed(
              Duration(seconds: 2),
                  (){
                _mainLVLoaderTop=-50;
                _shouldReloadMain=false;
                if(!_mainReloaderCtr.isClosed)_mainReloaderCtr.add("kjut");
              }
          );
        }
        if(!_mainReloaderCtr.isClosed)_mainReloaderCtr.add("kjut");
      }


      //infinite load more
      if(!_fetchingPost && _isOnline){
        if(_pageListScrollCtr.position.pixels > _pageListScrollCtr.position.maxScrollExtent - (_screenSize.height * 2)){
          fetchPosts();
        }
      }

    });
  }//add list view events

  List _pageData= List();
  bool _fetchingPost=false;
  List<String> _existingPIDs=List<String>();
  bool _isOnline=true;
  fetchPosts()async{
    if(_fetchingPost) return;
    _fetchingPost=true;
    try{
      http.Response _resp= await http.post(
        globals.globBaseTVURL + "?process_as=fetch_tv_posts",
        body:{
          "user_id": globals.userId,
          "existing" : jsonEncode(_existingPIDs)
        }
      );
      _isOnline=true;
      if(_resp.statusCode == 200){
        List _respObj= jsonDecode(_resp.body);
        if(_respObj.length>0){
          if(_pageData.length==0){
            resetVPlayers();
          }
          _pageData.addAll(_respObj);
          kCacheDl();
          if(!_pageDataUpdateNotifier.isClosed)_pageDataUpdateNotifier.add("kjut");
          Database _con= await _dbTables.tvProfile();
          await _con.execute("delete from tv_posts");
          int _kount= _respObj.length;
          for(int _k=0; _k<_kount; _k++){
            String _channelID=_respObj[_k]["channel_id"];
            String _postID=_respObj[_k]["post_id"];
            _existingPIDs.add(_postID);
            String _userID=_respObj[_k]["user_id"];
            String _title=_respObj[_k]["title"];
            String _postText=_respObj[_k]["post_text"];
            String _duration=_respObj[_k]["duration"];
            String _ar=_respObj[_k]["ar"];
            String _postPath=_respObj[_k]["post_path"];
            String _posterPath=_respObj[_k]["poster_path"];
            String _lchannelDP=_respObj[_k]["channel_dp"];
            String _channelName=_respObj[_k]["channel_name"];
            String _views=_respObj[_k]["views"];
            String _postTime=_respObj[_k]["post_time"];
            String _recommendedAs=_respObj[_k]["recommended_as"];
            String _postLikes=_respObj[_k]["likes"];
            _con.execute("insert into tv_posts (channel_id, post_id, user_id, title, post_text, duration, ar, post_path, poster_path, channel_dp, channel_name, views, post_time, recommended_as, likes) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [
              _channelID, _postID, _userID, _title, _postText, _duration, _ar, _postPath, _posterPath, _lchannelDP, _channelName, _views, _postTime, _recommendedAs, _postLikes
            ]);
            _fetchingPost=false;
          }
        }
        else{
          if(_pageData.length == 0){
            _pageData.add({
              "nodata": "nodata"
            });
            if(!_pageDataUpdateNotifier.isClosed)_pageDataUpdateNotifier.add("kjut");
          }
        }
      }
    }
    catch(ex){
      _isOnline=false;
      _fetchingPost=false;
      Database _con= await _dbTables.tvProfile();
      var _result= await _con.rawQuery("select * from tv_posts");
      int _kount= _result.length;
      for(int _k=0; _k<_kount; _k++){
        _pageData.add(_result[_k]);
      }
      kCacheDl();
      if(!_pageDataUpdateNotifier.isClosed){
        _pageDataUpdateNotifier.add("kjut");
      }
    }
  }//fetch posts

  kCacheDl(){
    int _kount= _pageData.length;
    for(int _k=0; _k<_kount; _k++){
      String _posterPath= _pageData[_k]["poster_path"];
      kjutCacheMgr.downloadFile(_posterPath, _cacheExpireDate).then((value) async{
        _availCache=await kjutCacheMgr.listAvailableCache();
        if(!_posterAvailNotifier.isClosed)_posterAvailNotifier.add("kjut");
      });
      String _postPath= _pageData[_k]["post_path"];
      kjutCacheMgr.downloadFile(_postPath, _cacheExpireDate).then((value) async{
        _availCache=await kjutCacheMgr.listAvailableCache();
      });
      String _channelDP= _pageData[_k]["channel_dp"];
      if(_channelDP.length>1){
        kjutCacheMgr.downloadFile(_channelDP, _cacheExpireDate).then((value) async{
          _availCache=await kjutCacheMgr.listAvailableCache();
          if(!_channelDPAvailNotifier.isClosed)_channelDPAvailNotifier.add("kjut");
        });
      }
    }
  }

  ///A convenient function to get channel dp
  genChannelDp(String dp) async{
    Database _con=await _dbTables.tvProfile();
    var _result= await _con.rawQuery("select * from profile limit 1");
    if(_result.length == 1){
      _globalChannelName= _result[0]["channel_name"];
      _globalChannelId=_result[0]["channel_id"];
    }
    if(dp.length == 1){
      _channeldp= Container(
        alignment: Alignment.center,
        child: CircleAvatar(
          radius: 24,
          child: Text(
            dp.toUpperCase()
          ),
        ),
      );
    }
    else{
      _channeldp= Container(
        alignment: Alignment.center,
        child: CircleAvatar(
          radius: 24,
          backgroundImage: FileImage(File(_tvDir.path + "/$dp")),
        ),
      );
    }
    if(!_profileUpdateNotifier.isClosed){
      _profileUpdateNotifier.add("kjut");
    }
  }

  Map _availCache={};
  KjutCacheMgr kjutCacheMgr=KjutCacheMgr();
  String _activeChannelID="";
  bool _fetchingProfile=false;
  initDir()async{
    kjutCacheMgr.initMgr().then((value) async{
      _availCache= await kjutCacheMgr.listAvailableCache();
    });

    if(_fetchingProfile == false){
      _fetchingProfile=true;
      if(_appDir==null){
        _appDir= await getApplicationDocumentsDirectory();
        _tvDir= Directory(_appDir.path + "/camtv");
        await _tvDir.create();
        //create a tmp folder for local processing
        Directory _tmpDir= Directory(_tvDir.path + "/tmp");
        await _tmpDir.create();
        List<FileSystemEntity> _tmpFiles= _tmpDir.listSync();
        int _tmpFilesCount=_tmpFiles.length;
        for(int _k=0; _k<_tmpFilesCount; _k++){
          try{
            _tmpFiles[_k].delete();
          }
          catch(ex){

          }
        }
      }

      Database _con= await _dbTables.tvProfile();
      var _result= await _con.rawQuery("select * from profile where status='ACTIVE' limit 1");
      if(_result.length<1){
        try{
          http.Response _resp= await http.post(
              globals.globBaseTVURL + "?process_as=try_create_tv_profile",
              body: {
                "user_id": globals.userId
              }
          );

          if(_resp.statusCode == 200){
            var _respObj= jsonDecode(_resp.body);
            String _innerchname=_respObj["channel_name"];
            String _inchDP= _respObj["dp"];
            String _inwebsite= _respObj["website"];
            String _inbrief= _respObj["about"];
            String _instatus="ACTIVE";
            String _inchannelid= _respObj["id"]; _activeChannelID="$_inchannelid";
            String _interests=_respObj["interests"];
            String _dpname=_inchDP;
            List<String> _brkdpstr;
            if(_inchDP.length>1){
              _brkdpstr= _inchDP.split("/");
              _dpname=_brkdpstr.last;
            }

            _con.execute("insert into profile (channel_name, dp, website, brief, status, channel_id, interests) values (?, ?, ?, ?, ?, ?, ?)",
                [_innerchname,_dpname, _inwebsite, _inbrief, _instatus, _inchannelid, _interests]).then((value){
              if(_inchDP.length>1){
                http.get(_inchDP).then((_dpresp){
                  File _locdpf=File(_appDir.path + "/camtv/$_dpname");
                  _locdpf.writeAsBytes(_dpresp.bodyBytes).then((value){
                    genChannelDp(_dpname);
                    _fetchingProfile=false;
                  });
                });
              }
              else {
                genChannelDp(_dpname);
                _fetchingProfile=false;
              }
            });
          }
        }
        catch(ex){
          _fetchingProfile=false;
        }
      }
      else{
        _fetchingProfile=false;
        Map _rw= _result[0];
        String _inchdp= _rw["dp"];
        _activeChannelID=_rw["channel_id"];
        genChannelDp(_inchdp);
      }
    }
  }//init directory

  String _curPost="";
  final Map<String, GlobalKey> _pageItemKeys= Map<String, GlobalKey>();
  GlobalKey<ScaffoldState> _scaffoldkey= GlobalKey<ScaffoldState>();
  BuildContext _pageContext;
  Size _screenSize;
  String _deviceTheme;
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize= MediaQuery.of(_pageContext).size;
    return Scaffold(
      key: _scaffoldkey,
      resizeToAvoidBottomPadding: true,
      drawer: Drawer(
        child: FocusScope(
          autofocus: true,
          child: Container(
            decoration: BoxDecoration(
                color: pageTheme.bgColor,
            ),
            child: ListView(
              children: <Widget>[
                DrawerHeader(
                    margin: EdgeInsets.only(bottom: 0, top: 0),
                    decoration: BoxDecoration(
                        color: pageTheme.drawerHeadBG,
                      border: Border(
                        bottom: BorderSide(
                          color:pageTheme.drawerLine
                        )
                      )
                    ),
                    child: Container(
                      child: Stack(
                        children: [
                          Container(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                StreamBuilder(
                                  stream: _profileUpdateNotifier.stream,
                                  builder: (BuildContext _ctx, AsyncSnapshot snapshot){
                                    return _channeldp;
                                  },
                                ),//user dp
                                Expanded(
                                    child: Container(
                                      margin: EdgeInsets.only(left:12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          Container(
                                            margin:EdgeInsets.only(bottom: 3),
                                            child: Text(
                                              globals.fullname,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: pageTheme.fontColor
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          //fullname

                                          StreamBuilder(
                                            stream: _profileUpdateNotifier.stream,
                                            builder: (BuildContext _ctx, snapshot){
                                              return Container(
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: <Widget>[
                                                    Container(
                                                      margin:EdgeInsets.only(right:5),
                                                      child: Text(
                                                        _globalChannelName,
                                                        style: TextStyle(
                                                            color: pageTheme.usernameColor,
                                                            fontSize: 11,
                                                            fontFamily: "ubuntu"
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    Icon(
                                                      FlutterIcons.tv_fea,
                                                      color: pageTheme.fontColor,
                                                      size: 16,
                                                    )
                                                  ],
                                                ),
                                              );
                                            },
                                          )
                                        ],
                                      ),
                                    )
                                ),//other user details
                              ],
                            ),
                          ),
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: (){
                                  Navigator.of(_pageContext).pop();
                                  if(_globalChannelId == ""){
                                    showLocalToast(
                                        text: "It seems like this channel have not been registered yet! - Connect to the internet to register it",
                                        duration: Duration(seconds: 7)
                                    );
                                  }
                                  else{
                                    Navigator.of(_pageContext).push(
                                        MaterialPageRoute(
                                          builder: (_){
                                            return MyChannels(_globalChannelId);
                                          },
                                        )
                                    );
                                  }
                                },
                                highlightColor: Colors.transparent,
                                child: Ink(

                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    )
                ),//drawer header

                Container(
                  decoration: BoxDecoration(
                      color: pageTheme.bgColorVar1,
                      border: Border(
                          bottom: BorderSide(
                              color:pageTheme.drawerItemColor
                          )
                      )
                  ),
                  child: ListTile(
                    leading: Icon(
                      FlutterIcons.home_fea,
                      color: pageTheme.drawerItemFontColor,
                    ),
                    title: Text(
                      "Home",
                      style: TextStyle(
                          color: pageTheme.drawerItemFontColor
                      ),
                    ),
                    onTap: (){
                      Navigator.of(_pageContext).pop();
                    },
                  ),
                ),//home
                Container(
                  decoration: BoxDecoration(
                      color: pageTheme.bgColorVar1,
                  ),
                  child: ListTile(
                    leading: Icon(
                      FlutterIcons.trending_up_fea,
                      color: pageTheme.drawerItemFontColor,
                    ),
                    title: Text(
                      "Trending",
                      style: TextStyle(
                          color: pageTheme.drawerItemFontColor
                      ),
                    ),
                  ),
                ),//trending
                Container(
                  decoration: BoxDecoration(
                      color: pageTheme.bgColorVar1,
                  ),
                  child: ListTile(
                    onTap: (){
                      Navigator.of(_pageContext).pop();
                      Navigator.of(_pageContext).push(MaterialPageRoute(
                        builder: (BuildContext _ctx){
                          return SubscribedChannels();
                        }
                      ));
                    },
                    leading: Icon(
                      FlutterIcons.hand_ent,
                      color: pageTheme.drawerItemFontColor,
                    ),
                    title: Text(
                      "Subscriptions",
                      style: TextStyle(
                          color: pageTheme.drawerItemFontColor
                      ),
                    ),
                  ),
                ),//subscriptions
                Container(
                  margin: EdgeInsets.only(top:36, bottom: 12),
                  padding: EdgeInsets.only(left:12, right:12),
                  child: Text(
                    "Your Library",
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                      color: pageTheme.drawerItemColor,
                  ),
                  child: ListTile(
                    leading: Icon(
                      FlutterIcons.like2_ant,
                      color: pageTheme.drawerItemFontColor,
                    ),
                    title: Text(
                      "Liked Videos",
                      style: TextStyle(
                          color: pageTheme.drawerItemFontColor
                      ),
                    ),
                    onTap: (){
                      Navigator.of(_pageContext).push(
                        MaterialPageRoute(
                          builder: (BuildContext _ctx){
                            return LikedVideos();
                          }
                        )
                      );
                    },
                  ),
                ), //liked videos
                Container(
                  decoration: BoxDecoration(
                      color: pageTheme.drawerItemColor,
                  ),
                  child: Material(
                    color: Colors.transparent,
                      child:ListTile(
                        onTap: (){
                          Navigator.pop(_pageContext);
                          Navigator.of(_pageContext).push(
                            CupertinoPageRoute(
                              builder: (BuildContext _ctx){
                                return WatchHistory();
                              }
                            )
                          );
                        },
                        leading: Icon(
                          FlutterIcons.history_faw,
                          color: pageTheme.drawerItemFontColor,
                        ),
                        title: Text(
                          "History",
                          style: TextStyle(
                              color: pageTheme.drawerItemFontColor
                          ),
                        ),
                      )
                  ),
                ), //history

                Container(
                    margin: EdgeInsets.only(top:12, bottom:12),
                    decoration: BoxDecoration(
                        color: pageTheme.drawerItemColor,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        onTap: (){
                          Navigator.of(_pageContext).pop();
                          if(_globalChannelId == ""){
                            showLocalToast(
                                text: "It seems like this channel have not been registered yet! - Connect to the internet to register it",
                                duration: Duration(seconds: 7)
                            );
                          }
                          else{
                            Navigator.of(_pageContext).push(
                                MaterialPageRoute(
                                  builder: (_){
                                    return MyChannels(_globalChannelId);
                                  },
                                )
                            );
                          }
                        },
                        leading: Icon(
                          FlutterIcons.tv_fea,
                          color: pageTheme.drawerItemFontColor,
                        ),
                        title: Text(
                          "Your Channel",
                          style: TextStyle(
                              color: pageTheme.usernameColor
                          ),
                        ),
                      ),
                    )
                )//your channel
              ],
            ),
          ),
          onFocusChange: (bool _isFocused){
            if(_isFocused){
              initDir();
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
      backgroundColor: pageTheme.bgColor,
      appBar: AppBar(
        backgroundColor: pageTheme.bgColorVar1,
        title: Container(
          child: Row(
            children: <Widget>[
              Container(
                height: 24, width: 70,
                decoration: BoxDecoration(
                    image: DecorationImage(
                        image: AssetImage("./images/camtv.png"),
                        fit: BoxFit.contain,
                        alignment: Alignment.topCenter,
                        colorFilter: pageTheme.deviceTheme == "dark" ? ColorFilter.mode(Colors.white, BlendMode.modulate)
                            : ColorFilter.mode(Color.fromRGBO(48, 48, 48, 1), BlendMode.modulate)
                    )
                ),
              ),
              Container(
                child: Text(
                  "Cam TV",
                  style: TextStyle(
                      color: pageTheme.fontColor,
                      fontFamily: "ubuntu",
                    fontSize: 15
                  ),
                ),
              )
            ],
          ),
        ),
        iconTheme: IconThemeData(
            color: pageTheme.fontColor
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: (){
                  if(_activeChannelID == ""){
                    showLocalToast(
                      text: "This channel is not active yet - kindly connect to the internet to register it",
                      duration: Duration(seconds: 7)
                    );
                  }
                  else{
                    Navigator.push(_pageContext, MaterialPageRoute(
                      builder: (BuildContext _ctx){
                        return AddVideo(_activeChannelID);
                      }
                    ));
                  }
                },
                child: Container(
                  padding: EdgeInsets.only(right: 7, left: 7),
                  child: Icon(
                    FlutterIcons.video_plus_mco,
                    color: pageTheme.profileIcons,
                  ),
                ),
              ),
            ),
          ),
          Container(
            alignment: Alignment.center,
            width: 28,
            height: 28,
            margin: EdgeInsets.only(left: 12, right: 18),
            child: StreamBuilder(
              stream: _profileUpdateNotifier.stream,
              builder: (BuildContext _ctx, AsyncSnapshot _profdpshot){
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: (){
                      if(_globalChannelId == ""){
                        showLocalToast(
                            text: "It seems like this channel have not been registered yet! - Connect to the internet to register it",
                            duration: Duration(seconds: 7)
                        );
                      }
                      else{
                        Navigator.of(_pageContext).push(
                            MaterialPageRoute(
                              builder: (_){
                                return MyChannels(_globalChannelId);
                              },
                            )
                        );
                      }
                    },
                    child: Ink(
                      child: _channeldp,
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),

      body: FocusScope(
        child: Listener(
          onPointerUp: (_){
            _pointerDown=false;
          },
          onPointerDown: (_){
            _pointerDown=true;
          },
          child: Container(
            child: Stack(
              children: <Widget>[
                Container(
                  width: _screenSize.width,height: _screenSize.height,
                  alignment: Alignment.center,
                  child: StreamBuilder(
                    stream:_pageDataUpdateNotifier.stream,
                    builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                      if(_pageData.length == 0){
                        return CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(pageTheme.profileIcons),
                          strokeWidth: 2,
                        );
                      }
                      Map _firstMap=_pageData[0];
                      if(_pageData.length == 1){
                        if(_firstMap.containsKey("nodata")){
                          return Container(
                            width: _screenSize.width,
                            height: _screenSize.height,
                            alignment: Alignment.center,
                            padding: EdgeInsets.only(left: 16, right: 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                    margin:EdgeInsets.only(bottom: 3),
                                    child: Icon(
                                      FlutterIcons.movie_open_outline_mco,
                                      size: 36,
                                      color: pageTheme.fontGrey,
                                    )
                                ),
                                Container(
                                    child: Text(
                                      "No recommendations to display",
                                      textAlign:TextAlign.center,
                                      style: TextStyle(
                                          color: pageTheme.fontGrey
                                      ),
                                    )
                                )
                              ],
                            ),
                          );
                        }
                      }
                      return ListView.builder(
                          controller: _pageListScrollCtr,
                          cacheExtent: _screenSize.height * 5,
                          physics: BouncingScrollPhysics(),
                          itemCount: _pageData.length,
                          itemBuilder: (BuildContext _ctx, int _itemIndex){
                            Map _blockIndex=_pageData[_itemIndex];
                            String _targPID= _blockIndex["post_id"];
                            if(!_pageItemKeys.containsKey(_targPID)){
                              _pageItemKeys[_targPID]= GlobalKey();
                            }
                            String _targChannelID= _blockIndex["channel_id"];

                            String _posterPath=_blockIndex["poster_path"];
                            String _postPath=_blockIndex["post_path"];
                            double _targAR= double.tryParse(_blockIndex["ar"]);
                            double _vidHeight= _screenSize.width/_targAR;
                            String _targChannelDP= _blockIndex["channel_dp"];
                            String _recommendedAs= _blockIndex["recommended_as"];
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

                            return Container(
                              key:_pageItemKeys[_targPID],
                              decoration: BoxDecoration(
                                  color: pageTheme.bgColorVar1
                              ),
                              padding: EdgeInsets.only(top: 5, bottom: 5),
                              margin: EdgeInsets.only(bottom: 1),
                              child: Column(
                                children: [
                                  Container(
                                    decoration:BoxDecoration(
                                        color: Colors.black
                                    ),
                                    child: Stack(
                                      children: [
                                        Container(
                                          child: StreamBuilder(
                                            stream:_vplayerChangeNotifier.stream,
                                            builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                              if(_curPost == _targPID){
                                                resetVPlayers();
                                                if(_availCache.containsKey(_postPath)){
                                                  _vplayers.add(CachedVideoPlayerController.file(File(_availCache[_postPath])));
                                                }
                                                else{
                                                  _vplayers.add(CachedVideoPlayerController.network(_postPath));
                                                }
                                                _vplayers.last.initialize().then((value) {
                                                  addVplayerEvent();
                                                });
                                                return Container(
                                                  alignment: Alignment.center,
                                                  width: _screenSize.width,
                                                  height: _vidHeight,
                                                  child: CachedVideoPlayer(
                                                      _vplayers.last
                                                  ),
                                                );
                                              }
                                              return Container(
                                                child: StreamBuilder(
                                                  stream: _posterAvailNotifier.stream,
                                                  builder: (BuildContext _ctx, AsyncSnapshot _cacheshot){
                                                    if(_availCache.containsKey(_posterPath)){
                                                      return Container(
                                                        width: _screenSize.width,
                                                        height: _vidHeight,
                                                        decoration: BoxDecoration(
                                                            image: DecorationImage(
                                                                image: FileImage(File(_availCache[_posterPath]))
                                                            )
                                                        ),
                                                      );
                                                    }
                                                    return Container(
                                                      width: _screenSize.width,
                                                      height: _screenSize.width/_targAR,
                                                      decoration: BoxDecoration(
                                                          image: DecorationImage(
                                                              image: NetworkImage(_posterPath)
                                                          )
                                                      ),
                                                    );
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                                        ),//the player
                                        StreamBuilder(
                                          stream:_playerPosChanged.stream,
                                          builder: (BuildContext _ctx, AsyncSnapshot _posShot){
                                            return AnimatedPositioned(
                                              right: 12, bottom: _curPost == _targPID ? 32 : 12,
                                              duration: Duration(milliseconds: 1500),
                                              curve: Curves.easeInOut,
                                              child: Container(
                                                padding:EdgeInsets.only(left: 7, right: 7, top: 5, bottom: 5),
                                                decoration:BoxDecoration(
                                                    color: Colors.black,
                                                    borderRadius: BorderRadius.circular(2)
                                                ),
                                                child: _curPost == _targPID ? Text(
                                                  globals.convSecToHMS(_curPlayerPos) + " / " + globals.convSecToHMS(_curPlayerDur),
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10
                                                  ),
                                                ) :Text(
                                                  globals.convSecToHMS(int.tryParse(_blockIndex["duration"])),
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),//time displayer
                                        StreamBuilder(
                                          stream: _playerPosChanged.stream,
                                          builder: (BuildContext _ctx, AsyncSnapshot _bufferShot){
                                            return Positioned.fill(
                                              child: Container(
                                                child: Stack(children: [
                                                  (_curPost == _targPID && _isBuffering && _curPlayerPos<1) ?
                                                  Container(
                                                    width: _screenSize.width,
                                                    height: _screenSize.width/_targAR,
                                                    child: FutureBuilder(
                                                      builder: (BuildContext _ctx, AsyncSnapshot _bufferFutureShot){
                                                        if(_bufferFutureShot.hasData){
                                                          return Container(
                                                            decoration: BoxDecoration(
                                                                image: DecorationImage(
                                                                    image: FileImage(_bufferFutureShot.data),
                                                                    fit: BoxFit.fitWidth
                                                                )
                                                            ),
                                                          );
                                                        }
                                                        return Container(
                                                          decoration: BoxDecoration(
                                                              image: DecorationImage(
                                                                  image: NetworkImage(_posterPath),
                                                                  fit: BoxFit.fitWidth
                                                              )
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ): Container(),
                                                  (_curPost == _targPID && _isBuffering) ?
                                                  Positioned(
                                                    right: 12, top: 12,
                                                    child: Container(
                                                      alignment: Alignment.center,
                                                      width: 20, height: 20,
                                                      child: CircularProgressIndicator(
                                                        valueColor: AlwaysStoppedAnimation<Color>(pageTheme.profileIcons),
                                                      ),
                                                    ),
                                                  ) : Container()
                                                ],),
                                              ),
                                            );
                                          },
                                        ),//buffering image displayer
                                        Positioned.fill(
                                            child: Material(
                                              color:Colors.transparent,
                                              child: InkWell(
                                                highlightColor: Colors.transparent,
                                                onTap: (){
                                                  Navigator.of(_pageContext).push(
                                                      CupertinoPageRoute(
                                                          builder: (BuildContext _ctx){
                                                            return WatchVideo(_targPID, _targChannelID);
                                                          }
                                                      )
                                                  );
                                                },
                                                child: Ink(
                                                  width: _screenSize.width,
                                                  height: _screenSize.width/_targAR,
                                                ),
                                              ),
                                            )
                                        )
                                      ],
                                    ),
                                  ),//the player and paraphernalia
                                  Container(
                                    margin:EdgeInsets.only(top: 7),
                                    padding:EdgeInsets.only(left: 12, right: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          margin:EdgeInsets.only(right: 12),
                                          child: _targChannelDP.length == 1 ? CircleAvatar(
                                            radius: 20,
                                            child: Text(
                                                _targChannelDP
                                            ),
                                            backgroundColor: pageTheme.bgColor,
                                            foregroundColor: pageTheme.fontColor,
                                          ): StreamBuilder(
                                            stream: _channelDPAvailNotifier.stream,
                                            builder: (BuildContext _ctx, AsyncSnapshot _dpshot){
                                              if(_availCache.containsKey(_targChannelDP)){
                                                return CircleAvatar(
                                                  radius: 20,
                                                  backgroundImage: FileImage(File(_availCache[_targChannelDP])),
                                                );
                                              }
                                              return CircleAvatar(
                                                radius: 20,
                                                backgroundImage: NetworkImage(_targChannelDP),
                                              );
                                            },
                                          ),
                                        ),//channel dp
                                        Expanded(
                                          child: Container(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  child: Text(
                                                    _blockIndex["title"],
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
                                                    _blockIndex["channel_name"],
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
                                                          globals.convertToK(int.tryParse(_blockIndex["likes"])) + " likes",
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
                                                          globals.convertToK(int.tryParse(_blockIndex["views"])) + " views",
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
                                                          _blockIndex["post_time"],
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
                                              ],
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            );
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
                  stream: _mainReloaderCtr.stream,
                  builder: (BuildContext _ctx, AsyncSnapshot _loadShot){
                    return Positioned(
                      width: _screenSize.width,
                      top: _shouldReloadMain ? _reloadHeight : _mainLVLoaderTop,
                      child: Opacity(
                        opacity: (_mainLVLoaderTop < -24) && !_shouldReloadMain ? 0 : 1,
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
                              valueColor: AlwaysStoppedAnimation<Color>(pageTheme.fontColor),
                              strokeWidth: 2,
                            ) : CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(pageTheme.fontColor),
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
            initDir();
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
            _existingPIDs=List();
            _pageData=List();
            fetchPosts();
          }
          else{
            _vplayers.forEach((element) {
              element.pause();
            });
          }
        },
      ),
    );
  }//route's build

  double _toastLeft=0, _toastTop=0;
  StreamController _toastCtr= StreamController.broadcast();
  bool _showToast=false;
  String _toastText="";
  showLocalToast({String text, Duration duration}){
    _showToast=true;
    _toastText=text;
    if(!_toastCtr.isClosed) _toastCtr.add("kjut");
    Future.delayed(
      duration,
        (){
        _showToast=false;
        if(!_toastCtr.isClosed)_toastCtr.add("kjut");
        }
    );
  }//show local toast

  int _localTimeTracker=0; int _lastStoredPlayerPos=0;
  int _curPlayerPos=0;
  int _curPlayerDur=0;
  StreamController _playerPosChanged= StreamController.broadcast();
  bool _isBuffering=false;
  addVplayerEvent(){
    CachedVideoPlayerController _focplayer=_vplayers.last;
    _curPlayerDur=_focplayer.value.duration.inSeconds;
    _focplayer.setLooping(true);
    _focplayer.setVolume(0);
    _focplayer.play();
    _focplayer.addListener(() {
      //_isBuffering=_focplayer.value.isBuffering; this is not working as of now
      int _localInnerTime= DateTime.now().millisecondsSinceEpoch;
      if(_localInnerTime - _localTimeTracker >=1000){
        _localTimeTracker=_localInnerTime;
        _isBuffering= _lastStoredPlayerPos == _focplayer.value.position.inSeconds;
        _lastStoredPlayerPos=_focplayer.value.position.inSeconds;
      }

      _curPlayerPos=_focplayer.value.position.inSeconds;
      if(!_playerPosChanged.isClosed)_playerPosChanged.add("kjut");
    });
  }//add video player event

  resetVPlayers(){
    _vplayers.forEach((element) {
      element.dispose();
    });
    _vplayers=List<CachedVideoPlayerController>();
  }

  StreamController _profileUpdateNotifier= StreamController.broadcast();
  StreamController _pageDataUpdateNotifier= StreamController.broadcast();
  ScrollController _pageListScrollCtr= ScrollController();
  List<CachedVideoPlayerController> _vplayers=List<CachedVideoPlayerController>();
  StreamController _vplayerChangeNotifier= StreamController.broadcast();
  StreamController _posterAvailNotifier=StreamController.broadcast();
  StreamController _channelDPAvailNotifier=StreamController.broadcast();
  @override
  void dispose() {
    super.dispose();
    _profileUpdateNotifier.close();
    _pageDataUpdateNotifier.close();
    _toastCtr.close();
    _pageListScrollCtr.dispose();
    resetVPlayers();
    _vplayerChangeNotifier.close();
    _playerPosChanged.close();
    _posterAvailNotifier.close();
    _channelDPAvailNotifier.close();
    _mainReloaderCtr.close();
  }//route's dispose

}