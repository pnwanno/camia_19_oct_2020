import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:video_player/video_player.dart';
import "package:flutter_cache_manager/flutter_cache_manager.dart";

import '../globals.dart' as globals;
import './post_comments.dart';
import './post_likes.dart';
import "../dbs.dart";
import './profile_ff.dart';
import './wall_hash.dart';

class WallProfile extends StatefulWidget{
  _WallProfile createState(){
    return _WallProfile();
  }
  final String userId; final String username;
  WallProfile(this.userId, {this.username});
}

class _WallProfile extends State<WallProfile> with SingleTickerProviderStateMixin{

  List<String> _downloadedBookmarks=List<String>();
  Future bookmarkPost(String _postId)async{
    Database _con= await _dbTables.wallPosts();
    _con.rawQuery("select book_marked from wall_posts where post_id=?", [_postId]).then((_queryResult) {
      if(_queryResult.length==1){
        if(_queryResult[0]["book_marked"] == "no"){
          _con.execute("update wall_posts set book_marked='yes' where post_id='$_postId'");
        }
        else{
          _con.execute("update wall_posts set book_marked='no' where post_id='$_postId'");
        }
      }
      else{
        if(_downloadedBookmarks.indexOf(_postId)<0){
          _downloadedBookmarks.add(_postId);
          //post have not been downloaded yet so we download it
          int _kount=_pageLiBlocks.length;
          for(int _k=0; _k<_kount; _k++){
            Map _targMap=_pageLiBlocks[_k];
            if(_targMap["post_id"] == _postId){
              String _kita= DateTime.now().millisecondsSinceEpoch.toString();
              String _targDPPath= _targMap["dp"];
              List<String> _brkDP= _targDPPath.split("/");
              String _targDP= _brkDP.last;
              String _localDP= _kita + _targDP;
              File _dPF= File(_appDir.path + "/wall_dir/post_media/$_localDP");
              if(_targDPPath.length>1){
                http.readBytes(_targDPPath).then((_dpBytes) {
                  _dPF.writeAsBytes(_dpBytes);
                });
              }
              String _mediaServerLoc=_targMap["image_path"];
              List _postMediaJson=_targMap["images"];
              _con.execute("insert into wall_posts (post_id, user_id, post_images, post_text, views, time_str, likes, comments, post_link_to, status, book_marked, media_server_loc, dp, username, fullname, section, save_time) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [
                _targMap["post_id"],
                widget.userId,
                jsonEncode(_postMediaJson),
                _targMap["post_text"],
                jsonEncode(_targMap["views"]),
                _targMap["post_time"],
                jsonEncode(_targMap["likes"]),
                jsonEncode(_targMap["comments"]),
                _targMap["link_to"],
                "complete", "yes",
                _mediaServerLoc,
                _localDP,
                _targMap["username"],
                _targMap["fullname"],
                "following", _kita
              ]);
              //save the post media
              int _mediacount= _postMediaJson.length;
              for(int _j=0; _j<_mediacount; _j++) {
                String _targMedia=_postMediaJson[_j]["file"];
                http.readBytes("$_mediaServerLoc/$_targMedia").then((_fbytes) {
                  File _mediaF= File(_appDir.path + "/wall_dir/post_media/$_targMedia");
                  _mediaF.writeAsBytes(_fbytes);
                });
              }
              break;
            }
          }
        }
      }
    });
  }//bookmark post

  likeUnlikePost(String postId)async{
    try{
      Database _con= await _dbTables.wallPosts();
      String _likeJson= jsonEncode(_wallLikes[postId]);
      _con.execute("update wall_posts set likes=? where post_id=?", [_likeJson, postId]);
      String url=globals.globBaseUrl + "?process_as=like_wall_post";
      http.post(
          url,
          body: {
            "user_id": globals.userId,
            "post_id": postId,
          }
      );
    }
    catch(ex){

    }
  }//like unlike post

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
          Database _con= await _dbTables.wallPosts();
          var _respObj= jsonDecode(_resp.body);
          if(_respObj["status"] == "following"){
            _con.execute("update wall_posts set section='following' where user_id='$_reqId' and section='unfollowing'");
          }
          else if(_respObj["status"] == "unfollowing"){
            _con.execute("update wall_posts set section='unfollowing' where user_id='$_reqId' and section='following'");
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
  GlobalKey _profileKey= GlobalKey();
  bool _showBarDP=false;
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
        _ufollowers= _respObj["r_follower"];
        _ufollowing=_respObj["r_following"];
        _umutual= _respObj["mutual"];
        String _interests= _respObj["interests"];
        List<String> _brokenInterests= List();
        if(_interests.length>0) _brokenInterests= _interests.split(",");
        List<Widget> _interestChildren= List<Widget>();
        int _countInterest= _brokenInterests.length;
        for(int _k=0; _k<_countInterest; _k++){
          _interestChildren.add(
            Container(
              margin: EdgeInsets.only(right: 9, bottom: 9),
              padding: EdgeInsets.only(left: 12, right: 12, top: 5, bottom: 5),
              decoration: BoxDecoration(
                color: Color.fromRGBO(48, 48, 48, 1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                _brokenInterests[_k],
                style: TextStyle(
                  color: Colors.white
                ),
              ),
            )
          );
        }
        if(_interests.length>0) _brokenInterests= _interests.split("");
        return TweenAnimationBuilder(
          tween: Tween<double>(
            begin: 0, end: 1
          ),
          duration: Duration(milliseconds: 1500),
          curve: Curves.elasticOut,
          builder: (BuildContext _ctx, double _twVal, _){
            return Opacity(
              opacity: _twVal < 0 ? 0 : _twVal>1 ? 1 : _twVal,
              child: Container(
                key: _profileKey,
                transform: Matrix4.translationValues(0, (_twVal * 150) - 150, 0),
                child: Column(
                  children: <Widget>[
                    Container(
                      padding: EdgeInsets.only(left: 12, right: 12),
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
                                        _respObj["dp"].toString().toUpperCase()
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
                                        fontSize: 14,
                                        fontFamily: "ubuntu"
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
                                    padding:EdgeInsets.only(top:5, bottom: 5, left:16, right: 16),
                                    decoration: BoxDecoration(
                                        color: Color.fromRGBO(24, 24, 24, 1),
                                        borderRadius: BorderRadius.circular(9)
                                    ),
                                    child: Text(
                                      _respObj["fullname"],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 15
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
                                    margin: EdgeInsets.only(top:3),
                                    padding:EdgeInsets.only(top:7, bottom: 7, left:12, right: 12),
                                    decoration: BoxDecoration(
                                        color: Color.fromRGBO(24, 24, 24, 1),
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                            color: Color.fromRGBO(20, 20, 20, 1)
                                        )
                                    ),
                                    child: RichText(
                                      textScaleFactor: MediaQuery.of(_pageContext).textScaleFactor,
                                      text: TextSpan(
                                          children: globals.parseTextForLinks(_respObj["about"])
                                      ),
                                    ),
                                  ),//about

                                  Container(
                                    margin: EdgeInsets.only(top:5),
                                    child: RichText(
                                      textScaleFactor: MediaQuery.of(_pageContext).textScaleFactor,
                                      text: TextSpan(
                                          children: globals.parseTextForLinks(_respObj["website"])
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
                                                    color: Color.fromRGBO(22, 22, 22, 1),
                                                    borderRadius: BorderRadius.circular(7)
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
                                                            fontSize: 13
                                                        ),
                                                      ),
                                                    )
                                                  ],
                                                )
                                            ):
                                            Container(
                                                padding: EdgeInsets.only(left:12, right:12, top:7, bottom:7),
                                                decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(7),
                                                    color: Colors.orange
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
                                                            fontSize: 13
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
                      padding: EdgeInsets.only(left: 16, right: 16),
                      margin: EdgeInsets.only(top: 12),
                      child: Container(
                        margin: EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: EdgeInsets.only(right: 12),
                              child: Text(
                                "Interested in: ",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: "ubuntu"
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                child: Wrap(
                                  direction: Axis.horizontal,
                                  children: _interestChildren,
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),//column interested in

                    Container(
                      margin: EdgeInsets.only(top: 32),
                      padding: EdgeInsets.only(left:16, right: 16, top:12, bottom: 12),
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
                                    pauseAllVids();
                                    Navigator.of(_pageContext).push(
                                        MaterialPageRoute(
                                            builder: (BuildContext _ctx){
                                              return ProfileFF(widget.userId, widget.username, _ufollowers.length.toString(), _ufollowing.length.toString(), "0");
                                            }
                                        )
                                    );
                                  },
                                  child: Container(
                                    padding: EdgeInsets.only(left: 7, right: 7, top: 7, bottom: 7),
                                    decoration:BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Column(
                                      children: <Widget>[
                                        Container(
                                          margin: EdgeInsets.only(bottom: 3),
                                          child: Text(
                                            "Followers",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          child: Text(
                                            globals.convertToK(_ufollowers.length),
                                            style: TextStyle(
                                                color: Colors.black,
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

                          Material(
                            color: Colors.transparent,
                            child: InkResponse(
                              onTap: (){
                                Navigator.of(_pageContext).push(
                                    MaterialPageRoute(
                                        builder: (BuildContext _ctx){
                                          return ProfileFF(widget.userId, widget.username, _ufollowers.length.toString(), _ufollowing.length.toString(), "1");
                                        }
                                    )
                                );
                              },
                              child: Container(
                                padding: EdgeInsets.only(left: 7, right: 7, top: 7, bottom: 7),
                                decoration:BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Column(
                                  children: <Widget>[
                                    Container(
                                      margin: EdgeInsets.only(bottom: 3),
                                      child: Text(
                                        "Following",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      child: Text(
                                        globals.convertToK(_ufollowing.length),
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontFamily: "ubuntu"
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),//following,
                            ),
                          ),

                          Container(
                            padding: EdgeInsets.only(left: 16, right: 16, top: 7, bottom: 7),
                            decoration:BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  child: Text(
                                    "Posts",
                                    style: TextStyle(
                                        fontSize: 12
                                    ),
                                  ),
                                ),
                                Container(
                                  child: Text(
                                    globals.convertToK(int.tryParse(_respObj["posts"])),
                                    style: TextStyle(
                                        fontFamily: "ubuntu"
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ), //post count

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
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Container(
                                  child: Text(
                                    globals.convertToK(_umutual.length),
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
              ),
            );
          },
        );
      }
    }
    catch(ex){
    }
  }//fetch wAll profile



  bool _resetting=false;
  resetVidPlayer(){
    if(_resetting == false){
      _resetting=true;
      _postVideos.forEach((key, value) async{
        await value.pause();
        await value.dispose();
      });
      _postVideos= Map<String, VideoPlayerController>();
      _playerIDMap= Map<String, String>();
      _pageLiUpdater.add("kjut");
      resetVidPlayer();
    }
    else{
      _resetting=false;
      _pageLiUpdater.add("kjut");
    }
  }//reset video player

  StreamController _wallLikeCtr= StreamController.broadcast();
  List _pageLiBlocks= List();
  StreamController _pageLiUpdater= StreamController.broadcast();

  Map<String, VideoPlayerController> _postVideos= Map<String, VideoPlayerController>();
  Map<String, String> _playerIDMap= Map<String, String>();
  final Map<String, GlobalKey> _wallBlockKeys= Map<String, GlobalKey>();
  StreamController _pageChangeNotifier= StreamController.broadcast();
  Map<String, PageController> _pageCtrs= Map<String, PageController>();
  Map<String, int> _pvCurPage= Map<String, int>();
  StreamController _vidVolCtrl= StreamController.broadcast();
  Map<String, List> _wallLikes= Map<String, List>();
  StreamController _wallBookedCtr= StreamController.broadcast();
  StreamController _showMorePostCtr= StreamController.broadcast();
  Map<String, bool> _showMorePost= Map<String, bool>();
  Widget pageBody(){
    if (_kjToast == null){
      _kjToast= globals.KjToast(Color.fromRGBO(20, 20, 20, 1), _screenSize, _toastCtr, _screenSize.height * .4);
    }
    return Container(
      padding: EdgeInsets.only(top:32),
      child: Stack(
        children: <Widget>[
          Container(
            child: kjPullToRefresh(
                child: StreamBuilder(
                  stream: _pageLiUpdater.stream,
                  builder: (BuildContext _ctx, snapshot){
                    if(_resetting==true){
                      return Container(
                        width: _screenSize.width, height: _screenSize.height,
                        alignment: Alignment.center,
                        child: CircularProgressIndicator(),
                      );
                    }
                    return ListView.builder(
                        controller: _globalListCtr,
                        itemCount: _pageLiBlocks.length + 1,
                        cacheExtent: _screenSize.height * 3,
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
                                        return profileShadow();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          }
                          else{
                            Map _targMap=_pageLiBlocks[_itemIndex - 1];
                            String _postID= _targMap["post_id"];
                            String _postudp=_targMap["dp"];
                            if(!_wallBlockKeys.containsKey(_postID)){
                              _wallBlockKeys[_postID]= GlobalKey();
                            }
                            List _postcomments=_targMap["comments"];
                            //List _wallLikes= _targMap["likes"];
                            if(!_wallLikes.containsKey(_postID)){
                              _wallLikes[_postID]= _targMap["likes"];
                            }

                            List _postMedia=_targMap["images"];
                            int _mediacount= _postMedia.length;
                            List<String> _pvarstrbrk= _postMedia[0]["ar"].toString().split("/");
                            double _pvAR= double.tryParse(_pvarstrbrk[0])/double.tryParse(_pvarstrbrk[1]);
                            double _postHeight= _screenSize.width * (1/_pvAR);
                            List<Widget> _pvchildren= List<Widget>();
                            if(!_pvCurPage.containsKey(_postID)){
                              _pvCurPage[_postID]=0;
                            }
                            if(!_pageCtrs.containsKey(_postID)){
                              _pageCtrs[_postID]= PageController();
                              _pageCtrs[_postID].addListener(() {
                                double _curPage= _pageCtrs[_postID].page;
                                if(_curPage.floor() == _curPage){
                                  _pvCurPage[_postID]= _curPage.toInt();
                                  _pageChangeNotifier.add("kjut");
                                  pauseAllVids();
                                  String _localVideoID=_postID + "." + _curPage.toInt().toString();
                                  String _localVideoKey= _playerIDMap[_localVideoID];
                                  if(_postVideos.containsKey(_localVideoKey)){
                                    _postVideos[_localVideoKey].play();
                                  }
                                }
                              });
                            }
                            for(int _j=0; _j<_mediacount; _j++){
                              String _mediaserverpath=_targMap["image_path"];
                              if(_postMedia[_j]["type"] == "video"){
                                String _tmpPlayerID="$_postID.$_j";
                                if(!_playerIDMap.containsKey(_tmpPlayerID)){
                                  _playerIDMap[_tmpPlayerID]= DateTime.now().microsecondsSinceEpoch.toString() + "$_j";
                                }
                                String _tmpPlayerKey=_playerIDMap[_tmpPlayerID];
                                List<String> _brkVAR= _postMedia[_j]["ar"].toString().split("/");
                                double _mediaVAR= double.tryParse(_brkVAR[0]) / double.tryParse(_brkVAR[1]);

                                _pvchildren.add(FutureBuilder(
                                  future: DefaultCacheManager().getSingleFile(_mediaserverpath + "/" + _postMedia[_j]["file"]),
                                  builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                    if(_snapshot.hasData){
                                      //dispose old video player and create a new one here
                                      if(_postVideos.containsKey(_tmpPlayerKey)){
                                        _postVideos["$_tmpPlayerKey"].dispose();
                                        _postVideos.remove(_tmpPlayerKey);
                                      }
                                      _playerIDMap[_tmpPlayerID]= DateTime.now().microsecondsSinceEpoch.toString() + "$_j";
                                      _tmpPlayerKey=_playerIDMap[_tmpPlayerID];
                                      _postVideos["$_tmpPlayerKey"] = VideoPlayerController.file(_snapshot.data);
                                      _postVideos["$_tmpPlayerKey"].initialize().then((value){
                                        _postVideos["$_tmpPlayerKey"].setLooping(true);
                                        if(globals.globalWallVideoMute) _postVideos["$_tmpPlayerKey"].setVolume(0);
                                        else _postVideos["$_tmpPlayerKey"].setVolume(1);
                                        _pageChangeNotifier.add("kjut");
                                      });
                                      return Container(
                                        child: AspectRatio(
                                          aspectRatio: _mediaVAR,
                                          child: VideoPlayer(
                                              _postVideos["$_tmpPlayerKey"]
                                          ),
                                        ),
                                      );
                                    }

                                    _postVideos["$_tmpPlayerKey"] = VideoPlayerController.network(_mediaserverpath + "/" + _postMedia[_j]["file"]);
                                    _postVideos["$_tmpPlayerKey"].initialize().then((value){
                                      _postVideos["$_tmpPlayerKey"].setLooping(true);
                                      if(globals.globalWallVideoMute) _postVideos["$_tmpPlayerKey"].setVolume(0);
                                      else _postVideos["$_tmpPlayerKey"].setVolume(1);
                                      _pageChangeNotifier.add("kjut");
                                    });
                                    return Container(
                                      child: AspectRatio(
                                        aspectRatio: _mediaVAR,
                                        child: VideoPlayer(
                                            _postVideos[_tmpPlayerKey]
                                        ),
                                      ),
                                    );
                                  },
                                ));
                              }
                              else{
                                _pvchildren.add(FutureBuilder(
                                  future: DefaultCacheManager().getSingleFile("$_mediaserverpath/" + _postMedia[_j]["file"]),
                                  builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                    if(_snapshot.hasData){
                                      return Container(
                                        width: _screenSize.width,
                                        decoration: BoxDecoration(
                                            image: DecorationImage(
                                                image:  FileImage(_snapshot.data),
                                                fit: BoxFit.cover,
                                                alignment: Alignment.topCenter
                                            )
                                        ),
                                      );
                                    }
                                    return Container(
                                      width: _screenSize.width,
                                      decoration: BoxDecoration(
                                          image: DecorationImage(
                                              image:  NetworkImage("$_mediaserverpath/" + _postMedia[_j]["file"]),
                                              fit: BoxFit.cover,
                                              alignment: Alignment.topCenter
                                          )
                                      ),
                                    );
                                  },
                                ));
                              }
                            }
                            if(!_showMorePost.containsKey(_postID)){
                              _showMorePost[_postID]=false;
                            }
                            return Container(
                              key: _wallBlockKeys[_postID],
                              decoration: BoxDecoration(
                                  color: Color.fromRGBO(24, 24, 24, 1)
                              ),
                              padding: EdgeInsets.only(bottom: 18, top: 18),
                              margin: EdgeInsets.only(bottom: 2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Container(
                                    padding: EdgeInsets.only(left: 18, right:18),
                                    child: Row(
                                      children: <Widget>[
                                        Container(
                                            child: GestureDetector(
                                              onTap: (){
                                              },
                                              child: Container(
                                                margin: EdgeInsets.only(right:9),
                                                child: _postudp.length == 1 ?
                                                CircleAvatar(
                                                  radius: _screenSize.width < 420 ? 15 : 20,
                                                  child: Text(
                                                    _postudp.toLowerCase(),
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ):
                                                CircleAvatar(
                                                  radius: _screenSize.width < 420 ? 15 : 20,
                                                  backgroundImage: NetworkImage(_postudp),
                                                ),
                                              ),
                                            )
                                        ),//userdp
                                        Expanded(
                                          child: Container(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Container(
                                                    margin: EdgeInsets.only(bottom: 3),
                                                    child: Wrap(
                                                      crossAxisAlignment: WrapCrossAlignment.center,
                                                      direction: Axis.horizontal,
                                                      children: <Widget>[
                                                        Container(
                                                          child: Text(
                                                            _targMap["username"],
                                                            style: TextStyle(
                                                                color: Colors.grey
                                                            ),
                                                          ),
                                                        ),
                                                        Container(
                                                          margin: EdgeInsets.only(left: 16, right: 16),
                                                          width: 2, height: 2,
                                                          decoration: BoxDecoration(
                                                              color: Colors.grey
                                                          ),
                                                        ),//separator
                                                        Container(
                                                          child: Text(
                                                            _targMap["post_time"],
                                                            style: TextStyle(
                                                                color: Colors.grey
                                                            ),
                                                          ),
                                                        )
                                                      ],
                                                    )
                                                ),//username and post time
                                                Container(
                                                  child: Wrap(
                                                    crossAxisAlignment: WrapCrossAlignment.center,
                                                    children: <Widget>[
                                                      Container(
                                                        child: _postcomments.length == 0 ?
                                                        Text(
                                                          "No Comments",
                                                          style: TextStyle(
                                                              color: Color.fromRGBO(100, 100, 100, 1)
                                                          ),
                                                        ): GestureDetector(
                                                          onTap: (){
                                                            Navigator.push(_pageContext, MaterialPageRoute(
                                                                builder: (BuildContext _routectx){
                                                                  return ViewPostedComments(_postID);
                                                                }
                                                            ));
                                                          },
                                                          child: Container(
                                                            child: Text(
                                                              "View " + globals.convertToK(_postcomments.length) + " comments",
                                                              style: TextStyle(
                                                                  color: Colors.blueGrey
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),//view comments
                                                      Container(
                                                        margin: EdgeInsets.only(left: 16, right: 16),
                                                        width: 2, height: 2,
                                                        decoration: BoxDecoration(
                                                            color: Colors.grey
                                                        ),
                                                      ), //separator
                                                      StreamBuilder(
                                                        stream: _wallLikeCtr.stream,
                                                        builder: (BuildContext _likectx, AsyncSnapshot _likeshot){
                                                          return Container(
                                                            child: (_wallLikes.length == 0) ? Container(
                                                                child: Text(
                                                                    "No likes",
                                                                    style: TextStyle(
                                                                        color: Color.fromRGBO(100, 100, 100, 1)
                                                                    )
                                                                )
                                                            ): GestureDetector(
                                                              onTap: (){
                                                                Navigator.push(_pageContext, MaterialPageRoute(
                                                                    builder: (BuildContext _routectx){
                                                                      return WallPostLikers(_postID);
                                                                    }
                                                                ));
                                                              },
                                                              child: Container(
                                                                  child: Text(
                                                                    globals.convertToK(_wallLikes[_postID].length) + " likes",
                                                                    style: TextStyle(
                                                                        color: Colors.blueGrey
                                                                    ),
                                                                  )
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      ),//view likes
                                                    ],
                                                  ),
                                                )//like and comment count
                                              ],
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),//userdp, username or fullname, likes count
                                  Container(
                                    height: _postHeight, width: _screenSize.width,
                                    margin: EdgeInsets.only(top: 12),
                                    child: Stack(
                                      children: <Widget>[
                                        Container(
                                          height: _postHeight, width: _screenSize.width,
                                          child: PageView(
                                            physics: BouncingScrollPhysics(),
                                            controller: _pageCtrs[_postID],
                                            children:_pvchildren,
                                          ),
                                        ),
                                        Positioned(
                                          right: 12, top: 12,
                                          child:  _mediacount >1 ? StreamBuilder(
                                            stream:_pageChangeNotifier.stream,
                                            builder: (BuildContext _pgnoctx, AsyncSnapshot _pgnoshot){
                                              return Container(
                                                padding: EdgeInsets.only(top:7, bottom: 7, left: 12, right: 12),
                                                decoration: BoxDecoration(
                                                    color: Color.fromRGBO(32, 32, 32, 1),
                                                    borderRadius: BorderRadius.circular(7)
                                                ),
                                                child: Text(
                                                  (_pvCurPage[_postID] + 1).toString() + "/" + _mediacount.toString(),
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontFamily: "ubuntu"
                                                  ),
                                                ),
                                              );
                                            },
                                          ): Container(),
                                        ),//page number displayer
                                        Positioned(
                                          right: 12, bottom: 12,
                                          child: StreamBuilder(
                                            stream: _pageChangeNotifier.stream,
                                            builder: (BuildContext _isvidctx, AsyncSnapshot _isvidshot){
                                              String _locvididstr= "$_postID." + _pvCurPage[_postID].toString();
                                              String _locvidid=_playerIDMap[_locvididstr];
                                              if(_postVideos.containsKey(_locvidid)){
                                                return Container(
                                                  padding: EdgeInsets.only(left: 9, right: 9, top: 9, bottom: 9),
                                                  decoration: BoxDecoration(
                                                      color: Color.fromRGBO(32, 32, 32, 1),
                                                      borderRadius: BorderRadius.circular(12)
                                                  ),
                                                  child: StreamBuilder(
                                                    stream: _vidVolCtrl.stream,
                                                    builder: (BuildContext _mutectx, AsyncSnapshot _muteshot){
                                                      return GestureDetector(
                                                        onTap: (){
                                                          if(globals.globalWallVideoMute){
                                                            globals.globalWallVideoMute=false;
                                                          }
                                                          else{
                                                            globals.globalWallVideoMute=true;
                                                          }
                                                          _vidVolCtrl.add("kjut");
                                                          _postVideos.forEach((key, value) {
                                                            if(globals.globalWallVideoMute)value.setVolume(0);
                                                            else value.setVolume(1);
                                                          });
                                                        },
                                                        child: Container(
                                                          width: 24, height: 24,
                                                          child: Icon(
                                                            globals.globalWallVideoMute ? FlutterIcons.volume_mute_faw5s : FlutterIcons.volume_up_faw5s,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                );
                                              }
                                              else{
                                                return Container();
                                              }
                                            },
                                          ),
                                        ),//mute and unmute gesture detector
                                      ],
                                    ),
                                  ), //media slides
                                  Container(
                                    padding: EdgeInsets.only(top: 12, bottom: 0, left: 16, right: 16),
                                    child: Row(
                                      children: <Widget>[
                                        Container(
                                          child: Row(
                                            children: <Widget>[
                                              StreamBuilder(
                                                  stream: _wallLikeCtr.stream,
                                                  builder: (BuildContext ctx, AsyncSnapshot snapshot){
                                                    return Material(
                                                      color: Colors.transparent,
                                                      child: InkResponse(
                                                          onTap: (){
                                                            int _ilike=_wallLikes[_postID].indexOf(globals.userId);
                                                            if(_ilike>-1){
                                                              _wallLikes[_postID].removeAt(_ilike);
                                                            }
                                                            else{
                                                              _wallLikes[_postID].add(globals.userId);
                                                            }
                                                            likeUnlikePost(_postID);
                                                            _wallLikeCtr.add("kjut");
                                                          },
                                                          child: _wallLikes[_postID].indexOf(globals.userId)>-1 ?
                                                          Container(
                                                            width: 24, height: 24,
                                                            child: ScaleTransition(
                                                              scale: _likeAni,
                                                              child: Icon(
                                                                FlutterIcons.ios_heart_ion,
                                                                color: Color.fromRGBO(200, 200, 200, 1),
                                                                size: 14,
                                                              ),
                                                            ),
                                                          ):
                                                          Container(
                                                            width: 24, height: 24,
                                                            child: Icon(
                                                              FlutterIcons.ios_heart_empty_ion,
                                                              color: Colors.white,
                                                              size: 14,
                                                            ),
                                                          )
                                                      ),
                                                    );
                                                  }
                                              ),//like icon
                                              Container(
                                                margin:EdgeInsets.only(left:7),
                                                child: GestureDetector(
                                                  onTap: (){
                                                    Navigator.push(_pageContext, CupertinoPageRoute(
                                                        builder: (BuildContext _ctx){
                                                          return ViewPostedComments(_postID);
                                                        }
                                                    ));
                                                  },
                                                  child: Container(
                                                    width: 24, height: 24,
                                                    child: Icon(
                                                      FlutterIcons.comment_faw5,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            ],
                                          ),
                                        ),//like and comment
                                        Expanded(
                                          child: Container(
                                            child: StreamBuilder(
                                              stream: _pageChangeNotifier.stream,
                                              builder: (BuildContext _dotctx, AsyncSnapshot _dotshot){
                                                List<Widget> _dots= List<Widget>();
                                                for(int _k=0; _k<_mediacount; _k++){
                                                  int _curpage=_pvCurPage[_postID];
                                                  _dots.add(
                                                      Container(
                                                        width: _curpage == _k ? 5 : 4, height: _curpage == _k ? 5 : 4,
                                                        margin: EdgeInsets.only(right: 5),
                                                        decoration: BoxDecoration(
                                                            color: _curpage == _k ? Colors.orangeAccent : Colors.grey,
                                                            borderRadius: BorderRadius.circular(5)
                                                        ),
                                                      )
                                                  );
                                                }
                                                if(_mediacount == 1){
                                                  _dots= [Container()];
                                                }
                                                return Container(
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: _dots,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),// dots
                                        Container(
                                          margin:EdgeInsets.only(left: 24),
                                          child: StreamBuilder(
                                            stream: _wallBookedCtr.stream,
                                            builder: (BuildContext _bookCtx, AsyncSnapshot _bookShot){
                                              return GestureDetector(
                                                onTap: (){
                                                  bookmarkPost(_postID);
                                                  int _findbook=_bookmarks.indexOf(_postID);
                                                  if(_findbook>-1) _bookmarks.removeAt(_findbook);
                                                  else _bookmarks.add(_postID);
                                                  _wallBookedCtr.add("kjut");
                                                },
                                                child: Container(
                                                  width: 24, height: 24,
                                                  child: Icon(
                                                    (_bookmarks.indexOf(_postID)>-1) ? FlutterIcons.bookmark_faw : FlutterIcons.bookmark_o_faw,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ), //bookmark
                                      ],
                                    ),
                                  ),//like, comment slide dots and bookmark
                                  Container(
                                      margin: EdgeInsets.only(top: 12),
                                      padding:EdgeInsets.only(left: 12, right:12),
                                      child: StreamBuilder(
                                        stream: _showMorePostCtr.stream,
                                        builder: (BuildContext _moreCtx, AsyncSnapshot _moreshot){
                                          String _postText=_targMap["post_text"];
                                          if(_screenSize.width<420){
                                            if(_postText.length > 90 && _showMorePost[_postID] == false){
                                              _postText = _postText.substring(0, 90) + "...";
                                            }
                                            else{
                                              _showMorePost[_postID]=true;
                                            }
                                          }
                                          else{
                                            if(_postText.length > 200 && _showMorePost[_postID]==false){
                                              _postText = _postText.substring(0, 200) + "...";
                                            }
                                            else{
                                              _showMorePost[_postID]=true;
                                            }
                                          }
                                          return RichText(
                                            textScaleFactor: MediaQuery.of(_pageContext).textScaleFactor,
                                            text: TextSpan(
                                                children: <TextSpan>[
                                                  TextSpan(
                                                      children: globals.parseTextForLinks(_postText)
                                                  ),
                                                  _showMorePost[_postID] ?
                                                  TextSpan():
                                                  TextSpan(
                                                      text: " read more...",
                                                      recognizer: TapGestureRecognizer()..onTap= (){
                                                        _showMorePost[_postID] = !_showMorePost[_postID];
                                                        _showMorePostCtr.add("kjut");
                                                      }
                                                  )
                                                ]
                                            ),
                                          );
                                        },
                                      )
                                  ), //post text
                                ],
                              ),
                            );
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
  AnimationController _likeAniCtr;
  Animation<double> _likeAni;
  @override
  void initState() {
    super.initState();
    _pageLiBlocks=List();
    getPageContents();
    localInit();

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

    _globalLinkListener= globals.localLinkTrigger.stream;
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      initGlobalLinkNav();
    });
  }//route's init method

  Stream _globalLinkListener;
  initGlobalLinkNav(){
    _globalLinkListener.listen((_data) async{
      Map _locdata= _data;
      if(_locdata["type"] == "atag"){
        try{
          String _link=_locdata["link"].toString().replaceAll("@", "").replaceAll("__kjut__", "").trim();
          http.post(
              globals.globBaseUrl + "?process_as=test_wall_username",
              body: {
                "username": _link
              }
          ).then((_resp){
            if(_resp.statusCode == 200){
              var _respObj= jsonDecode(_resp.body);
              if(_respObj["status"] == "success"){
                try{
                  Navigator.of(_pageContext).push(MaterialPageRoute(
                      builder: (BuildContext _ctx){
                        return WallProfile(_respObj["user_id"], username: _respObj["username"],);
                      }
                  ));
                }
                catch(ex){

                }
              }
            }
          });
        }
        catch(ex){

        }
      }
      else if(_locdata["type"] == "htag"){
        try{
          String _link=_locdata["link"].toString().replaceAll("#", "").replaceAll("__kjut__", "").trim();
          http.post(
              globals.globBaseUrl + "?process_as=test_wall_tag",
              body: {
                "tag": _link
              }
          ).then((_resp){
            if(_resp.statusCode == 200){
              var _respObj= jsonDecode(_resp.body);
              if(_respObj["status"] == "success"){
                try{
                  Navigator.of(_pageContext).push(MaterialPageRoute(
                      builder: (BuildContext _ctx){
                        return WallHashTags(_link);
                      }
                  ));
                }
                catch(ex){

                }
              }
            }
          });
        }
        catch(ex){

        }
      }
    });
  }

  Directory _appDir;
  localInit()async{
    _appDir= await getApplicationDocumentsDirectory();
  }//local Init
  bool _scrollreload=false;
  initLVEvents(){
    _globalListCtr.addListener(() {
      if((_globalListCtr.position.pixels > (_globalListCtr.position.maxScrollExtent -  (_screenSize.height * 1.5))) && _scrollreload == false){
        _scrollreload=true;
        getPageContents();
      }

      //mimic sliver for app bar dp
      if(_profileKey.currentContext!=null){
        RenderBox _profileBox= _profileKey.currentContext.findRenderObject();
        Size _profileSize= _profileBox.size;
        Offset _profileOffset= _profileBox.localToGlobal(Offset.zero);
        if(_profileOffset.dy < -1 * (_profileSize.height - 150)){
          _showBarDP=true;
          _pageLiScrollNotifier.add("kjut");
        }
        else{
          _showBarDP=false;
          _pageLiScrollNotifier.add("kjut");
        }
      }

      //add on scroll play video event
      List<String> _currentlyVisible=List<String>();
      List<String> _fullyVisible=List<String>();
      _wallBlockKeys.forEach((key, value) {
        if(value.currentContext!=null){
          RenderBox _tmpRb= value.currentContext.findRenderObject();
          Size _tmpSize= _tmpRb.size;
          Offset _tmpOffset= _tmpRb.localToGlobal(Offset.zero);
          if(_tmpOffset.dy>(-.5 * _tmpSize.height) && _tmpOffset.dy<_screenSize.height){
            _currentlyVisible.add(key);
          }
          if((_tmpOffset.dy>0) && ((_tmpOffset.dy + _tmpSize.height) < _screenSize.height)){
            _fullyVisible.add(key);
          }
        }
        else {
          //because we are using listview.builder, all elements are not always rendered
          //to save memory, and all that. So, depending on the cache extent that I have requested
          //some of the wall blocks may be nullified at points outside the cache extents
          //that I have specified. This else block takes care of that to avoid errors
        }
      });

      List<String> _visibleVids= List<String>();
      int _countCurVisible= _currentlyVisible.length;
      List<String> _fullyvisibleVids= List<String>();
      String _targKey="";
      for(int _k=0; _k<_countCurVisible; _k++){
        //I'm using a single loop (on the currently visible) for fully visible and currently visible
        //because the fully visible is a sub set of the currently visible
        _targKey= _currentlyVisible[_k];
        String _locCurrentPage= _pvCurPage[_targKey].toString();
        String _localPlayerID= _playerIDMap["$_targKey.$_locCurrentPage"];
        if(_postVideos.containsKey(_localPlayerID)){
          _visibleVids.add(_localPlayerID);
          if(_fullyVisible.indexOf(_targKey)>-1){
            _fullyvisibleVids.add(_localPlayerID);
          }
        }
      }

      String _playVidKey="";
      if(_visibleVids.length<1){
        pauseAllVids();
      }
      else if(_fullyvisibleVids.length>0){
        _playVidKey=_fullyvisibleVids[0];
      }
      else if(_visibleVids.length>2){
        _playVidKey=_visibleVids[1];
      }
      else if(_visibleVids.length>0){
        _playVidKey=_visibleVids[0];
      }
      if(_playVidKey!=""){
        _postVideos.forEach((key, value) {
          if(key!=_playVidKey){
            if(value.value.isPlaying) value.pause();
          }
        });
        if(!_postVideos[_playVidKey].value.isPlaying) {
          _postVideos[_playVidKey].play();
        }
      }
    });
  }//init list view scroll events

  List<String> _bookmarks;
  Future getPageContents()async{
    if(_bookmarks == null){
      _bookmarks= List<String>();
      Database _con= await _dbTables.wallPosts();
      _con.rawQuery("select post_id from wall_posts where book_marked='yes'").then((_result){
        int _kount= _result.length;
        for(int _k=0; _k<_kount; _k++){
          _bookmarks.add(_result[_k]["post_id"]);
        }
      });
    }
    _scrollreload=true;
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
        List _respObj= jsonDecode(_resp.body);
        resetVidPlayer();
        _pageLiBlocks.addAll(_respObj);
        if(_respObj.length>0)_scrollreload=false;
        _pageLiUpdater.add("kjut");
      }
    }
    catch(ex){
      _kjToast.showToast(
        text: "Can request for posts in offline mode",
        duration: Duration(seconds: 3)
      );
    }
  }//get page contents

  BuildContext _pageContext;
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext= context;
    _screenSize=MediaQuery.of(_pageContext).size;
    return WillPopScope(
      child: Scaffold(
        backgroundColor: Color.fromRGBO(32, 32, 32, 1),
        appBar: AppBar(
          backgroundColor: Color.fromRGBO(26, 26, 26, 1),
          title: Text(
              widget.username
          ),
          actions: [
            StreamBuilder(
              stream: _pageLiScrollNotifier.stream,
              builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                if(_userAbout!=null){
                  String _udp= _userAbout["dp"];
                  return AnimatedOpacity(
                    opacity: _showBarDP ? 1 : 0,
                    duration: Duration(milliseconds: 500),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      alignment: Alignment.center,
                      margin: EdgeInsets.only(right: 24),
                      curve: Curves.easeInOut,
                      width: _showBarDP ? 50 : 12, height: _showBarDP ? 50 : 12,
                      child: _udp.length ==  1 ? CircleAvatar(
                        radius: 20,
                        child: Text(
                          _udp.toUpperCase()
                        ),
                      ): CircleAvatar(
                        radius: _showBarDP ? 20 : 2,
                        backgroundImage: NetworkImage(_udp),
                      ),
                    ),
                  );
                }
                return Container();
              },
            )
          ],
        ),
        body: FocusScope(
          child: pageBody(),
          onFocusChange: (bool _isFocused){
            if(_isFocused){
              if(_pageLiBlocks.length>0){
                updatePagePosts();
              }
            }
            else pauseAllVids();
          },
          autofocus: true,
        ),
      ),
      onWillPop: ()async{
        Navigator.pop(context);
        return false;
      },
    );
  }//route's build method

  updatePagePosts()async{
    _userAbout=null;
    fetchWallProfile();
    try {
      List<String> _localpids= List<String>();
      int _kount= _pageLiBlocks.length;
      for(int _k=0; _k<_kount; _k++){
        _localpids.add(
          _pageLiBlocks[_k]["post_id"]
        );
      }
      http.Response _resp= await http.post(
          globals.globBaseUrl + "?process_as=fetch_wall_postids",
        body: {
            "pids": jsonEncode(_localpids)
        }
      );
      if(_resp.statusCode == 200){
        List _respObj= jsonDecode(_resp.body);
        int _kount= _respObj.length;
        for(int _k=0; _k<_kount; _k++){
          String _targPid= _respObj[_k]["post_id"];
          int _pidpos= _localpids.indexOf(_targPid);
          _pageLiBlocks[_pidpos]["post_time"]=_respObj[_k]["post_time"];
          _pageLiBlocks[_pidpos]["comments"]=_respObj[_k]["comments"];
          _pageLiBlocks[_pidpos]["likes"]=_respObj[_k]["likes"];
        }
        _wallLikes=Map<String, List>();
        resetVidPlayer();
        _pageLiUpdater.add("kjut");
      }
    }
    catch(ex){

    }
  }//update page posts

  pauseAllVids(){
    _postVideos.forEach((key, value) {
      if(value.value.initialized && value.value.isPlaying)value.pause();
    });
  }//pause all vids

  StreamController _pageLiScrollNotifier= StreamController.broadcast();
  @override
  void dispose() {
    pullRefreshCtr.close();
    _profileShimmerCtr.close();
    _toastCtr.close();
    _pageLiUpdater.close();
    _wallLikeCtr.close();
    _pageChangeNotifier.close();
    _pageCtrs.forEach((key, value) { value.dispose();});
    _postVideos.forEach((key, value) {
      if(value.value.initialized) value.dispose();
    });
    _vidVolCtrl.close();
    _wallBookedCtr.close();
    _likeAniCtr.dispose();
    _showMorePostCtr.close();
    _pageLiScrollNotifier.close();
    super.dispose();
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
                  _pageLiBlocks=List();
                  getPageContents();
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