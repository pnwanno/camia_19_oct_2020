import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart' as urlLauncher;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:video_player/video_player.dart';

import '../globals.dart' as globals;
import "../dbs.dart";

class WallProfile extends StatefulWidget{
  _WallProfile createState(){
    return _WallProfile();
  }
  final String userId; final String username;
  WallProfile(this.userId, {this.username});
}

class _WallProfile extends State<WallProfile>{

  convertToK(int val){
    List<String> units=["K", "M", "B"];
    double remain = val/1000;
    int counter=-1;
    if(remain>1) counter++;
    while(remain>999){
      counter++;
      remain /=1000;
    }
    if(counter>-1) return remain.toStringAsFixed(1) + units[counter];
    return "$val";
  }//convert to k m or b

  Future followUnfollowUser()async{
    int _isFollowing=_ufollowers.indexOf(globals.userId);
    if(_isFollowing>-1){
      _ufollowers.removeAt(_isFollowing);
    }
    else{
      _ufollowers.add(globals.userId);
    }
    _followingNotifier.add("kjut");
    String _reqId=widget.userId;
    try{
      http.post(
          globals.globBaseUrl + "?process_as=follow_unfollow_wall_user",
          body: {
            "user_id": globals.userId,
            "req_id": _reqId
          }
      ).then((_resp)async{
        if(_resp.statusCode == 200){
          Directory _followingDp= Directory(_wallDir.path + "/following");
          await _followingDp.create();

          Database _con= await _dbTables.wallPosts();
          var _respObj= jsonDecode(_resp.body);
          var _r= await _con.rawQuery("select * from followers where user_id=?", [_reqId]);
          if(_respObj["status"] == "following"){
            if(_r.length <1){
              String _username=_respObj["username"];
              String _dp= _respObj["dp"];
              List<String> _brkDp= _dp.split("/");
              String _dpName=_brkDp.last;
              _con.execute("insert into followers (user_id, user_name, dp) values (?, ?, ?)", [_reqId, _username, _dpName]);
              http.readBytes(_dp).then((_byteData){
                File _dpF= File(_followingDp.path + "/$_dpName");
                _dpF.exists().then((_exists) {
                  if(!_exists){
                    _dpF.writeAsBytes(_byteData);
                  }
                });
              });
            }
          }
          else if(_respObj["status"] == "unfollowing"){
            if(_r.length>0){
              String _dp= _r[0]["dp"];
              int _fid=_r[0]["id"];
              File _dpF= File(_followingDp.path + "/$_dp");
              _dpF.exists().then((_exists){
                if(_exists){
                  _dpF.delete();
                }
              });
              _con.execute("delete from followers where id=?", [_fid]);
            }
          }
        }
      });
    }
    catch(ex){
      _kjToast.showToast(
          text: "Offline mode",
          duration: Duration(seconds: 3)
      );
    }
  }

  RegExp _htag= RegExp(r"^#[a-z0-9_]+$", caseSensitive: false);
  RegExp _href= RegExp(r"[a-z0-9-]+\.[a-z0-9-]+", caseSensitive: false);
  RegExp _atTag= RegExp(r"^@[a-z0-9_]+$", caseSensitive: false);
  RegExp _isEmail= RegExp(r"^[a-z_0-9.-]+\@[a-z0-9-]+\.[a-z0-9-]+(\.[a-z0-9-]+)*$", caseSensitive: false);
  RegExp _phoneExp= RegExp(r"^[0-9 -]+$");

  ///Tries to open a URL or a local link (an app link)
  followLink(String _link){
    if(_isEmail.hasMatch(_link)){
      urlLauncher.canLaunch("mailto:$_link").then((_canLaunch) {
        if(_canLaunch){
          urlLauncher.launch("mailto:$_link");
        }
      });
    }
    else if(_href.hasMatch(_link)){
      String _newhref= "https://" + _link.replaceAll(RegExp(r"^https?:\/\/",caseSensitive: false), "");
      urlLauncher.canLaunch(_newhref).then((_canLaunch) {
        if(_canLaunch){
          urlLauncher.launch(_newhref);
        }
      });
    }
    else if(_phoneExp.hasMatch(_link)){
      String _newphone= "tel:$_link";
      urlLauncher.canLaunch(_newphone).then((_canLaunch) {
        if(_canLaunch){
          urlLauncher.launch(_newphone);
        }
      });
    }
  }

  parseTextForLinks(String _textData){
    _textData=_textData.replaceAll("\n", "__kjut__ ");
    List<String> _brkPostText= _textData.split(" ");
    int _brkPostTextCount= _brkPostText.length;
    List<InlineSpan> _postTextSpan= List<InlineSpan>();
    String _curPostText="";
    for(int _j=0; _j<_brkPostTextCount; _j++){
      String _curText=_brkPostText[_j];
      if(_phoneExp.hasMatch(_curText) || _isEmail.hasMatch(_curText) || _htag.hasMatch(_curText) || _atTag.hasMatch(_curText) || _href.hasMatch(_curText)){
        _postTextSpan.add(
            TextSpan(
                text: _curPostText.replaceAll("__kjut__ ", "\n") + " ",
                style: TextStyle(
                    height: 1.5
                )
            )
        );
        _curPostText="";
        _postTextSpan.add(
            TextSpan(
                text: _curText.replaceAll("__kjut__ ", "\n") + " ",
                style: TextStyle(
                    color: (_isEmail.hasMatch(_curText)) ? Colors.orange :
                    (_href.hasMatch(_curText) || _phoneExp.hasMatch(_curText)) ? Colors.blue : Colors.blueGrey,
                    height: 1.5
                ),
                recognizer: TapGestureRecognizer()..onTap=(){
                  followLink(_curText);
                }
            )
        );
      }
      else{
        _curPostText += _curText.replaceAll("__kjut__ ", "\n") + " ";
      }
    }
    _postTextSpan.add(
        TextSpan(
            text: _curPostText.replaceAll("__kjut__ ", "\n"),
            style: TextStyle(
                height: 1.5
            )
        )
    );
    return _postTextSpan;
  }//parse text for links

  Widget kShimmer(StreamController _ctr, double _extent, double _height, Gradient _gradient){
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: StreamBuilder(
          stream: _ctr.stream,
          builder: (BuildContext _ctx, AsyncSnapshot snapshot){
            Map _snapData= snapshot.hasData ? snapshot.data : {};
            return Stack(
              children: <Widget>[
                AnimatedPositioned(
                  curve: Curves.linear,
                  top: 0,
                  left: (snapshot.hasData && _snapData["state"] == "play")?
                      _snapData["position"]
                  :(-2 * MediaQuery.of(_pageContext).size.width),
                  duration: Duration(milliseconds: 200),
                  onEnd: (){
                    if(_snapData["state"] == "play"){
                      if(!_snapData.containsKey("direction")){
                        _snapData["direction"]="forward";
                        _snapData["opacity"]=1.0;
                      }
                      if(_snapData["direction"] == "forward"){
                        if(_snapData["position"]> _extent){
                          _snapData["direction"]="reverse";
                        }
                      }
                      else{
                        if(_snapData["position"] < 0){
                          _snapData["direction"]="forward";
                        }
                      }
                      _ctr.add({
                        "state": "play",
                        "position": _snapData["direction"] == "forward" ? snapshot.data["position"] + (_extent/10) : snapshot.data["position"] - (_extent/10),
                        "direction": _snapData["direction"],
                        "opacity" : _snapData["opacity"] ==  1.0 ? 0.0 :1.0
                      });
                    }
                  },
                  child: Container(
                    width: _extent * .3,
                    height: _height,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      gradient: _gradient,
                    ),
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }//My custom shimmer effect

  StreamController _profileShimmerCtr=StreamController.broadcast();
  Widget profileShadow({Widget shimmer}){
    return Container(
      child: Stack(
        children: <Widget>[
          Container(
            child: Column(
              children: <Widget>[
                Container(
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 150,
                        child: Column(
                          children: <Widget>[
                            Container(
                              width:70, height:70,
                              margin: EdgeInsets.only(right:12, bottom: 5),
                              decoration: BoxDecoration(
                                  color: Color.fromRGBO(60, 60, 60, 1),
                                  borderRadius: BorderRadius.circular(70)
                              ),
                            ),
                            Container(
                              height: 12,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(7),
                                color: Color.fromRGBO(60, 60, 60, 1)
                              ),
                            )
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                height: 15,
                                width: _screenSize.width * .4,
                                margin: EdgeInsets.only(bottom: 9),
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    color: Color.fromRGBO(60, 60, 60, 1)
                                ),
                              ),
                              Container(
                                height: 30,
                                margin: EdgeInsets.only(bottom: 9),
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    color: Color.fromRGBO(60, 60, 60, 1)
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
          ),
          (shimmer == null) ? Container() : shimmer
        ],
      ),
    );
  }//profile shadow

  List _ufollowers;
  List _ufollowing;
  List _umutual;
  StreamController _followingNotifier= StreamController.broadcast();

  var _userAbout;
  Future fetchWallProfile()async{
    try{
      if(_userAbout==null){
        String _url= globals.globBaseUrl + "?process_as=fetch_user_wall_profile";
        http.Response _resp= await http.post(
            _url,
            body: {
              "user_id": globals.userId,
              "req_id" : widget.userId
            }
        );
        if(_resp.statusCode == 200){
          _userAbout=jsonDecode(_resp.body);
        }
      }
      if(_userAbout!=null){
        var _respObj= _userAbout;
        _localUsername=_respObj["username"];
        _ufollowers= _respObj["r_follower"];
        _ufollowing=_respObj["r_following"];
        _umutual= _respObj["mutual"];

        return Container(
          child: Column(
            children: <Widget>[
              Container(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      child: Column(
                        children: <Widget>[
                          Container(
                            margin:EdgeInsets.only(bottom: 5),
                            child: _respObj["dp"].toString().length == 1?
                            CircleAvatar(
                              radius: 24,
                              child: Text(
                                _respObj["dp"]
                              ),
                            ):
                            CircleAvatar(
                              radius: 45,
                              backgroundImage: NetworkImage(_respObj["dp"]),
                            ),
                          ),//dp
                          Container(
                            child: Text(
                              _respObj["username"],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11
                              ),
                            ),
                          )
                        ],
                      ),
                    ), //dp and username

                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(left:16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              padding:EdgeInsets.only(top:3, bottom: 3, left:16, right: 16),
                              decoration: BoxDecoration(
                                color: Color.fromRGBO(20, 20, 20, 1),
                                borderRadius: BorderRadius.circular(9)
                              ),
                              child: Text(
                                _respObj["fullname"],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey
                                ),
                              ),
                            ),//fullname

                            _respObj["about"] == "" 
                                ?Container(
                              margin: EdgeInsets.only(top:12),
                              width: _screenSize.width * .7,
                              height: 48,
                              decoration: BoxDecoration(
                                color: globals.wallContainerShadow,
                                borderRadius: BorderRadius.circular(7)
                              ),
                            ) 
                            :Container(
                              margin: EdgeInsets.only(top:12),
                              padding:EdgeInsets.only(top:7, bottom: 7, left:12, right: 12),
                              decoration: BoxDecoration(
                                  color: Color.fromRGBO(15, 15, 15, 1),
                                  borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: Color.fromRGBO(20, 20, 20, 1)
                                )
                              ),
                              child: RichText(
                                text: TextSpan(
                                  children: parseTextForLinks(_respObj["about"])
                                ),
                              ),
                            ),//about
                            
                            Container(
                              margin: EdgeInsets.only(top:5),
                              child: RichText(
                                text: TextSpan(
                                  children: parseTextForLinks(_respObj["website"])
                                ),
                              ),
                            ),//website

                            widget.userId == globals.userId
                                ? Container() :
                            StreamBuilder(
                              stream: _followingNotifier.stream,
                              builder: (BuildContext _ctx, AsyncSnapshot snapshot){
                                return Container(
                                  margin: EdgeInsets.only(top:12),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkResponse(
                                      onTap: (){
                                        followUnfollowUser();
                                      },
                                      child: _ufollowers.indexOf(globals.userId)>-1?
                                      Container(
                                          padding: EdgeInsets.only(left:12, right:12, top:7, bottom:7),
                                          decoration: BoxDecoration(
                                              color: Colors.orange,
                                              borderRadius: BorderRadius.circular(12)
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: <Widget>[
                                              Icon(
                                                FlutterIcons.account_arrow_left_mco,
                                                color: Colors.white,
                                              ),
                                              Container(
                                                child: Text(
                                                  "Unfollow",
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12
                                                  ),
                                                ),
                                              )
                                            ],
                                          )
                                      ):
                                      Container(
                                          padding: EdgeInsets.only(left:12, right:12, top:7, bottom:7),
                                          decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              color: Color.fromRGBO(22, 22, 22, 1)
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: <Widget>[
                                              Icon(
                                                FlutterIcons.account_arrow_right_mco,
                                                color: Colors.white,
                                              ),
                                              Container(
                                                margin: EdgeInsets.only(left: 7),
                                                child: Text(
                                                  "Follow",
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12
                                                  ),
                                                ),
                                              )
                                            ],
                                          )
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ), //follow unfollow button
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),//column1

              Container(
                margin: EdgeInsets.only(top: 32),
                padding: EdgeInsets.only(left:16, right: 16, top:20, bottom: 20),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(80, 80, 80, 1),
                  borderRadius: BorderRadius.circular(7)
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    StreamBuilder(
                      stream: _followingNotifier.stream,
                      builder: (BuildContext _ctx, AsyncSnapshot snapshot){
                        return Material(
                          color: Colors.transparent,
                          child: InkResponse(
                            onTap: (){

                            },
                            child: Container(
                              padding: EdgeInsets.only(left: 7, right: 7, top: 7, bottom: 7),
                              decoration:BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(5),
                              ),
                              child: Column(
                                children: <Widget>[
                                  Container(
                                    margin: EdgeInsets.only(bottom: 3),
                                    child: Text(
                                      "Followers",
                                      style: TextStyle(
                                          fontSize: 8,
                                          color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    child: Text(
                                      convertToK(_ufollowers.length),
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontFamily: "ubuntu"
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),//followers

                    Container(
                      padding: EdgeInsets.only(left: 7, right: 7, top: 7, bottom: 7),
                      decoration:BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Column(
                        children: <Widget>[
                          Container(
                            margin: EdgeInsets.only(bottom: 3),
                            child: Text(
                              "Following",
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          Container(
                            child: Text(
                              convertToK(_ufollowing.length),
                              style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: "ubuntu"
                              ),
                            ),
                          )
                        ],
                      ),
                    ),//following

                    (widget.userId == globals.userId) ? Container()
                        :Container(
                      padding: EdgeInsets.only(left: 7, right: 7, top: 7, bottom: 7),
                      decoration:BoxDecoration(
                        color: Color.fromRGBO(10, 10, 10, 1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Column(
                        children: <Widget>[
                          Container(
                            margin: EdgeInsets.only(bottom: 3),
                            child: Text(
                              "Mutual",
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            child: Text(
                              convertToK(_umutual.length),
                              style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: "ubuntu"
                              ),
                            ),
                          )
                        ],
                      ),
                    ),//mutual
                  ],
                ),
              ), //column2 followers following mutual
            ],
          ),
        );
      }
    }
    catch(ex){
    }
  }//fetch wAll profile

  Map<String, VideoPlayerController> _postVideos= Map<String, VideoPlayerController>();
  Widget profileBlock(int _itemIndex){
     Map _liBlock=_pageLiBlocks[_itemIndex];
    String _postId= _liBlock["post_id"];
    if(_wallBlockKeys.containsKey(_postId)){
      _wallBlockKeys[_postId]= GlobalKey();
    }
    String _mediaroot=_pageLiBlocks[_itemIndex]["image_path"];
    List _postmedia=_pageLiBlocks[_itemIndex]["images"];
    int _postmediacount= _postmedia.length;
    List _brkAR= _postmedia[0]["ar"].toString().split("/");
    double _ar=double.tryParse(_brkAR[0])/double.tryParse(_brkAR[1]);
    List<Widget> _pvChildren= List<Widget>();
    for(int _k=0; _k<_postmediacount; _k++){
      if(_postmedia[_k]["type"] == "image"){
        _pvChildren.add(
          Container(
            child: Stack(
              children: <Widget>[
                Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(_mediaroot + "/" + _postmedia[_k]["file"]),
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topCenter
                    )
                  ),
                )
              ],
            ),
          )
        );
      }
      else{
        String _videoId= "$_postId.$_k";
        if(!_postVideos.containsKey(_videoId)){
          _postVideos[_videoId]= VideoPlayerController.network("$_mediaroot/${_postmedia[_k]}");
          _postVideos[_videoId].initialize().then((value){
            _postVideos[_videoId].setVolume(0.0);
            _postVideos[_videoId].seekTo(Duration(milliseconds: 500));
          });
        }
        List _innerARBrk=_postmedia[_k]["ar"].toString().split("/");
        double _innerAr= double.tryParse(_innerARBrk[0])/double.tryParse(_innerARBrk[1]);
        _pvChildren.add(
          Container(
            child: Stack(
              children: <Widget>[
                Container(
                  alignment: Alignment.center,
                  child: AspectRatio(
                    aspectRatio: _innerAr,
                    child: VideoPlayer(
                        _postVideos[_videoId]
                    ),
                  ),
                ),
                Positioned(
                  right: 12, bottom: 12,
                    child: Material(
                      color: Colors.transparent,
                      child: InkResponse(
                        onTap: (){

                        },
                        child: Icon(
                          FlutterIcons.ios_volume_mute_ion
                        ),
                      ),
                    )
                )
              ],
            ),
          )
        );
      }
    }
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      key: _wallBlockKeys[_postId],
      child: Column(
        children: <Widget>[
          Container(
            width: _screenSize.width,
            height:_screenSize.width * (1/_ar),
            child: PageView(
              children: _pvChildren,
            )
          )
        ],
      ),
    );
  }//profile block
  
  List _pageLiBlocks= List();
  StreamController _pageLiUpdater= StreamController.broadcast();
  final Map<String, GlobalKey> _wallBlockKeys= Map<String, GlobalKey>();
  Map<String, StreamController> pvHeightNotifier= Map<String, StreamController>();
  Widget pageBody(){
    if (_kjToast == null){
      _kjToast= globals.KjToast(12.0, _screenSize, _toastCtr, _screenSize.height * .4);
    }
    return Container(
      padding: EdgeInsets.only(top:32, left: 12, right: 12),
      child: Stack(
        children: <Widget>[
          Container(
            child: kjPullToRefresh(
                child: StreamBuilder(
                  stream: _pageLiUpdater.stream,
                  builder: (BuildContext _ctx, snapshot){
                    return ListView.builder(
                        controller: _globalListCtr,
                        itemCount: _pageLiBlocks.length,
                        itemBuilder: (BuildContext _ctx, int _itemIndex){
                          if(_itemIndex == 0){
                            return Container(
                              child: Column(
                                children: <Widget>[
                                  pullToRefreshContainer(),
                                  FutureBuilder(
                                    future: fetchWallProfile(),
                                    builder: (BuildContext __ctx, AsyncSnapshot snapshot){
                                      if(snapshot.hasData){
                                        return snapshot.data;
                                      }
                                      else{
                                        Future.delayed(
                                            Duration(milliseconds: 1000),
                                                (){
                                              _profileShimmerCtr.add({
                                                "state": "play",
                                                "position": 0.0
                                              });
                                            }
                                        );
                                        return profileShadow(
                                            shimmer: kShimmer(
                                                _profileShimmerCtr,
                                                _screenSize.width, 120,
                                                LinearGradient(
                                                    colors: [
                                                      Colors.transparent,
                                                      Color.fromRGBO(70, 70, 70, .7),
                                                      Colors.transparent,
                                                      Colors.transparent,
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    tileMode: TileMode.repeated
                                                )
                                            )
                                        );
                                      }
                                    },
                                  ),
                                  
                                  profileBlock(_itemIndex)
                                ],
                              ),
                            );
                          }
                          else{
                            return profileBlock(_itemIndex);
                          }
                        }
                    );
                  },
                )
            ),
          ),
          _kjToast
        ],
      ),
    );
  }//page body

  globals.KjToast _kjToast;
  StreamController _toastCtr= StreamController.broadcast();

  DBTables _dbTables= DBTables();
  @override
  void initState() {
    super.initState();
    getPageContents();
    localInit();
  }//route's init method

  Directory _appDir;
  Directory _wallDir;
  localInit()async{
    _appDir= await getApplicationDocumentsDirectory();
    _wallDir= Directory(_appDir.path + "/wall_dir");
    await _wallDir.create();
    if(widget.username == null){
      _localUsername="";
    }
    else _localUsername= widget.username;
    _pageLoadNotifier.add("kjut");
  }//local Init


  Future getPageContents()async{
    try{
      http.Response _resp= await http.post(
          globals.globBaseUrl + "?process_as=fetch_user_wall_post",
          body: {
            "user_id" : globals.userId,
            "req_id" : widget.userId,
            "start" : _pageLiBlocks.length.toString()
          }
      );
      if(_resp.statusCode == 200){
        var _respObj= jsonDecode(_resp.body);
        _pageLiBlocks.addAll(_respObj);
        _pageLiUpdater.add("kjut");
      }
    }
    catch(ex){
      _kjToast.showToast(
        text: "Can request for posts in offline mode",
        duration: Duration(seconds: 3)
      );
    }
  }

  BuildContext _pageContext;
  Size _screenSize;
  String _localUsername;
  @override
  Widget build(BuildContext context) {
    _pageContext= context;
    _screenSize=MediaQuery.of(_pageContext).size;
    return Scaffold(
      backgroundColor: Color.fromRGBO(10, 10, 10, 1),
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(32, 32, 32, 1),
        title: StreamBuilder(
          stream: _pageLoadNotifier.stream,
          builder: (BuildContext _ctx, AsyncSnapshot snapshot){
            return Text(
              snapshot.hasData ? _localUsername : (widget.username==null) ? "" : widget.username
            );
          },
        ),
      ),
      body: FocusScope(
        child: pageBody(),
        onFocusChange: (bool _focusState){
          return false;
        },
      ),
    );
  }//route's build method

  StreamController _pageLoadNotifier= StreamController.broadcast();
  @override
  void dispose() {
    super.dispose();
    _pageLoadNotifier.close();
    pullRefreshCtr.close();
    _profileShimmerCtr.close();
    _toastCtr.close();
    _pageLiUpdater.close();
  }//route's dispose method

  ///This is the container placed as the first child of the listview
  ///to show a pull-to-refresh cue
  Widget pullToRefreshContainer(){
    return StreamBuilder(
      stream: pullRefreshCtr.stream,
      builder: (BuildContext ctx, AsyncSnapshot snapshot){
        return AnimatedContainer(
          duration: Duration(milliseconds: 300),
          height: pullRefreshHeight,
          color: Color.fromRGBO(30, 30, 30, 1),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                  bottom: pullRefreshHeight - pullRefreshLoadHeight - 20,
                  child: Container(
                    alignment: Alignment.center,
                    child: Container(
                        width: 50, height: 50,
                        alignment: Alignment.center,
                        child: pullRefreshHeight< pullRefreshLoadHeight ?
                        CircularProgressIndicator(
                          value: pullRefreshHeight/pullRefreshLoadHeight,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                          strokeWidth: 3,
                        ):
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                          strokeWidth: 3,
                        )
                    ),
                  )
              )
            ],
          ),
        );
      },
    );
  }//pull to refresh container

  double pullRefreshHeight=0;
  double pullRefreshLoadHeight=80;
  StreamController pullRefreshCtr= StreamController.broadcast();
  ScrollController _globalListCtr= ScrollController();
  ///Pass a listview as child widget to this widget
  Widget kjPullToRefresh({Widget child}){
    return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerUp: (PointerUpEvent pue){
          if(pullRefreshHeight< pullRefreshLoadHeight){
            pullRefreshHeight =0;
            pullRefreshCtr.add("kjut");
          }
          else{
            Future.delayed(
                Duration(milliseconds: 1500),
                    (){
                  //call the refresh function
                  pullRefreshHeight=0;
                  pullRefreshCtr.add("kjut");

                }
            );
          }
        },
        onPointerMove: (PointerMoveEvent pme){
          Offset _delta= pme.delta;
          if(_globalListCtr.position.atEdge && !_delta.direction.isNegative){
            double dist= math.sqrt(_delta.distanceSquared);
            if(pullRefreshHeight <pullRefreshLoadHeight){
              pullRefreshHeight +=(dist/3);
              pullRefreshCtr.add("kjut");
            }
          }
        },
        child: child
    );
  }//kjut pull to refresh
}