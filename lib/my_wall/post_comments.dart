import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_icons/flutter_icons.dart';

import '../dbs.dart';
import '../globals.dart' as globals;
import 'profile.dart';
import './wall_hash.dart';

class ViewPostedComments extends StatefulWidget{
  _PostComments createState(){
    return _PostComments();
  }
  final String _gPostID;
  ViewPostedComments(this._gPostID);
}

class _PostComments extends State<ViewPostedComments> with SingleTickerProviderStateMixin{
  bool _pageDlg=false;
  StreamController _pageStreamCtr= StreamController.broadcast();
  DBTables dbTables= DBTables();
  Directory _appDir;
  Directory _wallDir;
  Widget _wallDP;

  globals.KjToast _kjToast;
  StreamController _toastCtr= StreamController.broadcast();
  AnimationController _likeAniCtr;
  Animation<double> _likeAni;
  initState(){
    super.initState();
    initWallDir();
    fetchPostComments();
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

    _globalLinkListener= globals.localLinkTrigger.stream;
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      initGlobalLinkNav();
    });
  }//route's init state

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

  StreamController _dpLoadedNotifier= StreamController.broadcast();
  initWallDir()async{
    _appDir=await getApplicationDocumentsDirectory();
    _wallDir=Directory(_appDir.path + "/wall_dir");

    //here we will be trying to get the user's dp
    String _dpstr= globals.fullname.substring(0,1);
    Database _con=await dbTables.myProfileCon();
    var _dpres= await _con.rawQuery("select dp from user_profile where status='active'");
    if(_dpres.length >0){
      File _dpfile=File(_wallDir.path + "/" + _dpres[0]["dp"]);
      if(_dpfile.existsSync()){
        _dpstr=_dpres[0]["dp"];
      }
    }

    _wallDP= Container(
      child: _dpstr.length == 1 ?
      CircleAvatar(
        radius: 20,
        child: Text(_dpstr),
      )
          :CircleAvatar(
        radius: 20,
        backgroundImage: FileImage(File(_dpstr)),
      ),
    );
    _dpLoadedNotifier.add("kjut");
  }//init wall dir and get user's dp

  var _commentBlockData;
  bool _gLocalPost=false;
  ///This the function that gets the page's content from the local db
  Future<void> fetchPostComments()async{
    Database _con= await dbTables.wallPosts();
    String _locPostId= widget._gPostID;
    var _result= await _con.rawQuery("select * from wall_posts where post_id=?", [_locPostId]);
    if(_result.length == 1){
      _commentBlockData= _result;
      _pageStreamCtr.add("kjut");
      _gLocalPost=true;
    }
    refreshPost(reloadPage: false);
  }//fetch post comments

  ///Updates the local database with the updates on the current post
  Future refreshPost({bool reloadPage})async{
    try{
      String _url=globals.globBaseUrl + "?process_as=get_wall_post_update";
      http.post(
          _url,
          body: {
            "post_id": widget._gPostID
          }
      ).then((_resp)async{
        if(_resp.statusCode == 200){
          var _respObj= jsonDecode(_resp.body);
          Database _con= await dbTables.wallPosts();
          String _postTime= _respObj["post_time"];
          String _postLikes= jsonEncode(_respObj["likes"]);
          String _postComments= jsonEncode(_respObj["comments"]);
          String _localPostID= widget._gPostID;
          if(_gLocalPost){
            _con.execute("update wall_posts set likes=?, comments=?, time_str=? where post_id=?", [
              _postLikes, _postComments, _postTime, _localPostID
            ]).then((value) {
              if(reloadPage){
                fetchPostComments();
              }
            });
          }
          else{
            List<Map> _serverData=List<Map>();
            _serverData.add({
              "post_id": _localPostID,
              "time_str": _postTime,
              "comments": _postComments,
              "likes": _postLikes,
              "username": _respObj["username"],
              "dp": _respObj["dp"],
              "fullname": _respObj["username"],
              "post_text": _respObj["post_text"]
            });
            _commentBlockData=_serverData;
            _pageStreamCtr.add("kjut");
          }
        }
      });
    }
    catch(ex){
    }
  }

  ///Responds to the view replies ontap gesture
  fetchRepliesToComment(String _commentId)async{
    _commentReplies[_commentId]={
      "type": "widget",
      "content": Container(
        margin: EdgeInsets.only(top:12),
        height: 90,
        alignment: Alignment.centerLeft,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
        ),
      )
    };
    _viewReplyCtr.add("kjut");
    try{
      http.post(
          globals.globBaseUrl + "?process_as=fetch_replies_to_comment",
          body: {
            "comment_id": _commentId
          }
      ).then((_resp){
        if(_resp.statusCode == 200){
          var _respObj= jsonDecode(_resp.body);
          int _kount= _respObj.length;
          List<Widget> _colChildren= List<Widget>();
          for(int _itemIndex=0; _itemIndex<_kount; _itemIndex++){
            String _innerDp=_respObj[_itemIndex]["dp"].toString();
            List _likes= jsonDecode(_respObj[_itemIndex]["likes"]);
            String _cuname= _respObj[_itemIndex]["username"];
            String _cid= _respObj[_itemIndex]["comment_id"];
            if(!_commentLikeMap.containsKey(_cid)){
              if(_likes.indexOf(globals.userId)>-1){
                _commentLikeMap[_cid]=true;
              }
              else _commentLikeMap[_cid]= false;
            }
            if(!_commentReplies.containsKey(_cid)){
              _commentReplies[_cid]={
                "type": "text",
                "content" : _respObj[_itemIndex]["replies"]
              };
            }
            _colChildren.add(
                Container(
                  margin: EdgeInsets.only(left:32, top:12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        child: GestureDetector(
                          onTap: (){
                            Navigator.of(_pageContext).push(CupertinoPageRoute(
                              builder: (BuildContext _ctx){
                                return WallProfile(_respObj[_itemIndex]["uid"], username: _respObj[_itemIndex]["username"]);
                              }
                            ));
                          },
                          child: Container(
                            margin: EdgeInsets.only(right:16),
                            child: (_innerDp.length == 1)?
                            CircleAvatar(
                                radius: 16,
                                child:Text(
                                    _innerDp
                                )
                            ):
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: NetworkImage(
                                  _innerDp
                              ),
                            ),
                          ),
                        ),
                      ),//dp

                      Expanded(
                        child: Container(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                child: GestureDetector(
                                  onTap: (){
                                    Navigator.of(_pageContext).push(MaterialPageRoute(
                                        builder: (BuildContext _ctx){
                                          return WallProfile(_respObj[_itemIndex]["uid"], username: _respObj[_itemIndex]["username"]);
                                        }
                                    ));
                                  },
                                  child: Container(
                                    child: Text(
                                      _respObj[_itemIndex]["username"],
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontFamily: "ubuntu",
                                          fontSize: 15
                                      ),
                                    ),
                                  ),
                                ),
                              ),//username
                              Container(
                                margin: EdgeInsets.only(top:5),
                                child: RichText(
                                  textScaleFactor: MediaQuery.of(_pageContext).textScaleFactor,
                                  text: TextSpan(
                                      children: globals.parseTextForLinks(_respObj[_itemIndex]["text"])
                                  ),
                                ),
                              ), //comment text

                              /*time, like count, reply gesture, like comment
                                * */
                              Container(
                                margin: EdgeInsets.only(top:5),
                                child: Wrap(
                                  direction: Axis.horizontal,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: <Widget>[
                                    Container(
                                      margin: EdgeInsets.only(right:7),
                                      child: Text(
                                        _respObj[_itemIndex]["time"],
                                        style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 13,
                                            fontFamily: "ubuntu"
                                        ),
                                      ),
                                    ), //post time

                                    Container(
                                      margin: EdgeInsets.only(right:7),
                                      child: Text(
                                        _likes.length.toString() + " likes",
                                        style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 13
                                        ),
                                      ),
                                    ), //like count

                                    GestureDetector(
                                      onTap: (){
                                        _replyToName=_cuname;
                                        _replyToId=_cid;
                                        _replyToCtr.add(_replyToName);
                                        FocusScope.of(_pageContext).requestFocus(_commentTxtNode);
                                      },
                                      child: Container(
                                        margin: EdgeInsets.only(right:7),
                                        child: Text(
                                          "Reply",
                                          style: TextStyle(
                                              color: Colors.blueAccent,
                                              fontSize: 13
                                          ),
                                        ),
                                      ),
                                    ), //reply comment

                                    Container(
                                      child: StreamBuilder(
                                          stream: _commentLikeCtr.stream,
                                          builder: (BuildContext ctx, AsyncSnapshot snapshot){
                                            return Material(
                                              color: Colors.transparent,
                                              child: InkResponse(
                                                  onTap: (){
                                                    likeComment(_cid);
                                                    _commentLikeMap[_cid]= !_commentLikeMap[_cid];
                                                    _commentLikeCtr.add("kjut");
                                                  },
                                                  child: _commentLikeMap[_cid] ?
                                                  ScaleTransition(
                                                    scale: _likeAni,
                                                    child: Icon(
                                                      FlutterIcons.ios_heart_ion,
                                                      color: Colors.white,
                                                      size: 13,
                                                    ),
                                                  ):
                                                  Icon(
                                                    FlutterIcons.ios_heart_empty_ion,
                                                    color: Colors.white,
                                                    size: 13,
                                                  )
                                              ),
                                            );
                                          }
                                      ),
                                    )
                                    //like, unlike comment
                                  ],
                                ),
                              ),
                              //time, like count, reply gesture, like comment

                              /*View replies gesture
                                * */
                              Container(
                                child: StreamBuilder(
                                  stream: _viewReplyCtr.stream,
                                  builder: (BuildContext ctx, AsyncSnapshot snapshot){
                                    return Container(
                                      child: (_commentReplies[_cid]["type"] == "text" && _commentReplies[_cid]["content"] == "0")?
                                      Container() :
                                      (_commentReplies[_cid]["type"] == "text" && _commentReplies[_cid]["content"] != "0") ?
                                      GestureDetector(
                                        onTap: (){
                                          fetchRepliesToComment(_cid);
                                        },
                                        child: Container(
                                            margin: EdgeInsets.only(top:16),
                                            child:Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: <Widget>[
                                                Container(
                                                  height:2, width: 40,
                                                  margin: EdgeInsets.only(right: 16),
                                                  decoration: BoxDecoration(
                                                      color: Colors.grey
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Container(
                                                    child: Text(
                                                      "View " + _commentReplies[_cid]["content"] + " replies",
                                                      style: TextStyle(
                                                          color: Colors.grey,
                                                          fontFamily: "ubuntu",
                                                          fontSize: 12
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              ],
                                            )
                                        ),
                                      ):
                                      _commentReplies[_cid]["content"],
                                    );
                                  },
                                ),
                              )
                              //view replies gesture
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                )
            );
          }
          Widget _innerComment= Container(
            child: Column(
              children: _colChildren,
            ),
          );
          _commentReplies[_commentId]={
            "type": "widget",
            "content": _innerComment
          };
          _viewReplyCtr.add("kjut");
        }
        else{
          _kjToast.showToast(
              text: "Can't fetch replies now - kindly try again later",
              duration: Duration(seconds: 3)
          );
        }
      });
    }
    catch(ex){
      _kjToast.showToast(
          text: "Can't fetch replies - Offline mode",
          duration: Duration(seconds: 3)
      );
    }
  }//fetch replies to comment

  likeComment(String _commentId){
    try{
      String _url= globals.globBaseUrl + "?process_as=like_wall_comment";
      http.post(
          _url,
          body: {
            "comment_id": _commentId,
            "user_id": globals.userId
          }
      ).then((_resp){
        if(_resp.statusCode == 200){
          if(_resp.body == "success"){
            refreshPost(reloadPage: false);
          }
        }
      });
    }
    catch(ex){

    }
  }//like comment


  dispose(){
    _likeAniCtr.dispose();
    _pageStreamCtr.close();
    pullRefreshCtr.close();
    _commentLikeCtr.close();
    _toastCtr.close();
    _dpLoadedNotifier.close();
    _replyToCtr.close();
    _viewReplyCtr.close();
    _globalListCtr.dispose();
    _commentTextCtr.dispose();
    super.dispose();
  }//route's dispose

  replyToComment()async{
    if(_commentTextCtr.text=="") return false;
    try{
      String _url= globals.globBaseUrl + "?process_as=reply_wall_comment";
      String _commentText= _commentTextCtr.text;
      _commentTextCtr.text="";
      http.post(
          _url,
          body: {
            "post_id": widget._gPostID,
            "user_id": globals.userId,
            "comment_id": _replyToId,
            "comment": _commentText
          }
      ).then((_resp){
        if(_resp.statusCode == 200){
          if(_resp.body == "success"){
            refreshPost(reloadPage: true);
          }
          return true;
        }
        else return false;
      });
      if(_replyToId!=""){
        _commentReplies.remove(_replyToId);
        _replyToId="";
        _replyToName="";
        _replyToCtr.add("");
      }
    }
    catch(ex){
      _kjToast.showToast(
          text: "Can't comment in offline mode",
          duration: Duration(seconds: 3)
      );
      return false;
    }
  }//reply to comment

  StreamController _viewReplyCtr= StreamController.broadcast();
  Map _commentReplies= Map();

  StreamController _commentLikeCtr= StreamController.broadcast();
  Map<String, bool> _commentLikeMap= Map<String, bool>();
  Widget commentBlock(List _commentLi, int itemIndex){
    List _commentLikes= jsonDecode(_commentLi[itemIndex]["likes"]);
    int _countLikes= _commentLikes.length;
    String _cid=_commentLi[itemIndex]["comment_id"];
    String _replyCount= _commentLi[itemIndex]["replies"];
    if(!_commentReplies.containsKey(_cid)){
      _commentReplies[_cid]= {
        "type" : "text",
        "content": _replyCount
      };
    }
    if(!_commentLikeMap.containsKey(_cid)){
      if(_commentLikes.indexOf(globals.userId)>-1){
        _commentLikeMap[_cid]=true;
      }
      else{
        _commentLikeMap[_cid]= false;
      }
    }
    String _cuname=_commentLi[itemIndex]["username"];
    String _cuid=_commentLi[itemIndex]["uid"];
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GestureDetector(
            onTap: (){
              Navigator.of(_pageContext).push(CupertinoPageRoute(
                  builder: (BuildContext _ctx){
                    return WallProfile(_cuid, username: _cuname);
                  }
              ));
            },
            child: Container(
              width: 32, height: 32,
              child: _commentLi[itemIndex]["dp"].toString().length == 1?
              CircleAvatar(
                radius: 24,
                child: Text(
                  _commentLi[itemIndex]["dp"],
                  style: TextStyle(

                  ),
                ),
              ):
              CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(_commentLi[itemIndex]["dp"]),
              )
            ),
          ), //dp

          Expanded(
            child: Container(
              margin: EdgeInsets.only(left:12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    margin: EdgeInsets.only(bottom: 3),
                    child: GestureDetector(
                      onTap: (){
                        Navigator.of(_pageContext).push(MaterialPageRoute(
                            builder: (BuildContext _ctx){
                              return WallProfile(_cuid, username: _cuname);
                            }
                        ));
                      },
                      child: Container(
                        child: Text(
                          _cuname,
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 15,
                              fontFamily: "ubuntu"
                          ),
                        ),
                      ),//comment username,
                    ),
                  ),

                  Container(
                    child: RichText(
                      textScaleFactor: MediaQuery.of(_pageContext).textScaleFactor,
                      text: TextSpan(
                          children: globals.parseTextForLinks(_commentLi[itemIndex]["text"])
                      ),
                    ),
                  ), //comment

                  /*post time, likes and reply gesture
                  * */
                  Container(
                    margin: EdgeInsets.only(top:7),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Container(
                          child: Container(
                            child: Text(
                              _commentLi[itemIndex]["time"],
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                  fontFamily: "ubuntu"
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),//comment time

                        Container(
                          margin: EdgeInsets.only(left: 9),
                          child: Text(
                            globals.convertToK(_countLikes) + " likes",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),//comment like count

                        GestureDetector(
                          onTap: (){
                            _replyToName=_cuname;
                            _replyToId=_cid;
                            _replyToCtr.add(_replyToName);
                            FocusScope.of(_pageContext).requestFocus(_commentTxtNode);
                          },
                          child: Container(
                            margin: EdgeInsets.only(left:9),
                            child: Text(
                              "Reply",
                              style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 13
                              ),
                            ),
                          ),
                        ), //reply comment

                        Container(
                          margin: EdgeInsets.only(left:12),
                          child: StreamBuilder(
                              stream: _commentLikeCtr.stream,
                              builder: (BuildContext ctx, AsyncSnapshot snapshot){
                                return Material(
                                  color: Colors.transparent,
                                  child: InkResponse(
                                      onTap: (){
                                        likeComment(_cid);
                                        _commentLikeMap[_cid]= !_commentLikeMap[_cid];
                                        _commentLikeCtr.add("kjut");
                                      },
                                      child: _commentLikeMap[_cid] ?
                                      ScaleTransition(
                                        scale: _likeAni,
                                        child: Icon(
                                          FlutterIcons.ios_heart_ion,
                                          color: Colors.white,
                                          size: 13,
                                        ),
                                      ):
                                      Icon(
                                        FlutterIcons.ios_heart_empty_ion,
                                        color: Colors.white,
                                        size: 14,
                                      )
                                  ),
                                );
                              }
                          ),
                        )
                      ],
                    ),
                  ), //post time, likes and reply gesture

                  /*View replies gesture
                  * */
                  Container(
                    child: StreamBuilder(
                      stream: _viewReplyCtr.stream,
                      builder: (BuildContext ctx, AsyncSnapshot snapshot){
                        return Container(
                          child: (_commentReplies[_cid]["type"] == "text" && _commentReplies[_cid]["content"] == "0")?
                          Container() :
                          (_commentReplies[_cid]["type"] == "text" && _commentReplies[_cid]["content"] != "0") ?
                          GestureDetector(
                            onTap: (){
                              fetchRepliesToComment(_cid);
                            },
                            child: Container(
                                margin: EdgeInsets.only(top:16),
                                child:Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: <Widget>[
                                    Container(
                                      height:2, width: 40,
                                      margin: EdgeInsets.only(right: 16),
                                      decoration: BoxDecoration(
                                          color: Colors.grey
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        child: Text(
                                          "View " + _commentReplies[_cid]["content"] + " replies",
                                          style: TextStyle(
                                              color: Colors.grey,
                                              fontFamily: "ubuntu",
                                              fontSize: 12
                                          ),
                                        ),
                                      ),
                                    )
                                  ],
                                )
                            ),
                          ):
                          _commentReplies[_cid]["content"],
                        );
                      },
                    ),
                  )
                  //view replies gesture
                ],
              ),
            ),
          ), //Post contents
        ],
      ),
    );
  }//comment block

  Widget commentList(){
    List _commentLi= jsonDecode(_commentBlockData[0]["comments"]);
    List _postLikes= jsonDecode(_commentBlockData[0]["likes"]);
    int _commentCount=_commentLi.length;
    return ListView.builder(
        itemCount: _commentCount,
        controller: _globalListCtr,
        itemBuilder: (BuildContext ctx, int itemIndex){
          if(itemIndex == 0){
            return Container(
              child: Column(
                children: <Widget>[
                  pullToRefreshContainer(),
                  Container(
                    margin: EdgeInsets.only(bottom: 16),
                    padding: EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(
                                color: Color.fromRGBO(32, 32, 32, 1)
                            )
                        )
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        /*Post DP
                                    * */
                        Container(
                          margin: EdgeInsets.only(right: 16),
                          width: 32, height: 32,
                          alignment: Alignment.center,
                          child: _commentBlockData[0]["dp"].toString().length == 1 ?
                          CircleAvatar(
                            radius: 24,
                            child: Text(
                                _commentBlockData[0]["dp"]
                            ),
                          ):CircleAvatar(
                            radius: 24,
                            backgroundImage: (_gLocalPost) ? FileImage(
                                File(_wallDir.path + "/post_media/" + _commentBlockData[0]["dp"])
                            ):
                            NetworkImage(_commentBlockData[0]["dp"]),
                          ),
                        ),//Post dp

                        Expanded(
                          child: Container(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  child: Text(
                                    _commentBlockData[0]["username"].toString().length>0 ?
                                    _commentBlockData[0]["username"]:
                                    _commentBlockData[0]["fullname"],
                                    style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold
                                    ),
                                  ),
                                ),//username

                                Container(
                                  margin: EdgeInsets.only(top:4),
                                  child: RichText(
                                    textScaleFactor: MediaQuery.of(_pageContext).textScaleFactor,
                                    text: TextSpan(
                                      children: globals.parseTextForLinks(_commentBlockData[0]["post_text"]),
                                    ),
                                  ),
                                ),//post text,

                                Container(
                                  margin: EdgeInsets.only(top:7),
                                  child: Row(
                                    children: <Widget>[
                                      Container(
                                        margin: EdgeInsets.only(right:5),
                                        child: Text(
                                          globals.convertToK(_postLikes.length) + " likes",
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          _commentCount.toString() + " comments",
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 13
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                ), //like count and comment count


                                Container(
                                  margin: EdgeInsets.only(top: 3, bottom: 12),
                                  child: Text(
                                    _commentBlockData[0]["time_str"],
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        fontFamily: "ubuntu"
                                    ),
                                  ),
                                ),//post time
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ),//The Post data

                  /*First Comment
                  * */
                  commentBlock(_commentLi, itemIndex)
                  //first comment
                ],
              ),
            );
          }
          else{
            return commentBlock(_commentLi, itemIndex);
          }
        }
    );// builds the page blocks
  }//comment list

  ///The actual route's page body drawn
  Widget pageBody(){
    return Scaffold(
      backgroundColor: Color.fromRGBO(32, 32, 32, 1),
      appBar: AppBar(
        title: Text(
          "Comments",
          style: TextStyle(
              color: Colors.grey
          ),
        ),
        backgroundColor: Color.fromRGBO(26, 26, 26, 1),
      ),
      body: FocusScope(
        child: Container(
            padding: EdgeInsets.only(left:12, right:12, top:24),
            child: Stack(
              children: <Widget>[
                StreamBuilder(
                  stream: _pageStreamCtr.stream,
                  builder: (BuildContext ctx, snapshot){
                    if(snapshot.hasData && _commentBlockData!=null){
                      return kjPullToRefresh(
                          child: commentList()
                      );
                    }
                    else{
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color.fromRGBO(120, 120, 120, 1)),
                        ),
                      );
                    }
                  },
                ),
                _kjToast
              ],
            )
        ),
        onFocusChange: (bool _isFocused){
          if(_isFocused){
            if(_commentBlockData.length>0){
              refreshPost(reloadPage: true);
            }
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
          height: 140,
          width: _screenSize.width,
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 140, width: _screenSize.width,
            child: Stack(
              overflow: Overflow.visible,
              children: <Widget>[
                Positioned(
                  bottom:65, left: 12,
                  child: StreamBuilder(
                    stream: _replyToCtr.stream,
                    builder: (BuildContext ctx, AsyncSnapshot snapshot){
                      if(snapshot.hasData && snapshot.data!=""){
                        return Container(
                          padding: EdgeInsets.only(left:36, right: 0, top:5, bottom: 5),
                          decoration: BoxDecoration(
                              color: Color.fromRGBO(20, 20, 20, 1),
                              border: Border.all(
                                  color: Color.fromRGBO(60, 60, 60, 1)
                              ),
                              borderRadius: BorderRadius.circular(5)
                          ),
                          child: Stack(
                            overflow: Overflow.visible,
                            children: <Widget>[
                              Container(
                                transform: Matrix4.translationValues(-32, 0, 0),
                                child: Text(
                                  snapshot.data,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontFamily: "ubuntu"
                                  ),
                                ),
                              ),
                              Positioned(
                                right:0, bottom:0,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkResponse(
                                    onTap:(){
                                      _replyToId="";
                                      _replyToName="";
                                      _replyToCtr.add("");
                                    },
                                    child: Icon(
                                      FlutterIcons.ios_close_circle_ion,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ),
                              )
                            ],
                          ),
                        );
                      }
                      else{
                        return Container();
                      }
                    },
                  ),
                ),
                Positioned(
                  bottom: 0, left:0,
                  child: Container(
                    padding: EdgeInsets.only(left:12, right:12),
                    width: _screenSize.width,
                    height:60,
                    color: Colors.white,
                    child: Flex(
                      direction: Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Flexible(
                          flex: 1,
                          child: StreamBuilder(
                            stream: _dpLoadedNotifier.stream,
                            builder: (BuildContext ctx, AsyncSnapshot snapshot){
                              return snapshot.hasData ? _wallDP : Container();
                            },
                          ),
                        ),//your dp

                        Flexible(
                          flex: 8,
                          child: Container(
                            margin: EdgeInsets.only(left: 12, right:12),
                            child: Stack(
                              children: <Widget>[
                                Container(
                                  child: TextField(
                                    style: TextStyle(
                                      color: Colors.black,
                                    ),
                                    controller: _commentTextCtr,
                                    focusNode: _commentTxtNode,
                                    decoration: InputDecoration(
                                        hintText: "Comment as " + globals.fullname,
                                        hintStyle: TextStyle(
                                            color: Colors.grey
                                        ),
                                        enabledBorder: InputBorder.none,
                                        focusedBorder:InputBorder.none
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Flexible(
                          flex: 1,
                          child: Material(
                            color: Colors.transparent,
                            child: InkResponse(
                              onTap: (){
                                replyToComment();
                              },
                              child: Icon(
                                FlutterIcons.send_circle_mco,
                                color: Colors.blue,
                                size: 36,
                              ),
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
      ),
    );
  }//page body method

  TextEditingController _commentTextCtr= TextEditingController();
  FocusNode _commentTxtNode=FocusNode();
  StreamController _replyToCtr= StreamController.broadcast();
  String _replyToName="";
  String _replyToId="";

  /*Route build method
  * */
  BuildContext _pageContext;
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext= context;
    _screenSize= MediaQuery.of(_pageContext).size;
    if(_kjToast == null){
      _kjToast= globals.KjToast(Color.fromRGBO(24, 24, 24, 1), _screenSize, _toastCtr, _screenSize.height * .4);
    }
    return WillPopScope(
        child: MaterialApp(
          home: pageBody(),
        ),
        onWillPop: ()async{
          if(_pageDlg) _pageDlg=false;
          else Navigator.of(_pageContext).pop();
          return false;
        }
    );
  }//Route build method

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
                  refreshPost(reloadPage: true);
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