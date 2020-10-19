import 'dart:convert';
import 'dart:io';
import 'dart:async';
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
import 'package:liquid_progress_indicator/liquid_progress_indicator.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import './new_post.dart';
import '../globals.dart' as globals;
import '../dbs.dart';
import './edit_profile.dart';
import './post_comments.dart';
import './post_likes.dart';
import './profile.dart';
import './wall_hash.dart';
import './wall_search.dart';

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

    }
  }//like unlike post


  Future followUnfollowUser(String _reqId, int _itemIndex)async{
    _followSuggestions.removeAt(_itemIndex);
    _suggestionLiKey.currentState.removeItem(_itemIndex,
            (context, animation) {
          return SlideTransition(
            position: animation.drive(Tween<Offset>(begin: Offset.zero, end: Offset.zero)),
          );
        }
    );
    try{
      http.post(
          globals.globBaseUrl + "?process_as=follow_unfollow_wall_user",
          body: {
            "user_id": globals.userId,
            "req_id": _reqId
          }
      ).then((_resp)async{
        if(_resp.statusCode == 200){
          Database _con= await dbTables.wallPosts();
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
  }//follow unfollow user

  //this variable helps to keep track of posts that were downloaded
  // because they were bookmarked by the user -
  // this variable is important because the process of download will take a while and we do not want
  //same post to be bookmarked multiple times before its download is completed
  List<String> _downloadedBookmarks= List<String>();
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
      else{
        if(_downloadedBookmarks.indexOf(_postId)<0){
          _downloadedBookmarks.add(_postId);
          //post have not been downloaded yet so we download it
          int _kount= _serverData.length;
          for(int _k=0; _k<_kount; _k++){
            Map _targMap=_serverData[_k];
            if(_targMap["post_id"] == _postId){
              String _kita= DateTime.now().millisecondsSinceEpoch.toString();
              String _targDPPath= _targMap["dp"];
              List<String> _brkDP= _targDPPath.split("/");
              String _targDP= _brkDP.last;
              String _localDP= _kita + _targDP;
              File _dPF= File(_appdir.path + "/wall_dir/post_media/$_localDP");
              if(_targDPPath.length>1){
                http.readBytes(_targDPPath).then((_dpBytes) {
                  _dPF.writeAsBytes(_dpBytes);
                });
              }
              String _mediaServerLoc=_targMap["image_path"];
              String _postMediaJson=_targMap["post_images"];
              _con.execute("insert into wall_posts (post_id, user_id, post_images, post_text, views, time_str, likes, comments, post_link_to, status, book_marked, media_server_loc, dp, username, fullname, section, save_time) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [
                _targMap["post_id"],
                _targMap["user_id"],
                _postMediaJson,
                _targMap["post_text"],
                _targMap["views"],
                _targMap["time_str"],
                _targMap["likes"],
                _targMap["comments"],
                _targMap["post_link_to"],
                "complete", "yes",
                _mediaServerLoc,
                _localDP,
                _targMap["username"],
                _targMap["fullname"],
                "following", _kita
              ]);
              //save the post media
              List _postMedia= jsonDecode(_postMediaJson);
              int _mediacount= _postMedia.length;
              for(int _j=0; _j<_mediacount; _j++) {
                String _targMedia=_postMedia[_j]["file"];
                http.readBytes("$_mediaServerLoc/$_targMedia").then((_fbytes) {
                  File _mediaF= File(_appdir.path + "/wall_dir/post_media/$_targMedia");
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

  Map<String, Map> pageViewCtrs=Map<String, Map>();

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
                      Navigator.of(_pageContext).push(
                          MaterialPageRoute(
                              builder: (BuildContext _ctx){
                                return WallHashTags(key);
                              }
                          )
                      );
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
  }//fetch trending hashtags

  List _followSuggestions= List();
  StreamController _fsuggestNotifier= StreamController.broadcast();
  ScrollController _suggestionListCtr= ScrollController();
  bool _loadingSuggestions= false;
  final GlobalKey<AnimatedListState> _suggestionLiKey= GlobalKey<AnimatedListState>();
  fetchFSuggestions()async{
    _loadingSuggestions=true;
    try{
      http.Response _resp= await http.post(
          globals.globBaseUrl + "?process_as=wall_user_suggest",
          body: {
            "user_id": globals.userId,
            "current_uids": jsonEncode(_followSuggestions)
          }
      );
      if(_resp.statusCode == 200){
        List _respObj= jsonDecode(_resp.body);
        if(_respObj.length>0){
          _loadingSuggestions=false;
          _followSuggestions.addAll(_respObj);
          _fsuggestNotifier.add("kjut");
        }
      }
    }
    catch(ex){
      _loadingSuggestions=false;
    }
  }

  List<String> imageExts= ["jpg", "png", "gif"];
  List<String> videoExts= ["mp4"];
  Map<String, PageController> wallMediaPageCtr= Map<String, PageController>();
  Map<String, int> _wallPVCurPage= Map<String, int>();
  StreamController pageChangeNotifier= StreamController.broadcast();
  Map<String, VideoPlayerController> wallVideoCtr= Map<String, VideoPlayerController>();
  Map<String, String> _playerIDMap= Map<String, String>();
  StreamController _vidVolCtrl= StreamController.broadcast();
  Map<String, List> wallLikes=Map<String, List>();
  StreamController wallLikeCtr= StreamController.broadcast();
  Map<String, bool> showMorePost=Map<String, bool>();
  StreamController showMorePostCtr= StreamController.broadcast();

  Map<String, String> _wallBooked=Map<String, String>();
  StreamController _wallBookedCtr= StreamController.broadcast();



  ///Get fresh contents from server or from database
  ///Updates the database with fresh server contents if it exists
  Future<void> refreshWall()async{
    String _url=globals.globBaseUrl + "?process_as=fetch_wall_post";
    try{
      http.Response _resp= await http.post(
          _url,
          body: {
            "user_id": globals.userId,
            "exclude": jsonEncode(_existingPids)
          }
      );
      if(_resp.statusCode == 200){
        //let's get existing posts
        Database _con= await dbTables.wallPosts();
        int _newestPID=0;
        //get the newest post in the local database by getting the post with the highest post_id from the server
        var _locResult=await  _con.rawQuery("select post_id from wall_posts order by cast(post_id as signed) desc limit 1");
        if(_locResult.length == 1){
          _newestPID= int.tryParse(_locResult[0]["post_id"]);
        }
        var _respObj= jsonDecode(_resp.body);
        int _kount= _respObj.length;
        for(int _k=0; _k<_kount; _k++){
          String _serverImageDir= _respObj[_k]["image_path"];
          int _targPID= int.tryParse(_respObj[_k]["post_id"]);
          if(_targPID > _newestPID){
            _scrollreload=true; //prevent the page from fetching more content from the server while it is about saving the already fetched data

            //new post item from server or probably an old post that was not processed to completion due errors - videoplayer error
            //check if this post have been saved before where media has been completely downloaded or not, skip because the media is likely still being downloaded
            var _checkPostExistsDifferently= await _con.rawQuery("select * from wall_posts where post_id='$_targPID'");
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
              //A dp length greater than 1 is a link to an actual image on the server
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
            var _locResult= await _con.rawQuery("select id from wall_posts where book_marked='no'");
            if(_locResult.length >=_kount && _kount>20){
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
        }
        _scrollreload=false;
        //update existing posts
        List<String> _locexistingpids= List<String>();
        var _locpidResult= await _con.rawQuery("select post_id from wall_posts where section='following'");
        int _locpidresultlen= _locpidResult.length;
        for(int _u=0; _u< _locpidresultlen; _u++){
          _locexistingpids.add(_locpidResult[_u]["post_id"]);
        }
        http.post(
            globals.globBaseUrl + "?process_as=fetch_wall_postids",
            body: {
              "pids": jsonEncode(_locexistingpids)
            }
        ).then((_serverresponse)async{
          if(_serverresponse.statusCode == 200){
            List _respData= jsonDecode(_serverresponse.body);
            int _datacount= _respData.length;
            Database _innercon= await dbTables.wallPosts();
            for(int _u=0; _u<_datacount; _u++){
              //update the views and the likes, ...
              String _views= jsonEncode(_respData[_u]["views"]);
              String _likes=jsonEncode(_respData[_u]["likes"]);
              String _comments=jsonEncode(_respData[_u]["comments"]);
              String _postTime=_respData[_u]["post_time"];
              String _locpid=_respData[_u]["post_id"];
              await _innercon.execute("update wall_posts set views=?, likes=?, comments=?, time_str=? where post_id=?", [_views, _likes, _comments, _postTime, _locpid]);
            }
            fetchPosts();
          }
        });
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
  List<Map> _serverData= List<Map>();
  List<String> _existingPids= List<String>();
  Future<void> fetchPosts({String caller})async{
    Database con= await dbTables.wallPosts();
    var _localResult=await con.rawQuery("select * from wall_posts where status='complete' and section='following' order by cast(post_id as signed) desc limit 20");
    String _views, _likes, _comments, _postTime, _targpid;
    int _kount= _localResult.length;
    bool _appendPid=true;
    if(_existingPids.length>0) _appendPid=false; //if we already have posts in the array the prepend to it instead of append
    for(int _k=0; _k<_kount; _k++){
      Map _row={};
      bool _newpid=false;
      _localResult[_k].forEach((key, value) {
        if(key == "post_id" && _existingPids.indexOf(value)<0){
          if(_appendPid) _existingPids.add(value);
          else _existingPids.insert(0, value);
          _newpid=true;
        }
        if(key == "post_id") _targpid= value;

        _row["$key"]= "$value";
        if(key == "views") _views= value;
        if(key == "likes") _likes= value;
        if(key == "comments") _comments= value;
        if(key == "time_str") _postTime= value;
      });
      if(_newpid){
        if(_appendPid) _serverData.add(_row);
        else _serverData.insert(0, _row);
      }
      else{
        int _itempos=_existingPids.indexOf(_targpid);
        _serverData[_itempos]["views"]= _views;
        _serverData[_itempos]["likes"]= _likes;
        _serverData[_itempos]["comments"]= _comments;
        _serverData[_itempos]["time_str"]= _postTime;
      }
    }
    _scrollreload=false;
    if(!wallRenderCtr.isClosed){
      resetVidPlayer();
      wallRenderCtr.add("kjut");
    }
    if(caller == "init"){
      refreshWall();
    }
  }//fetch posts

  List<String> _displayingADs= List<String>();
  Map<String, String> _adBlocksMap= Map<String, String>();
  bool _fetchingAd= false;
  List<int> _adBlocks=List<int>();

  fetchWallAD()async{
    if(_fetchingAd == false && _adBlocks.length>0){
      _fetchingAd=true;
      try{
        http.Response _resp= await http.post(
            globals.globBaseUrl + "?process_as=fetch_wall_ad",
            body: {
              "user_id": globals.userId,
              "current_ads": jsonEncode(_displayingADs)
            }
        );
        if(_resp.statusCode == 200){
          String _respbody= _resp.body;
          if(_respbody!=""){
            int _kount= _adBlocks.length;
            bool _foundEmpty=false;
            for(int _k=0; _k<_kount; _k++){
              String _targIndex= _adBlocks[_k].toString();
              if(!_adBlocksMap.containsKey(_targIndex)){
                _adBlocksMap[_targIndex]= _respbody;
                _foundEmpty=true;
                _adAvailableNotifier.add("kjut");
              }
              if(_foundEmpty && _adBlocksMap.containsKey(_targIndex) == false){
                fetchWallAD();
                break;
              }
            }
          }
        }
      }
      catch(ex){
        _fetchingAd=false;
      }
    }
  }//fetch wall ad

  bool _resetting=false;
  resetVidPlayer(){
    if(_resetting == false){
      _resetting=true;
      wallVideoCtr.forEach((key, value) async{
        await value.pause();
        await value.dispose();
      });
      wallVideoCtr= Map<String, VideoPlayerController>();
      _playerIDMap= Map<String, String>();
      setState(() {
        resetVidPlayer();
      });
    }
    else{
      _resetting=false;
      setState(() {

      });
    }
  }//reset video player

  static GlobalKey _newPostKey= GlobalKey();

  BuildContext _pageContext;
  Widget pageBody(){
    return Scaffold(
      backgroundColor: Color.fromRGBO(32, 32, 32, 1),
      bottomNavigationBar: Container(
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
                      Navigator.of(_pageContext).push(MaterialPageRoute(

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
                      Navigator.push(_pageContext, MaterialPageRoute(
                          builder: (BuildContext _ctx){
                            return WallSearch();
                          }
                      ));
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
                    if(_resetting){
                      return Container(
                        alignment: Alignment.center,
                        width: _screenSize.width,
                        height: _screenSize.height,
                        child: CircularProgressIndicator(),
                      );
                    }
                    else if(_serverData.length < 1){
                      return Container(
                        alignment: Alignment.center,
                        width: _screenSize.width,
                        height: _screenSize.height,
                        child: CircularProgressIndicator(),
                      );
                    }
                    return ListView.builder(
                        physics: BouncingScrollPhysics(),
                        controller: wallScrollCtr,
                        cacheExtent: _screenSize.height * 7,
                        itemCount: _serverData.length + 1,
                        itemBuilder: (BuildContext _mainlvctx, int _mainIndex){
                          if(_mainIndex == 0){
                            return Container(
                              child: Column(
                                children: <Widget>[
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
                              Map _currentBlock;
                              bool _pendingPost=false;
                              if(_mainIndex == 1 && globals.wallPostData["state"] == "active"){
                                _currentBlock= {
                                  "dp": globals.fullname.substring(0,1),
                                  "post_id": "-1",
                                  "user_id": globals.userId,
                                  "post_text": globals.wallPostData["text"],
                                  "views": "[]",
                                  "comments": "[]",
                                  "likes": "[]",
                                  "username": globals.fullname,
                                  "fullname" : globals.fullname,
                                  "time_str" : globals.wallPostData["title"],
                                  "link_to": "",
                                  "post_images": globals.wallPostData["media"],
                                  "section": "following"
                                };
                                _pendingPost=true;
                              }
                              else _currentBlock=_serverData[_mainIndex - 1];
                              bool _islocal=false;
                              if(_currentBlock.containsKey("section")) _islocal= true;
                              String _postudp=_currentBlock["dp"];
                              String _postDir;
                              if(_pendingPost){
                                _postDir=_appdir.path + "/wall_dir/tmp";
                              }
                              else{
                                _postDir=_appdir.path + "/wall_dir/post_media";
                              }
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
                              List _brkPostAR;
                              if(_pendingPost){
                                String _locAR="4/3";
                                _brkPostAR=_locAR.split("/");
                              }
                              else{
                                _brkPostAR=_postMedia[0]["ar"].toString().split("/");
                              }
                              double _postAR=double.tryParse(_brkPostAR[0]) / double.tryParse(_brkPostAR[1]);
                              double _postHeight= _screenSize.width * (1/_postAR);

                              List<Widget> _pvChildren= List<Widget>();
                              for(int _k=0; _k<_postMediaCount; _k++){
                                if(_postMedia[_k]["type"] == "video"){
                                  String _tmpPlayerID="$_postId.$_k";
                                  if(!_playerIDMap.containsKey(_tmpPlayerID)){
                                    _playerIDMap[_tmpPlayerID]= DateTime.now().microsecondsSinceEpoch.toString() + "$_k";
                                    String _tryKey=_playerIDMap[_tmpPlayerID];
                                    while(wallVideoCtr.containsKey(_tryKey)){
                                      _playerIDMap[_tmpPlayerID]= DateTime.now().microsecondsSinceEpoch.toString() + "$_k";
                                      _tryKey=_playerIDMap[_tmpPlayerID];
                                    }
                                  }
                                  String _tmpPlayerKey=_playerIDMap[_tmpPlayerID];
                                  List<String> _brkVAR;
                                  if(_pendingPost){
                                    String _locAR="4/3";
                                    _brkVAR= _locAR.split("/");
                                  }
                                  else{
                                    _brkVAR= _postMedia[_k]["ar"].toString().split("/");
                                  }
                                  double _mediaVAR= double.tryParse(_brkVAR[0]) / double.tryParse(_brkVAR[1]);

                                  try{
                                    if(_islocal){
                                      if(_pendingPost){
                                        wallVideoCtr["$_tmpPlayerKey"] = VideoPlayerController.file(File( _postMedia[_k]["path"]));
                                      }
                                      else{
                                        wallVideoCtr["$_tmpPlayerKey"] = VideoPlayerController.file(File(_postDir + "/" + _postMedia[_k]["file"]));
                                      }
                                      wallVideoCtr["$_tmpPlayerKey"].initialize().then((value) {
                                        if(globals.globalWallVideoMute){
                                          wallVideoCtr["$_tmpPlayerKey"].setVolume(0);
                                        }
                                        else wallVideoCtr["$_tmpPlayerKey"].setVolume(1);
                                        wallVideoCtr["$_tmpPlayerKey"].seekTo(Duration(milliseconds: 500));
                                        wallVideoCtr["$_tmpPlayerKey"].setLooping(true);
                                      });
                                      _pvChildren.add(Container(
                                        alignment: Alignment.center,
                                        child: AspectRatio(
                                          aspectRatio: _mediaVAR,
                                          child: VideoPlayer(
                                              wallVideoCtr["$_tmpPlayerKey"]
                                          ),
                                        ),
                                      ));
                                    }
                                    else{
                                      String _mediaserverpath=_currentBlock["image_path"];
                                      _pvChildren.add(
                                          FutureBuilder(
                                            future: DefaultCacheManager().getSingleFile(_mediaserverpath + "/" + _postMedia[_k]["file"]),
                                            builder: (BuildContext _ctx, AsyncSnapshot _vidshot){
                                              if(_vidshot.hasData){
                                                //dispose old video player and create a new one here
                                                if(wallVideoCtr.containsKey(_tmpPlayerKey)){
                                                  wallVideoCtr["$_tmpPlayerKey"].dispose();
                                                  wallVideoCtr.remove(_tmpPlayerKey);
                                                }
                                                _playerIDMap[_tmpPlayerID]= DateTime.now().millisecondsSinceEpoch.toString() + "$_k";
                                                _tmpPlayerKey=_playerIDMap[_tmpPlayerID];
                                                wallVideoCtr["$_tmpPlayerKey"] = VideoPlayerController.file(_vidshot.data);
                                                wallVideoCtr["$_tmpPlayerKey"].initialize().then((value){
                                                  wallVideoCtr["$_tmpPlayerKey"].setLooping(true);
                                                  if(globals.globalWallVideoMute) wallVideoCtr["$_tmpPlayerKey"].setVolume(0);
                                                  else wallVideoCtr["$_tmpPlayerKey"].setVolume(1);
                                                  pageChangeNotifier.add("kjut");
                                                });
                                                return Container(
                                                  child: AspectRatio(
                                                    aspectRatio: _mediaVAR,
                                                    child: VideoPlayer(
                                                        wallVideoCtr["$_tmpPlayerKey"]
                                                    ),
                                                  ),
                                                );
                                              }
                                              wallVideoCtr["$_tmpPlayerKey"] = VideoPlayerController.network(_mediaserverpath + "/" + _postMedia[_k]["file"]);
                                              wallVideoCtr["$_tmpPlayerKey"].initialize().then((value){
                                                wallVideoCtr["$_tmpPlayerKey"].setLooping(true);
                                                if(globals.globalWallVideoMute) wallVideoCtr["$_tmpPlayerKey"].setVolume(0);
                                                else wallVideoCtr["$_tmpPlayerKey"].setVolume(1);
                                                pageChangeNotifier.add("kjut");
                                              });
                                              return Container(
                                                child: AspectRatio(
                                                  aspectRatio: _mediaVAR,
                                                  child: VideoPlayer(
                                                      wallVideoCtr[_tmpPlayerKey]
                                                  ),
                                                ),
                                              );
                                            },
                                          )
                                      );
                                    }
                                  }
                                  catch(ex){
                                    Future.delayed(
                                        Duration(seconds: 3),
                                            (){
                                          resetVidPlayer();
                                        }
                                    );
                                  }
                                }
                                else{
                                  String _imgLoc;
                                  if(_pendingPost){
                                    _imgLoc= _postMedia[_k]["path"];
                                  }
                                  else _imgLoc= _postDir + "/" + _postMedia[_k]["file"];
                                  if(_islocal || _pendingPost){
                                    _pvChildren.add(Container(
                                      width: _screenSize.width,
                                      decoration: BoxDecoration(
                                          image: DecorationImage(
                                              image: FileImage(File(_imgLoc)),
                                              fit: BoxFit.cover,
                                              alignment: Alignment.topCenter
                                          )
                                      ),
                                    ));
                                  }
                                  else{
                                    String _mediaserverpath=_currentBlock["image_path"];
                                    _pvChildren.add(FutureBuilder(
                                      future: DefaultCacheManager().getSingleFile(_mediaserverpath + "/" + _postMedia[_k]["file"]),
                                      builder: (BuildContext _ctx, AsyncSnapshot _imageshot){
                                        if(_imageshot.hasData){
                                          return Container(
                                            width: _screenSize.width,
                                            decoration: BoxDecoration(
                                                image: DecorationImage(
                                                    image: FileImage(_imageshot.data),
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
                                                  image: NetworkImage(_mediaserverpath + "/" + _postMedia[_k]["file"]),
                                                  fit: BoxFit.cover,
                                                  alignment: Alignment.topCenter
                                              )
                                          ),
                                        );
                                      },
                                    ));
                                  }
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
                                wallMediaPageCtr[_postId]= PageController();
                                wallMediaPageCtr[_postId].addListener(() {
                                  double _localCurPage=wallMediaPageCtr[_postId].page;
                                  if(_localCurPage.floor() == _localCurPage){
                                    if(wallMediaPageCtr[_postId].hasClients){
                                      _wallPVCurPage[_postId]=_localCurPage.toInt();
                                    }
                                    pauseAllVids();
                                    String _localVideoID=_postId + "." + _localCurPage.toInt().toString();
                                    String _localVideoKey=_playerIDMap[_localVideoID];
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

                              Widget _liBlock=Container(
                                key: _wallBlockKeys[_postId],
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
                                                            child: GestureDetector(
                                                              onTap:(){
                                                                Navigator.of(_pageContext).push(
                                                                    MaterialPageRoute(
                                                                        builder: (BuildContext _ctx){
                                                                          return WallProfile(_currentBlock["user_id"], username: _currentBlock["fullname"],);
                                                                        }
                                                                    )
                                                                );
                                                              },
                                                              child: Text(
                                                                _currentBlock["username"] == "" ? _currentBlock["fullname"] : _currentBlock["username"],
                                                                style: TextStyle(
                                                                    color: Colors.grey
                                                                ),
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
                                                            child: _pendingPost ? StreamBuilder(
                                                              stream:globals.globalWallPostCtr.stream,
                                                              builder: (BuildContext _gctx, AsyncSnapshot _globpendingshot){
                                                                return Text(
                                                                  _currentBlock["time_str"],
                                                                  style: TextStyle(
                                                                      color: Colors.grey
                                                                  ),
                                                                );
                                                              },
                                                            ): Text(
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
                                                String _locvidkey=_playerIDMap[_locvidid];
                                                if(wallVideoCtr.containsKey(_locvidkey)){
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
                                                            wallVideoCtr.forEach((key, value) {
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
                                                    stream: wallLikeCtr.stream,
                                                    builder: (BuildContext ctx, AsyncSnapshot snapshot){
                                                      return Material(
                                                        color: Colors.transparent,
                                                        child: InkResponse(
                                                            onTap: (){
                                                              if(!_pendingPost){
                                                                int _ilike=wallLikes[_postId].indexOf(globals.userId);
                                                                if(_ilike>-1){
                                                                  wallLikes[_postId].removeAt(_ilike);
                                                                }
                                                                else{
                                                                  wallLikes[_postId].add(globals.userId);
                                                                }
                                                                likeUnlikePost(_postId);
                                                                wallLikeCtr.add("kjut");
                                                              }
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
                                                      if(!_pendingPost){
                                                        Navigator.push(_pageContext, CupertinoPageRoute(
                                                            builder: (BuildContext _ctx){
                                                              return ViewPostedComments(_postId);
                                                            }
                                                        ));
                                                      }
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
                                                    if(!_pendingPost){
                                                      bookmarkPost(_postId);
                                                      if(_wallBooked[_postId] == "yes") _wallBooked[_postId]="no";
                                                      else _wallBooked[_postId]="yes";
                                                      _wallBookedCtr.add("kjut");
                                                    }
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
                                              textScaleFactor: MediaQuery.of(_pageContext).textScaleFactor,
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
                              Widget _laidBlock;
                              if(_mainIndex == 2){
                                _laidBlock= Container(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      StreamBuilder(
                                        builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                          if(_followSuggestions.length>0){
                                            return TweenAnimationBuilder(
                                              tween: Tween<double>(begin: 20, end: 330),
                                              duration: Duration(milliseconds: 700),
                                              curve: Curves.easeOut,
                                              builder: (BuildContext _twCtx, double _twVal, _){
                                                return Opacity(
                                                  opacity: _twVal/330,
                                                  child: Container(
                                                    margin: EdgeInsets.only(top: 12, bottom: 12),
                                                    width: _screenSize.width, height: _twVal,
                                                    decoration: BoxDecoration(
                                                        color: Color.fromRGBO(24, 24, 24, 1)
                                                    ),
                                                    padding: EdgeInsets.only(top: 12, bottom: 12, left: 16, right: 16),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Container(
                                                          margin:EdgeInsets.only(bottom: 12),
                                                          child: Text(
                                                            "Suggested for you",
                                                            textAlign: TextAlign.center,
                                                            style: TextStyle(
                                                                color: Colors.white,
                                                                fontStyle: FontStyle.italic
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: Container(
                                                            width:_screenSize.width,
                                                            child: AnimatedList(
                                                              key: _suggestionLiKey,
                                                              scrollDirection: Axis.horizontal,
                                                              physics: BouncingScrollPhysics(),
                                                              initialItemCount: _followSuggestions.length,
                                                              controller: _suggestionListCtr,
                                                              itemBuilder: (BuildContext _liCtx, int _liIndex, Animation _itemAnimation){
                                                                String _sudp= _followSuggestions[_liIndex]["dp"];
                                                                String _suname=_followSuggestions[_liIndex]["username"];
                                                                String _sfname=_followSuggestions[_liIndex]["fullname"];
                                                                String _suid= _followSuggestions[_liIndex]["user_id"];
                                                                String _stype=_followSuggestions[_liIndex]["type"];
                                                                return Container(
                                                                  decoration: BoxDecoration(
                                                                      color: Color.fromRGBO(32, 32, 32, 1)
                                                                  ),
                                                                  margin: EdgeInsets.only(left: 2),
                                                                  child: GestureDetector(
                                                                    onTap: (){
                                                                      Navigator.of(_pageContext).push(
                                                                          MaterialPageRoute(
                                                                              builder: (BuildContext _ctx){
                                                                                return WallProfile(_suid, username: _suname,);
                                                                              }
                                                                          )
                                                                      );
                                                                    },
                                                                    child: Container(
                                                                      padding: EdgeInsets.only(left: 12, right:12, top:14, bottom: 14),
                                                                      child: Column(
                                                                        children: [
                                                                          Container(
                                                                              margin:EdgeInsets.only(bottom: 12),
                                                                              child: _sudp.length == 1?
                                                                              Container(
                                                                                width:120, height:120,
                                                                                decoration: BoxDecoration(
                                                                                    color: Color.fromRGBO(32, 32, 32, 1)
                                                                                ),
                                                                                alignment: Alignment.center,
                                                                                child: Text(
                                                                                  _sudp.toUpperCase(),
                                                                                  style: TextStyle(
                                                                                      color: Colors.white,
                                                                                      fontSize: 32
                                                                                  ),
                                                                                ),
                                                                              ):
                                                                              Container(
                                                                                width: 120, height: 120,
                                                                                decoration: BoxDecoration(
                                                                                    image: DecorationImage(
                                                                                        image: NetworkImage(_sudp),
                                                                                        fit: BoxFit.cover
                                                                                    )
                                                                                ),
                                                                              )
                                                                          ),//dp
                                                                          Container(
                                                                            margin:EdgeInsets.only(bottom: 5),
                                                                            child: Text(
                                                                              _suname,
                                                                              style: TextStyle(
                                                                                  color: Colors.grey,
                                                                                  fontFamily: "ubuntu"
                                                                              ),
                                                                            ),
                                                                          ), //username
                                                                          Container(
                                                                            margin:EdgeInsets.only(bottom: 9),
                                                                            child: Text(
                                                                              _sfname,
                                                                              style: TextStyle(
                                                                                  color: Colors.white
                                                                              ),
                                                                            ),
                                                                          ), //fullname
                                                                          Container(
                                                                            margin: EdgeInsets.only(bottom: 9),
                                                                            child: Wrap(
                                                                              direction: Axis.horizontal,
                                                                              alignment: WrapAlignment.center,
                                                                              children: [
                                                                                Container(
                                                                                  padding: EdgeInsets.only(top: 3, bottom: 3, left: 7, right: 7),
                                                                                  decoration: BoxDecoration(
                                                                                      color: Color.fromRGBO(60, 60, 60, 1),
                                                                                      borderRadius: BorderRadius.circular(12)
                                                                                  ),
                                                                                  child: Text(
                                                                                    _stype,
                                                                                    style: TextStyle(
                                                                                        color: Colors.white,
                                                                                        fontSize: 10
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                _stype.toLowerCase() == "popular" ?
                                                                                Container(
                                                                                  margin: EdgeInsets.only(left: 7),
                                                                                  child: Text(
                                                                                    globals.convertToK(int.tryParse(_followSuggestions[_liIndex]["detail"])) + " followers",
                                                                                    style: TextStyle(
                                                                                        color: Colors.white,
                                                                                        fontSize: 13,
                                                                                        fontFamily: "ubuntu"
                                                                                    ),
                                                                                  ),
                                                                                )
                                                                                    : _stype.toLowerCase() == "common interests"?
                                                                                Container(
                                                                                  margin: EdgeInsets.only(left: 7),
                                                                                  width: 250, height: 32,
                                                                                  child: SingleChildScrollView(
                                                                                    scrollDirection: Axis.horizontal,
                                                                                    physics: BouncingScrollPhysics(),
                                                                                    child: Text(
                                                                                      _followSuggestions[_liIndex]["details"],
                                                                                      style: TextStyle(
                                                                                          fontFamily: "ubuntu",
                                                                                          color: Colors.white,
                                                                                          fontSize: 12
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                ):
                                                                                _stype.toLowerCase() == "you may know"
                                                                                    ? Container(
                                                                                  margin: EdgeInsets.only(left: 7),
                                                                                  child: Text(
                                                                                    globals.convertToK(int.tryParse(_followSuggestions[_liIndex]["detail"])) + " score",
                                                                                    style: TextStyle(
                                                                                        color: Colors.white,
                                                                                        fontSize: 13,
                                                                                        fontFamily: "ubuntu"
                                                                                    ),
                                                                                  ),
                                                                                ):
                                                                                Container()
                                                                              ],
                                                                            ),
                                                                          ), //follow type
                                                                          Container(
                                                                            child: GestureDetector(
                                                                              onTap: (){
                                                                                followUnfollowUser(_suid, _liIndex);
                                                                              },
                                                                              child: Container(
                                                                                padding: EdgeInsets.only(left: 14, right: 14, top: 7, bottom: 7),
                                                                                decoration: BoxDecoration(
                                                                                    color: Colors.orange,
                                                                                    borderRadius: BorderRadius.circular(9)
                                                                                ),
                                                                                child: Text(
                                                                                  _stype.toLowerCase() == "follows you" ? "Follow Back" : "Follow",
                                                                                  style: TextStyle(
                                                                                      color: Colors.white,
                                                                                      fontSize: 13,
                                                                                      fontFamily: "ubuntu"
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ),//follow btn
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                        )
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          }
                                          return Container();
                                        },
                                      ),
                                      _liBlock
                                    ],
                                  ),
                                );
                              }
                              else{
                                _laidBlock= _liBlock;
                              }
                              return _laidBlock;
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
              _kjToast,
              Positioned(
                child: IgnorePointer(
                  ignoring: true,
                  child: StreamBuilder(
                    stream: _loaderCtr.stream,
                    builder: (BuildContext _ctx, AsyncSnapshot _loadshot){
                      return AnimatedOpacity(
                        opacity: _loadshot.hasData && _loadshot.data == "reload" ? 1 : _loaderOpacity < .1 ? _loaderOpacity : 1,
                        duration: Duration(milliseconds: 300),
                        child: Container(
                            width: _screenSize.width, height: 70,
                            child: LiquidLinearProgressIndicator(
                              direction: Axis.vertical,
                              value: _loadshot.hasData && _loadshot.data == "reload" ? 1 : _loaderOpacity,
                              backgroundColor: Color.fromRGBO(32, 32, 32, 1),
                              valueColor: _loadshot.hasData && _loadshot.data == "reload"
                                  ? AlwaysStoppedAnimation<Color>(Color.fromRGBO(32, 32, 32, 1))
                                  :AlwaysStoppedAnimation<Color>(Color.fromRGBO(48, 48, 48, 1)),
                              center: AnimatedOpacity(
                                opacity:_loadshot.hasData && _loadshot.data == "reload" ? 1 :0,
                                duration: Duration(milliseconds: 500),
                                child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),),
                              ),
                            )
                        ),
                      );
                    },
                  ),
                ),
              )
            ],
          ),
        ),//page container,
        autofocus: true,
        onFocusChange: (bool _isFocused){
          if(_isFocused){
            //capturing only when focus is gained
            if(_serverData.length>0){
              initLocalWallDir();
              fetchPosts(caller: "init");
              _followSuggestions=List();
              fetchFSuggestions();
            }
          }
          else{
            pauseAllVids();
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

  double _loaderOpacity=0;
  StreamController _loaderCtr= StreamController.broadcast();
  bool _reload=false; //this variable is used to tell the pull to refresh implementation when to reload the page
  Stream _gwallPostStream;

  bool _scrollreload=false;

  Stream _globalLinkListener;

  final Map<String, GlobalKey> _wallBlockKeys= Map<String, GlobalKey>();
  AnimationController _likeAniCtr;
  Animation<double> _likeAni;
  @override
  void initState() {
    super.initState();
    wallScrollCtr= ScrollController(); //scroll controller for the main page's scroll
    fetchPosts(caller: "init"); //fetch local post if any exists
    initLocalWallDir(); //creates (or initializes) user's wall profile
    fetchFSuggestions();
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

    _gwallPostStream= globals.globalWallPostCtr.stream;
    _gwallPostStream.listen((_data) {
      if(globals.wallPostData["state"]=="passive" && globals.wallPostData["message"] == "success"){
        _kjToast.showToast(
            text: "Your post is LIVE!",
            duration: Duration(seconds: 3)
        );
        fetchPosts(caller: "init");
      }
      else if(globals.wallPostData["state"]=="passive" && globals.wallPostData["message"] == "error"){
        _kjToast.showToast(
            text: "Your post didn't complete successfully",
            duration: Duration(seconds: 7)
        );
        resetVidPlayer();
        _followSuggestions= List();
        fetchFSuggestions();
      }
    });

    _globalLinkListener= globals.localLinkTrigger.stream;
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      initGlobalLinkNav();
    });
    initLVEvents();

    _suggestionListCtr.addListener(() {
      if(_loadingSuggestions == false){
        if(_suggestionListCtr.position.pixels > (_suggestionListCtr.position.maxScrollExtent - (_screenSize.width * 1.5))){
          fetchFSuggestions();
        }
      }
    });
  }//route's init state

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

  initLVEvents(){
    wallScrollCtr.addListener(() {
      if(wallScrollCtr.position.outOfRange){
        double _curpix= wallScrollCtr.position.pixels;
        if(_curpix.isNegative){
          if(_curpix>-70 && _reload == false){
            _loaderOpacity= (_curpix)/-70;
            _loaderCtr.add("kjut");
          }
          else if((_curpix<-70) && _reload==false){
            _reload=true;
            _loaderCtr.add("reload");
          }
        }
      }
      else{
        if(_reload){
          if(_scrollreload){
            //prevent reload of this page when a previous fetch request has not been successfully completed
            _reload=false;
            _loaderOpacity=0;
            _loaderCtr.add("kjut");
          }
          else{
            pauseAllVids();
            Future.delayed(
                Duration(milliseconds: 3000),
                    (){
                  _reload=false;
                  _loaderOpacity=0;
                  _loaderCtr.add("kjut");
                  fetchPosts(caller: "init");
                }
            );
          }
        }
        if((wallScrollCtr.position.pixels > (wallScrollCtr.position.maxScrollExtent -  (_screenSize.height * 1.5))) && _scrollreload == false){
          _scrollreload=true;
          onScrollReload();
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
        String _locCurrentPage= _wallPVCurPage[_targKey].toString();
        String _localPlayerID= _playerIDMap["$_targKey.$_locCurrentPage"];
        if(wallVideoCtr.containsKey(_localPlayerID)){
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
        wallVideoCtr.forEach((key, value) {
          if(key!=_playVidKey){
            if(value.value.isPlaying) value.pause();
          }
        });
        if(!wallVideoCtr[_playVidKey].value.isPlaying) {
          wallVideoCtr[_playVidKey].play();
        }
      }
    });
  }//init list view events

  Future<void> onScrollReload()async{
    try{
      http.Response _resp= await http.post(
          globals.globBaseUrl + "?process_as=fetch_wall_post",
          body:{
            "user_id": globals.userId,
            "exclude": jsonEncode(_existingPids)
          }
      );
      if(_resp.statusCode == 200){
        var _respObj= jsonDecode(_resp.body);
        int _newcontentlen=_respObj.length;
        if(_newcontentlen>0){
          _scrollreload=false; //to give allowance for fresh content load from the server
          for(int _k=0; _k<_newcontentlen; _k++){
            _existingPids.add(_respObj[_k]["post_id"]);
            _serverData.add({
              "post_id": _respObj[_k]["post_id"],
              "user_id": _respObj[_k]["user_id"],
              "post_images": jsonEncode(_respObj[_k]["images"]),
              "image_path" : _respObj[_k]["image_path"],
              "post_text" : _respObj[_k]["post_text"],
              "views" : jsonEncode(_respObj[_k]["views"]),
              "time_str" : _respObj[_k]["post_time"],
              "likes" : jsonEncode(_respObj[_k]["likes"]),
              "comments": jsonEncode(_respObj[_k]["comments"]),
              "post_link_to": _respObj[_k]["link_to"],
              "bookmarked": "no",
              "dp": _respObj[_k]["dp"],
              "username": _respObj[_k]["username"],
              "fullname": _respObj[_k]["fullname"]
            });
          }
          resetVidPlayer();
          wallRenderCtr.add("kjut");
        }
      }
    }
    catch(ex){

    }
  }//on scroll approach end

  Directory _appdir;
  Widget _wallDp= Container();
  Directory _wallDir;
  Directory _postDir;
  initLocalWallDir()async{
    if(_appdir == null){
      _appdir= await getApplicationDocumentsDirectory();
      _wallDir= Directory(_appdir.path + "/wall_dir");
      await _wallDir.create();
      _postDir= Directory(_wallDir.path + "/post_media");
      await _postDir.create();
    }

    String _dbdp=globals.fullname.substring(0,1);

    Database con= await dbTables.myProfileCon();
    var _result= await con.rawQuery("select * from user_profile where status='active'");
    if(_result.length==1){
      var _rw= _result[0];
      String _dppath= _appdir.path + "/wall_dir/" + _rw["dp"];
      File _walldpF= File(_dppath);
      if(await _walldpF.exists()){
        _dbdp=_dppath;
      }
    }
    else{
      //create a new local profile
      String _upStattus="active";
      String _upname=globals.fullname;
      String _profiledp="", _upbrief="", _upwebsite="", _profileinterests;
      //check online if one exists, else create one
      try{
        http.Response _resp= await http.post(
            globals.globBaseUrl + "?process_as=try_create_wall_profile",
            body: {
              "user_id": globals.userId,
              "username": _upname
            }
        );
        if(_resp.statusCode == 200){
          var _respObj= jsonDecode(_resp.body);
          _upname= _respObj["username"];
          _upwebsite= _respObj["website"];
          _upbrief= _respObj["brief"];
          _profiledp=_respObj["dp"];
          _profileinterests=_respObj["interests"];
          if(_profiledp.length>1){
            Uint8List _dpbytes= await http.readBytes(_profiledp);
            List<String> _brkDP= _profiledp.split("/");
            _profiledp= _brkDP.last;
            String _dppath= _appdir.path + "/wall_dir/$_profiledp";
            File _walldpF= File(_dppath);
            if(_walldpF.existsSync()){
              await _walldpF.delete();
            }
            _walldpF.writeAsBytesSync(_dpbytes);
            _dbdp=_dppath;
          }
          con.execute("insert into user_profile (username, dp, website, brief, interests, status) values (?, ?, ?, ?, ?, ?)",[_upname, _profiledp, _upwebsite, _upbrief, _profileinterests, _upStattus]);
        }
      }
      catch(ex){

      }
    }
    _wallDp= Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: (){
          Navigator.of(_pageContext).push(MaterialPageRoute(
              builder: (BuildContext ctx){
                return EditWallProfile();
              }
          ));
        },
        child: Container(
          alignment: Alignment.center,
          child: _dbdp.length == 1 ?
          CircleAvatar(
            radius: 20,
            child: Text(_dbdp),
          ):
          CircleAvatar(
            radius: 20,
            backgroundImage: FileImage(File(_dbdp)),
          ),
        ),
      ),
    );
    dpChangedCtr.add("kjut");

    //delete wall_posts that have lasted more than 24 hours with like
    Database _con2= await dbTables.wallPosts();
    _con2.rawQuery("select * from wall_posts where section!='following'").then((_result) {
      int _kount= _result.length;
      int _kita= DateTime.now().millisecondsSinceEpoch;
      for(int _k=0; _k<_kount; _k++){
        int _targSaveTime= int.tryParse(_result[_k]["save_time"]);
        if(_kita - _targSaveTime >(24 * 3600 * 1000)){
          int _wpid= _result[_k]["id"];
          List _targMedia= jsonDecode(_result[_k]["post_images"]);
          int _targMediaCount= _targMedia.length;
          for(int _j=0; _j<_targMediaCount; _j++){
            File _dPF= File(_appdir.path + "/wall_dir/post_media/${_targMedia[_j]["file"]}");
            _dPF.exists().then((_fexists){
              if(_fexists) _dPF.delete();
            });
          }
          _con2.execute("delete from wall_posts where id=?", [_wpid]);
        }
      }
    });
  }//init local wall dir

  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize= MediaQuery.of(_pageContext).size;
    if(_kjToast==null){
      _kjToast=globals.KjToast(Color.fromRGBO(20, 20, 20, 1), _screenSize, toastCtrl, _screenSize.height * .4);
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

  StreamController _adAvailableNotifier= StreamController.broadcast();
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
    _loaderCtr.close();
    _fsuggestNotifier.close();
    _adAvailableNotifier.close();
  }//close all stream

  @override
  void dispose() {
    closeAllStream();
    wallScrollCtr.dispose();
    wallMediaPageCtr.forEach((key, value) {
      value.dispose();
    });
    wallVideoCtr.forEach((key, value) {
      value.dispose();
    });
    _likeAniCtr.stop();
    _likeAniCtr.dispose();
    _suggestionListCtr.dispose();
    super.dispose();
  }//route's dispose state
}