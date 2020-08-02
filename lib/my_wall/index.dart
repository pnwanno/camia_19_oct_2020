import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_icons/flutter_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:video_player/video_player.dart';
import 'package:circular_clip_route/circular_clip_route.dart';

import './new_post.dart';
import '../globals.dart' as globals;
import '../dbs.dart';
import './my_profile.dart';
import './post_comments.dart';
import './post_likes.dart';
import './profile.dart';

class MyWall extends StatefulWidget{
  _MyWall createState(){
    return _MyWall();
  }
}


class _MyWall extends State<MyWall> with SingleTickerProviderStateMixin{
  DBTables dbTables=DBTables();
  bool globDlgIsVisible=false;

  globals.KjToast _kjToast;

  Map<String, Map> postPPt= Map<String, Map>();
  
  StreamController dpChangedCtr= StreamController.broadcast();

  ///The scroll controller for the wall's primary list view
  ScrollController wallScrollCtr;
  StreamController pullRefreshCtr= StreamController.broadcast();

  
  likeUnlikePost(String postId)async{
    try{
      Database _con= await dbTables.wallPosts();
      String _likeJson= jsonEncode(wallLikes[postId]);
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
      _kjToast.showToast(
        text: "Like is disabled in offline mode",
        duration: Duration(seconds: 5)
      );
    }
  }//like unlike post

  ///Adds or remove a post from bookmark list of wall posts
  Future bookmarkPost(String _postId)async{
    Database _con= await dbTables.wallPosts();
    _con.rawQuery("select book_marked from wall_posts where post_id=?", [_postId]).then((_queryResult) {
      if(_queryResult.length==1){
        if(_queryResult[0]["book_marked"] == "no"){
          _con.execute("update wall_posts set book_marked='yes' where post_id='$_postId'");
        }
        else{
          _con.execute("update wall_posts set book_marked='no' where post_id='$_postId'");
        }
      }
    });
  }//bookmark post

  Future<bool> postComment(String postId)async{
    if(_wallPostCommentCtr.containsKey(postId)){
      String _url= globals.globBaseUrl + "?process_as=post_wall_comment";
      TextEditingController _targetCtr=_wallPostCommentCtr[postId];
      if(_targetCtr.text == "") return false;
      try{
        String _postText=_targetCtr.text;
        _targetCtr.text="";
        http.Response resp= await http.post(
            _url,
            body: {
              "user_id": globals.userId,
              "post_id": postId,
              "reply_to": "",
              "post_text":_postText
            }
        );
        if(resp.statusCode == 200){
          if(resp.body == "success"){
            fetchPosts(caller: "init");
            return true;
          }
          else{
            _kjToast.showToast(
                text: "Can't comment - It seems you are logged out",
                duration: Duration(seconds: 3)
            );
            return false;
          }
        }
        else{
          _kjToast.showToast(
            text: "Can't comment now - try again later",
            duration: Duration(seconds: 3)
          );
          return false;
        }
      }
      catch(ex){
        _kjToast.showToast(
            text: "Can't comment - Offline mode",
            duration: Duration(seconds: 5)
        );
        return false;
      }
    }
    else return false;
  }

  Map<String, Map> pageViewCtrs=Map<String, Map>();

  int pseudoPgCtrAttach=0;
  var _serverData;
  bool refreshData=true;
  String postPos="0";

  Future<Widget> fetchTrendingHashTags()async{
    try{
      http.Response _resp=await http.post(
          globals.globBaseUrl + "?process_as=fetch_wall_trending_tags"
      );
      if(_resp.statusCode == 200){
        Map _respObj= jsonDecode(_resp.body);
        List<Widget> _liChildren= List<Widget>();
        int _kounter=0;
        _respObj.forEach((key, value) {
          if(_kounter<20){
            _liChildren.add(
                Material(
                  color: Colors.transparent,
                  child: InkResponse(
                    onTap: (){

                    },
                    child: Container(
                      margin: EdgeInsets.only(right: 12),
                      padding: EdgeInsets.only(left:16, right: 16, top: 5, bottom: 5),
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(41, 41, 41, 1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Color.fromRGBO(80, 80, 80, 1)
                        )
                      ),
                      child: Text(
                        globals.kChangeCase(key, globals.KWordcase.sentence_case),
                        style: TextStyle(
                          color: Colors.white
                        ),
                      ),
                    ),
                  ),
                )
            );
          }
          _kounter++;
        });

        return TweenAnimationBuilder(
          tween: Tween<double>(
            begin: 0, end: 1
          ),
          duration: Duration(seconds: 1),
          curve: Curves.easeInOut,
          builder: (BuildContext _ctx, double _curval, _){
            return Opacity(
              opacity: _curval,
              child: Container(
                padding: EdgeInsets.only(top: 9, bottom: 9, left: 24),
                decoration: BoxDecoration(
                    color: Color.fromRGBO(31, 31, 31, 1)
                ),
                width: _screenSize.width, height: 50,
                child: ListView(
                  reverse: true,
                  physics: BouncingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  children: _liChildren,
                ),
              ),
            );
          },
        );
      }
      else return Container();
    }
    catch(ex){
      return Container(

      );
    }
  }


  List<String> imageExts= ["jpg", "png", "gif"];
  List<String> videoExts= ["mp4"];
  Map<String, PageController> wallMediaPageCtr= Map<String, PageController>();
  Map<String, int> _wallPVCurPage= Map<String, int>();
  StreamController pageChangeNotifier= StreamController.broadcast();
  Map<String, VideoPlayerController> wallVideoCtr= Map<String, VideoPlayerController>();
  StreamController _vidVolCtrl= StreamController.broadcast();
  bool _globalMute=true;
  Map<String, List> wallLikes=Map<String, List>();
  StreamController wallLikeCtr= StreamController.broadcast();
  Map<String, bool> showMorePost=Map<String, bool>();
  StreamController showMorePostCtr= StreamController.broadcast();

  Map<String, String> _wallBooked=Map<String, String>();
  StreamController _wallBookedCtr= StreamController.broadcast();
  Map<String, TextEditingController> _wallPostCommentCtr= Map<String, TextEditingController>();


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
                fetchPosts(caller: "init");
              }
            );
          }
        },
        onPointerMove: (PointerMoveEvent pme){
          Offset _delta= pme.delta;
          if(wallScrollCtr.position.atEdge && !_delta.direction.isNegative){
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

  ///Get fresh contents from server or from database
  ///Updates the database with fresh server contents if it exists
  Future<void> refreshWall()async{
    String _url=globals.globBaseUrl + "?process_as=fetch_wall_post";
    try{
      http.Response _resp= await http.post(
        _url,
        body: {
          "user_id": globals.userId,
          "start" : postPos
        }
      );
      if(_resp.statusCode == 200){
        //let's get existing posts
        Database _con= await dbTables.wallPosts();
        var _result= await _con.rawQuery("select post_id from wall_posts where status='complete' and section='following'");
        List<String> _pids=List<String>();
        int _resultCount=_result.length;
        
        for(int _k=0; _k<_resultCount; _k++){
          _pids.add(
            _result[_k]["post_id"]
          );
        }
        var _respObj= jsonDecode(_resp.body);
        int _kount= _respObj.length;
        
        Directory _wallDir= Directory(_appdir.path + "/wall_dir");
        await _wallDir.create();
        Directory _postDir= Directory(_wallDir.path + "/post_media");
        await _postDir.create();
        for(int _k=0; _k<_kount; _k++){
          String _serverImageDir= _respObj[_k]["image_path"];
          var _targPID= _respObj[_k]["post_id"];
          if(_pids.indexOf(_targPID)<0){
            //new post item from server or probably an old post that was not processed to completion due errors - videoplayer error

            //check if this post was not successfully processed the last time
            var _checkPostResult= await _con.rawQuery("select * from wall_posts where post_id='$_targPID' and status='pending'");
            if(_checkPostResult.length>0){
              var _checkPostImages=jsonDecode(_checkPostResult[0]["post_images"]);
              int _checkPostImagesCount= _checkPostImages.length;
              for(int _j=0; _j<_checkPostImagesCount; _j++){
                String _checkPostImagePath= _postDir.path + "/" + _checkPostImages[_j]["file"];
                File _checkPostImageFile=File(_checkPostImagePath);
                _checkPostImageFile.exists().then((_fexists){
                  if(_fexists){
                    _checkPostImageFile.delete();
                  }
                });
              }
              await _con.execute("delete from wall_posts where post_id='$_targPID'");
            }//the post was not fully processed for some reasons

            //check if this post have been saved before but not as 'following' post
            var _checkPostExistsDifferently= await _con.rawQuery("select * from wall_posts where post_id='$_targPID' and status='complete'");
            if(_checkPostExistsDifferently.length == 1) continue;


            var _serverPImages= _respObj[_k]["images"];
            int _imageCount= _serverPImages.length;

            String _jsonPostImages= jsonEncode(_respObj[_k]["images"]);

            String _kita= DateTime.now().millisecondsSinceEpoch.toString();
            String _section="following";
            String _status="pending";
            String _uid=_respObj[_k]["user_id"];
            String _postText=_respObj[_k]["post_text"];
            String _views= jsonEncode(_respObj[_k]["views"]);
            String _time=_respObj[_k]["post_time"];
            String _likes=jsonEncode(_respObj[_k]["likes"]);
            String _comments=jsonEncode(_respObj[_k]["comments"]);
            String _linkTo=_respObj[_k]["link_to"];
            String _bookmarked="no";
            String _mediaServerLoc= _respObj[_k]["image_path"];
            String _postDP=_respObj[_k]["dp"];
            if(_postDP.length>1){
              //A dp length greater than 1 is a link to an actual image in the server
              String _postDPURL="$_postDP";
              List<String> _brkPostDP= _postDP.split("/");
              _postDP= _kita + _brkPostDP.last;
              http.readBytes(_postDPURL).then((_postDPBytesData){
                File(_postDir.path + "/$_postDP").writeAsBytes(_postDPBytesData);
              });
            }
            String _username=_respObj[_k]["username"];
            String _fullname=_respObj[_k]["fullname"];
            _con.execute(
              "insert into wall_posts (post_id, user_id, post_images, post_text, views, time_str, likes, comments, post_link_to, status, book_marked, media_server_loc, dp, username, fullname, section, save_time) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
              [_targPID, _uid, _jsonPostImages, _postText, _views, _time, _likes, _comments, _linkTo, _status, _bookmarked, _mediaServerLoc, _postDP, _username, _fullname, _section, _kita]
            );
            //delete the oldest post if local post count reaches the set threshold
            var _locResult= await _con.rawQuery("select id from wall_posts");
            if(_locResult.length >=_kount){
              var _oldestPostResult= await _con.rawQuery("select * from wall_posts where book_marked='no' order by cast(post_id as signed) asc limit 1");
              if(_oldestPostResult.length == 1){
                  var _oldestPostImages=jsonDecode(_oldestPostResult[0]["post_images"]);
                  int _oldestPostImageCount= _oldestPostImages.length;
                  for(int _u=0; _u<_oldestPostImageCount; _u++){
                    File _oldestPostImage = File(_postDir.path + "/" + _oldestPostImages[_u]["file"]);
                    _oldestPostImage.exists().then((value) {
                      if(value) _oldestPostImage.delete();
                    });
                  }
                  String _oldestPDP= _oldestPostResult[0]["dp"];
                  File _oldestPDPF= File(_postDir.path + "/$_oldestPDP");
                  _oldestPDPF.exists().then((_foundDp){
                    if(_foundDp) _oldestPDPF.delete();
                  });
                  int _oldestPostId= _oldestPostResult[0]["id"];
                  _con.execute("delete from wall_posts where id=?", [_oldestPostId]);
              }
            }

            //now fetch post media from the server for local savings
            for(int _j=0; _j<_imageCount; _j++){
              try{
                String _imageURL=_serverImageDir + "/" + _serverPImages[_j]["file"];
                http.get(_imageURL).then((_resp){
                  if(_resp.statusCode == 200){
                    Uint8List _imageBytes=_resp.bodyBytes;
                    File _localImage= File(_postDir.path + "/" + _serverPImages[_j]["file"]);
                    _localImage.writeAsBytes(_imageBytes).then((_imageByteFile)async{
                      bool _uploadedAll= true;
                      for(int _u=0; _u<_imageCount; _u++){
                        File _checkFile= File(_postDir.path + "/" + _serverPImages[_u]["file"]);
                        _checkFile.exists().then((_fexists){
                          if(!_fexists) _uploadedAll=false;
                          if(_u==_imageCount - 1){
                            if(_uploadedAll){
                              String _newInnerStatus="complete";
                              _con.execute("update wall_posts set status=? where post_id=?", [_newInnerStatus,  _targPID]).then((value){
                                fetchPosts();
                              });
                            }
                          }
                        });
                      }
                    });
                  }
                });
              }
              catch(ex){

              }
            }
          }
          else{
            //update the views and the likes, ...
            String _views= jsonEncode(_respObj[_k]["views"]);
            String _likes=jsonEncode(_respObj[_k]["likes"]);
            String _comments=jsonEncode(_respObj[_k]["comments"]);
            String _postTime=_respObj[_k]["post_time"];
            await _con.execute("update wall_posts set views=?, likes=?, comments=?, time_str=? where post_id=?", [_views, _likes, _comments, _postTime, _targPID]);
            fetchPosts();
          }
        }
      }
      else{
        //server error
      }
    }
    catch(ex){
      _kjToast.showToast(
        text: "Offline mode - get connected for updated contents",
        duration: Duration(seconds: 3)
      );
      return false;
    }
  }//refresh wall

  ///The stream controller for wall list view render changes
  StreamController wallRenderCtr= StreamController.broadcast();

  double pullRefreshHeight=0;
  double pullRefreshLoadHeight=80;
  Future<void> fetchPosts({String caller})async{
    Database con= await dbTables.wallPosts();
    _serverData=await con.rawQuery("select * from wall_posts where status='complete' and section='following' order by cast(post_id as signed) desc");

    if(!wallRenderCtr.isClosed){
      wallRenderCtr.add("kjut");
    }
    if(caller == "init"){
      refreshWall();
    }
  }//fetch posts

  static GlobalKey _newPostKey= GlobalKey();
  BuildContext _pageContext;
  Widget pageBody(){
    return Scaffold(
      backgroundColor: Color.fromRGBO(58, 58, 58, 1),
      bottomNavigationBar:
        Container(
          height: 70,
          padding: (_screenSize.width < 365) ? EdgeInsets.only(left: 22, right: 22) : EdgeInsets.only(left: 32, right: 32),
          decoration: BoxDecoration(
            color: Color.fromRGBO(26, 26, 26, 1)
          ),
          width: MediaQuery.of(_pageContext).size.width,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Container(
                child: Material(
                  color: Colors.transparent,
                  child: InkResponse(
                    onTap: (){

                    },
                    child: Container(
                      width: 60, height: 60,
                      child: Icon(
                        FlutterIcons.home_ant,
                        color: Colors.white,
                        size: 28,
                      ),
                    )
                  ),
                ),
              ),//home button

              Container(
                key: _newPostKey,
                child: Material(
                  color: Colors.transparent,
                  child: InkResponse(
                    onTap: (){
                      Navigator.of(_pageContext).push(CircularClipRoute(
                        expandFrom: _newPostKey.currentContext,
                        builder: (BuildContext _newPostXtx){
                          return NewWallPost();
                        }
                      ));
                    },
                    child: Container(
                      width: 60, height: 60,
                      child: Icon(
                        FlutterIcons.ios_add_circle_ion,
                        color: Colors.white,
                        size: 28,
                      )
                    )
                  ),
                ),
              ),//add post

              Container(
                child: Material(
                  color: Colors.transparent,
                  child: InkResponse(
                    onTap: (){

                    },
                    child: Container(
                      width: 60, height: 60,
                      child: Icon(
                        FlutterIcons.searchengin_faw5d,
                        color: Colors.white,
                        size: 28,
                      ),
                    )
                  ),
                ),
              ),//search

              StreamBuilder(
                stream: dpChangedCtr.stream,
                builder: (BuildContext ctx, AsyncSnapshot snapshot){
                  return _wallDp;
                }
              )
            ],
          ),
        ),//bottom navigation bar
      
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(26, 26, 26, 1),
        title: Container(
          padding: EdgeInsets.only(left:12),
          child: Text(
            "MY WALL",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        )
      ),
      body: FocusScope(
        child: Container(
          child: Stack(
            children: <Widget>[
              Container(
                height: _screenSize.height,
                child: StreamBuilder(
                  stream: wallRenderCtr.stream,
                  builder: (BuildContext _mainctx, AsyncSnapshot _mainshot){
                    return ListView.builder(
                        physics: BouncingScrollPhysics(),
                        controller: wallScrollCtr,
                        cacheExtent: _screenSize.height * 4,
                        itemCount: _mainshot.hasData ? (_serverData.length + 1) : 0,
                        itemBuilder: (BuildContext _mainlvctx, int _mainIndex){
                          if(_mainIndex == 0){
                            return Container(
                              child: Column(
                                children: <Widget>[
                                  pullToRefreshContainer(),
                                  Container(
                                    child:FutureBuilder(
                                      future: fetchTrendingHashTags(),
                                      builder: (BuildContext _ctx, AsyncSnapshot _trendshot){
                                        if(_trendshot.hasData){
                                          return _trendshot.data;
                                        }
                                        else {
                                          return Container(
                                            height: 50, width: _screenSize.width,
                                            padding: EdgeInsets.only(left:24, top: 9, bottom: 9),
                                            decoration: BoxDecoration(
                                              color: Color.fromRGBO(31, 31, 31, 1)
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),//trending tags
                                ],
                              ),
                            );
                          }
                          else{
                            if(_serverData.length > 0){
                              Map _currentBlock=_serverData[_mainIndex - 1];
                              bool _islocal=false;
                              if(_currentBlock.containsKey("section")) _islocal= true;
                              String _postudp=_currentBlock["dp"];
                              String _postDir= _appdir.path + "/wall_dir/post_media";
                              List _postcomments=jsonDecode(_currentBlock["comments"]);
                              String _postId= _currentBlock["post_id"];

                              if(!_wallBlockKeys.containsKey(_postId)){
                                _wallBlockKeys[_postId]=GlobalKey();
                              }

                              if(!wallLikes.containsKey(_postId)){
                                wallLikes[_postId]=jsonDecode(_currentBlock["likes"]);
                              }
                              List _postMedia= jsonDecode(_currentBlock["post_images"]);
                              int _postMediaCount= _postMedia.length;
                              List _brkPostAR=_postMedia[0]["ar"].toString().split("/");
                              double _postAR=double.tryParse(_brkPostAR[0]) / double.tryParse(_brkPostAR[1]);
                              double _postHeight= _screenSize.width * (1/_postAR);

                              List<Widget> _pvChildren= List<Widget>();
                              for(int _k=0; _k<_postMediaCount; _k++){
                                if(_postMedia[_k]["type"] == "video"){
                                  String _tmpPlayerKey="$_postId.$_k";
                                  if(!wallVideoCtr.containsKey("$_tmpPlayerKey")) {
                                    if(_islocal){
                                      wallVideoCtr["$_tmpPlayerKey"] = VideoPlayerController.file(File(_postDir + "/" + _postMedia[_k]["file"]));
                                    }
                                    else{
                                      wallVideoCtr["$_tmpPlayerKey"] = VideoPlayerController.network(_postMedia[_k]["file"]);
                                    }
                                    wallVideoCtr["$_tmpPlayerKey"].initialize().then((value) {
                                      wallVideoCtr["$_tmpPlayerKey"].setVolume(0);
                                      wallVideoCtr["$_tmpPlayerKey"].seekTo(Duration(milliseconds: 500));
                                      wallVideoCtr["$_tmpPlayerKey"].setLooping(true);
                                    });
                                  }
                                  List<String> _brkVAR= _postMedia[_k]["ar"].toString().split("/");
                                  double _mediaVAR= double.tryParse(_brkVAR[0]) / double.tryParse(_brkVAR[1]);

                                  _pvChildren.add(Container(
                                    child: AspectRatio(
                                      aspectRatio: _mediaVAR,
                                      child: VideoPlayer(
                                          wallVideoCtr["$_tmpPlayerKey"]
                                      ),
                                    ),
                                  ));
                                }
                                else{
                                  _pvChildren.add(Container(
                                    width: _screenSize.width,
                                    decoration: BoxDecoration(
                                        image: DecorationImage(
                                            image: (_islocal) ? FileImage(File(_postDir + "/" + _postMedia[_k]["file"])) : NetworkImage(""),
                                            fit: BoxFit.cover,
                                            alignment: Alignment.topCenter
                                        )
                                    ),
                                  ));
                                }
                              }
                              if(!_wallBooked.containsKey(_postId)){
                                if(_islocal){
                                  _wallBooked[_postId]=_currentBlock["book_marked"];
                                }
                                else{
                                  _wallBooked[_postId]="no";
                                }
                              }
                              if(!wallMediaPageCtr.containsKey(_postId)){
                                _wallPVCurPage[_postId]=0;
                                wallMediaPageCtr[_postId]= PageController(initialPage: _wallPVCurPage[_postId], keepPage: true);
                                wallMediaPageCtr[_postId].addListener(() {
                                  double _localCurPage=wallMediaPageCtr[_postId].page;
                                  if(_localCurPage.floor() == _localCurPage){
                                    if(wallMediaPageCtr[_postId].hasClients){
                                      _wallPVCurPage[_postId]=_localCurPage.toInt();
                                    }
                                    pauseAllVids();
                                    String _localVideoKey=_postId + "." + _localCurPage.toInt().toString();
                                    if(wallVideoCtr.containsKey(_localVideoKey)){
                                      wallVideoCtr[_localVideoKey].play();
                                    }
                                    pageChangeNotifier.add("kjut");
                                  }
                                });
                              }

                              if(!showMorePost.containsKey(_postId)){
                                showMorePost[_postId]=false;
                              }

                              return Container(
                                key: _wallBlockKeys[_postId],
                                decoration: BoxDecoration(
                                    color: Color.fromRGBO(32, 32, 32, 1)
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
                                                  Navigator.of(_pageContext).push(
                                                      MaterialPageRoute(
                                                          builder: (BuildContext _ctx){
                                                            return WallProfile(_currentBlock["user_id"], username: _currentBlock["fullname"],);
                                                          }
                                                      )
                                                  );
                                                },
                                                child: Container(
                                                  margin: EdgeInsets.only(right:9),
                                                  child: _postudp.length == 1 ?
                                                  CircleAvatar(
                                                    radius: _screenSize.width < 420 ? 15 : 20,
                                                    child: Text(
                                                      _postudp,
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ):
                                                  CircleAvatar(
                                                    radius: _screenSize.width < 420 ? 15 : 20,
                                                    backgroundImage: _islocal ? FileImage(File("$_postDir/$_postudp")) : NetworkImage(_postudp),
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
                                                              _currentBlock["username"] == "" ? _currentBlock["fullname"] : _currentBlock["username"],
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
                                                              _currentBlock["time_str"],
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
                                                                    return ViewPostedComments(_postId);
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
                                                          stream: wallLikeCtr.stream,
                                                          builder: (BuildContext _likectx, AsyncSnapshot _likeshot){
                                                            return Container(
                                                              child: (wallLikes[_postId].length == 0) ? Container(
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
                                                                        return WallPostLikers(_postId);
                                                                      }
                                                                  ));
                                                                },
                                                                child: Container(
                                                                    child: Text(
                                                                      globals.convertToK(wallLikes[_postId].length) + " likes",
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
                                              controller: wallMediaPageCtr[_postId],
                                              children: _pvChildren,
                                            ),
                                          ),
                                          Positioned(
                                            right: 12, top: 12,
                                            child:  _postMediaCount >1 ? StreamBuilder(
                                              stream:pageChangeNotifier.stream,
                                              builder: (BuildContext _pgnoctx, AsyncSnapshot _pgnoshot){
                                                return Container(
                                                  padding: EdgeInsets.only(top:7, bottom: 7, left: 12, right: 12),
                                                  decoration: BoxDecoration(
                                                    color: Color.fromRGBO(32, 32, 32, 1),
                                                    borderRadius: BorderRadius.circular(7)
                                                  ),
                                                  child: Text(
                                                    (_wallPVCurPage[_postId] + 1).toString() + "/" + _postMediaCount.toString(),
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
                                              stream: pageChangeNotifier.stream,
                                              builder: (BuildContext _isvidctx, AsyncSnapshot _isvidshot){
                                                String _locvidid= "$_postId." + _wallPVCurPage[_postId].toString();
                                                if(wallVideoCtr.containsKey(_locvidid)){
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
                                                            if(_globalMute){
                                                              _globalMute=false;
                                                            }
                                                            else{
                                                              _globalMute=true;
                                                            }
                                                            _vidVolCtrl.add("kjut");
                                                            wallVideoCtr.forEach((key, value) {
                                                              if(_globalMute)value.setVolume(0);
                                                              else value.setVolume(1);
                                                            });
                                                          },
                                                          child: Container(
                                                            width: 24, height: 24,
                                                            child: Icon(
                                                              _globalMute ? FlutterIcons.volume_mute_faw5s : FlutterIcons.volume_up_faw5s,
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
                                          )
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
                                                    stream: wallLikeCtr.stream,
                                                    builder: (BuildContext ctx, AsyncSnapshot snapshot){
                                                      return Material(
                                                        color: Colors.transparent,
                                                        child: InkResponse(
                                                            onTap: (){
                                                              int _ilike=wallLikes[_postId].indexOf(globals.userId);
                                                              if(_ilike>-1){
                                                                wallLikes[_postId].removeAt(_ilike);
                                                              }
                                                              else{
                                                                wallLikes[_postId].add(globals.userId);
                                                              }
                                                              likeUnlikePost(_postId);
                                                              wallLikeCtr.add("kjut");
                                                            },
                                                            child: wallLikes[_postId].indexOf(globals.userId)>-1 ?
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
                                                          return ViewPostedComments(_postId);
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
                                                stream: pageChangeNotifier.stream,
                                                builder: (BuildContext _dotctx, AsyncSnapshot _dotshot){
                                                  List<Widget> _dots= List<Widget>();
                                                  for(int _k=0; _k<_postMediaCount; _k++){
                                                    int _curpage=_wallPVCurPage[_postId];
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
                                                  if(_postMediaCount == 1){
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
                                                    bookmarkPost(_postId);
                                                    if(_wallBooked[_postId] == "yes") _wallBooked[_postId]="no";
                                                    else _wallBooked[_postId]="yes";
                                                    _wallBookedCtr.add("kjut");
                                                  },
                                                  child: Container(
                                                    width: 24, height: 24,
                                                    child: Icon(
                                                      (_wallBooked[_postId] == "yes") ? FlutterIcons.bookmark_faw : FlutterIcons.bookmark_o_faw,
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
                                        stream: showMorePostCtr.stream,
                                        builder: (BuildContext _moreCtx, AsyncSnapshot _moreshot){
                                          String _postText=_currentBlock["post_text"];
                                          if(_screenSize.width<420){
                                            if(_postText.length > 90 && showMorePost[_postId] == false){
                                              _postText = _postText.substring(0, 90) + "...";
                                            }
                                            else{
                                              showMorePost[_postId]=true;
                                            }
                                          }
                                          else{
                                            if(_postText.length > 200 && showMorePost[_postId]==false){
                                              _postText = _postText.substring(0, 200) + "...";
                                            }
                                            else{
                                              showMorePost[_postId]=true;
                                            }
                                          }
                                          return RichText(
                                            text: TextSpan(
                                              children: <TextSpan>[
                                                TextSpan(
                                                  children: globals.parseTextForLinks(_postText)
                                                ),
                                                showMorePost[_postId] ?
                                                TextSpan():
                                                TextSpan(
                                                    text: " read more...",
                                                    recognizer: TapGestureRecognizer()..onTap= (){
                                                      showMorePost[_postId] = !showMorePost[_postId];
                                                      showMorePostCtr.add("kjut");
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
                            else{
                              return Container(
                                width: _screenSize.width, height: _screenSize.height - 50,
                                alignment: Alignment.center,
                                child: CircularProgressIndicator(),
                              );
                            }
                          }
                        }
                    );
                  },
                ),
              ),//the page's actual content

              _kjToast
            ],
          ),
        ),//page container,
        autofocus: true,
        onFocusChange: (bool _isFocused){
          if(_isFocused){
            //capturing only when focus is gained
            if(_serverData!=null){
              initLocalWallDir();
              fetchPosts(caller: "init");
            }
          }
        },
      ),
      
    );
  }//pagebody
  StreamController toastCtrl=StreamController.broadcast();

  ///Convenient method to pause all playing videos
  pauseAllVids(){
    wallVideoCtr.forEach((key, value) {
      if(value.value.isPlaying) value.pause();
    });
  }


  final Map<String, GlobalKey> _wallBlockKeys= Map<String, GlobalKey>();
  AnimationController _likeAniCtr;
  Animation<double> _likeAni;
  @override
  void initState() {
    super.initState();
    wallScrollCtr= ScrollController();

    fetchPosts(caller: "init");
    initLocalWallDir();

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
  }//route's init state

  initLVEvents(){
    wallScrollCtr.addListener(() {
      List<String> _currentlyVisible=List<String>();
      _wallBlockKeys.forEach((key, value) {
        if(value.currentContext!=null){
          RenderBox _tmpRb= value.currentContext.findRenderObject();
          Size _tmpSize= _tmpRb.size;
          Offset _tmpOffset= _tmpRb.localToGlobal(Offset.zero);
          //if(_tmpOffset.dy>0 && (_tmpOffset.dy + _tmpSize.height)< _screenSize.height){
          if(_tmpOffset.dy>(-.5 * _tmpSize.height) && _tmpOffset.dy<_screenSize.height){
            _currentlyVisible.add(key);
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
      String _targKey="";
      for(int _k=0; _k<_countCurVisible; _k++){
        _targKey= _currentlyVisible[_k];
        String _locCurrentPage= _wallPVCurPage[_targKey].toString();
        if(wallVideoCtr.containsKey("$_targKey.$_locCurrentPage")){
          _visibleVids.add("$_targKey.$_locCurrentPage");
        }
      }
      if(_visibleVids.length<1){
        pauseAllVids();
      }
      if(_visibleVids.length>2){
        String _vidKey=_visibleVids[1];
        wallVideoCtr.forEach((key, value) {
          if(key!=_vidKey){
            if(value.value.isPlaying) value.pause();
          }
        });
        if(!wallVideoCtr[_vidKey].value.isPlaying)
          wallVideoCtr[_vidKey].play();
      }
      else if(_visibleVids.length>0){
        String _vidKey=_visibleVids[0];
        wallVideoCtr.forEach((key, value) {
          if(key!=_vidKey){
            if(value.value.isPlaying) value.pause();
          }
        });
        if(!wallVideoCtr[_vidKey].value.isPlaying)
          wallVideoCtr[_vidKey].play();
      }
    });
  }

  Directory _appdir;
  Widget _wallDp= Container();
  initLocalWallDir()async{
    if(_appdir == null){
      _appdir= await getApplicationDocumentsDirectory();
      Directory wallDir= Directory(_appdir.path + "/wall_dir");
      await wallDir.create();

      _wallDp= Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: (){
            Navigator.of(_pageContext).push(MaterialPageRoute(
              builder: (BuildContext ctx){
                return MyWallProfile();
              }
            ));
          },
          child: Container(
            child: CircleAvatar(
              radius: 20,
              child: Text(
                globals.fullname.substring(0,1)
              ),
            ),
          ),
        ),
      );
    }

    Database con= await dbTables.myProfileCon();
    var _result= await con.rawQuery("select * from user_profile where status='active'");
    if(_result.length==1){
      var _rw= _result[0];
      String _dppath= _appdir.path + "/wall_dir/" + _rw["dp"];
      File _walldpF= File(_dppath);
       if(await _walldpF.exists()){
         _wallDp= Material(
            color: Colors.transparent,
            child: InkResponse(
              onTap: (){
                Navigator.of(_pageContext).push(MaterialPageRoute(
                  builder: (BuildContext ctx){
                    return MyWallProfile();
                  }
                ));
              },
              child: Container(
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: FileImage(_walldpF),
                ),
              ),
            ),
          );
       }
    }
    else{
      //create a new local profile
      String upStattus="active";
      String upname="";
      String profiledp="", upbrief="", upwebsite="", uppostcount="0", upfollower="0", upfollowing="0";
      String uprofileWebsiteTitle="", uprofileWebsiteDescription="";
      con.execute("insert into user_profile (username, dp, website, brief, post_count, follower, following, website_title, website_description, status) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",[upname, profiledp, upwebsite, upbrief, uppostcount, upfollower, upfollowing, uprofileWebsiteTitle, uprofileWebsiteDescription, upStattus]);
    }
    dpChangedCtr.add("kjut");

    Directory _postDir= Directory(_appdir.path + "/wall_dir"+ "/post_media");
    await _postDir.create();
    //clear old 'cached' data
    int _kita= DateTime.now().millisecondsSinceEpoch;
    int _expire= _kita - 3600000;
    Database _con= await dbTables.wallPosts();
    var _r=await _con.rawQuery("select * from wall_posts where section <> 'following' and cast(save_time as signed)<?", [_expire]);
    int _kount= _r.length;
    for(int _k=0; _k<_kount; _k++){
      List _imgs= jsonDecode(_r[_k]["post_images"]);
      int _imgCount=_imgs.length;
      for(int _j; _j<_imgCount; _j++){
        File _imgF= File(_postDir.path + "/${_imgs[_j]}");
        _imgF.exists().then((_exists) {
          if(_exists) _imgF.delete();
        });
      }

      String _dp=_r[_k]["dp"];
      int _id= _r[_k]["id"];
      File _dpF= File(_postDir.path + "/$_dp");
      _dpF.exists().then((_exists) {
        if(_exists) _dpF.delete();
      });
      _con.execute("delete from wall_posts where id=?", [_id]);
    }
  }//init local wall dir

  Size _screenSize;
  double _globalFontSize;
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize= MediaQuery.of(_pageContext).size;
    if(_screenSize.width> 420) _globalFontSize=14;
    else _globalFontSize=13;
    if(_kjToast==null){
      _kjToast=globals.KjToast(_globalFontSize, _screenSize, toastCtrl, _screenSize.height * .4);
    }
    return WillPopScope(
      child: MaterialApp(
        home: pageBody(),
      ),
      onWillPop: ()async{
        if(globDlgIsVisible){
          globDlgIsVisible=false;
        }
        else{
          Navigator.of(_pageContext).pop();
        }
        return false;
      }
    );
  }//page build method

  ///Closes all stream controllers
  closeAllStream(){
    dpChangedCtr.close();
    wallRenderCtr.close();
    pullRefreshCtr.close();
    wallLikeCtr.close();
    toastCtrl.close();
    pageChangeNotifier.close();
    showMorePostCtr.close();
    _wallBookedCtr.close();
    _vidVolCtrl.close();
  }//close all stream

  @override
  void dispose() {
    closeAllStream();
    wallScrollCtr.dispose();
    wallMediaPageCtr.forEach((key, value) {
      value.dispose();
    });
    wallVideoCtr.forEach((key, value) {
      if(value.value.isPlaying){
        value.pause();
      }
      value.dispose();
    });
    _wallPostCommentCtr.forEach((key, value) {
      value.dispose();
    });
    _likeAniCtr.stop();
    _likeAniCtr.dispose();
    super.dispose();
  }//route's init state
}