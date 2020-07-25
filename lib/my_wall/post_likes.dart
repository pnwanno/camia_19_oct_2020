import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../globals.dart' as globals;
import '../dbs.dart';

class WallPostLikers extends StatefulWidget{
  _WallPostLikers createState(){
    return _WallPostLikers();
  }
  final String _gPostId;
  WallPostLikers(this._gPostId);
}

class _WallPostLikers extends State<WallPostLikers>{

  globals.KjToast _kjToast;
  DBTables _dbTables= DBTables();
  Directory _appDir;
  Directory _wallDir;
  @override
  void initState() {
    super.initState();
    fetchLocalData();
  }//route's initstate

  List _likeIds= List();
  fetchLocalData()async{
    _appDir= await getApplicationDocumentsDirectory();
    _wallDir= Directory(_appDir.path + "/wall_dir");

    Database _con= await _dbTables.wallPosts();
    var _result= await _con.rawQuery("select likes from wall_posts where post_id=?", [widget._gPostId]);
    if(_result.length == 1){
      _likeIds= jsonDecode(_result[0]["likes"]);
      _kjToast= globals.KjToast(12, _screenSize, _toastCtr, _screenSize.height * .4);
      _pageLoadNotifier.add("event");
    }
  }//fetch local data

  Future followUnfollowUser(String _userId)async{
    _following[_userId]= !_following[_userId];
    _followingNotifier.add("kjut");
    try{
      http.post(
        globals.globBaseUrl + "?process_as=follow_unfollow_wall_user",
        body: {
          "user_id": globals.userId,
          "req_id": _userId
        }
      ).then((_resp)async{
        if(_resp.statusCode == 200){
          Directory _followingDp= Directory(_wallDir.path + "/following");
          await _followingDp.create();

          Database _con= await _dbTables.wallPosts();
          var _respObj= jsonDecode(_resp.body);
          var _r= await _con.rawQuery("select * from followers where user_id=?", [_userId]);
          if(_respObj["status"] == "following"){
            if(_r.length <1){
              _con.execute("update wall_posts set section='following' where user_id='$_userId' and section='unfollowing'");
              String _username=_respObj["username"];
              String _dp= _respObj["dp"];
              List<String> _brkDp= _dp.split("/");
              String _dpName=_brkDp.last;
              _con.execute("insert into followers (user_id, user_name, dp) values (?, ?, ?)", [_userId, _username, _dpName]);
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
              _con.execute("update wall_posts set section='unfollowing' where user_id='$_userId' and section='following'");
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

  ///Gets a single user's like stamp from the server
  Future fetchLikeBlock(String _userId)async{
    try{
      http.Response _resp= await http.post(
        globals.globBaseUrl + "?process_as=fetch_single_user_wall_post_like_stamp",
        body: {
          "user_id": globals.userId,
          "request": _userId,
          "post_id": widget._gPostId
        }
      );
      if(_resp.statusCode == 200){
        var _respObj= jsonDecode(_resp.body);
        String _userDP= _respObj["dp"];
        if(_respObj["following"] == "yes") _following[_userId]= true;
        else _following[_userId]=false;

        Future.delayed(
          Duration(milliseconds: 500),
            (){
              _followingNotifier.add("kjut");
            }
        );
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.only(left:12, right: 12, top:5, bottom: 5),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Color.fromRGBO(32, 32, 32, 1)
              )
            )
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                child: _userDP.length == 1 ?
                CircleAvatar(
                  radius: 20,
                  child: Text(
                    _userDP
                  ),
                ):
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(_userDP),
                ),
              ), //user dp

              Expanded(
                child: Container(
                  margin: EdgeInsets.only(left:16, right:16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        margin: EdgeInsets.only(bottom: 3),
                        child: Text(
                          _respObj["username"],
                          style: TextStyle(
                            color: Color.fromRGBO(120, 120, 120, 1),
                            fontSize: 8,
                            fontFamily: "ubuntu"
                          ),
                        ),
                      ),

                      Container(
                        child: Text(
                          _respObj["fullname"],
                          style: TextStyle(
                              color: Color.fromRGBO(60, 60, 60, 1),
                              fontSize: 9
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ), //username and fullname

              Container(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Container(
                      margin:EdgeInsets.only(bottom: 2),
                      child: Text(
                        "Liked " + _respObj["time"],
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 8,
                        ),
                      ),
                    ), //like time

                    StreamBuilder(
                      stream: _followingNotifier.stream,
                      builder: (BuildContext _ctx, snapshot){
                        if(_userId == globals.userId){
                          return Container();
                        }
                        return Material(
                          color: Colors.transparent,
                          child: InkResponse(
                            onTap: (){
                              followUnfollowUser(_userId);
                            },
                            child: Container(
                              padding: EdgeInsets.only(left:9, right: 9, top: 3, bottom: 3),
                              decoration: BoxDecoration(
                                  color: _following[_userId] ? Colors.orange : Color.fromRGBO(32, 32, 32, 1),
                                  borderRadius: BorderRadius.circular(12)
                              ),
                              child: _following[_userId] ?
                              Row(
                                children: <Widget>[
                                  Icon(
                                      FlutterIcons.account_arrow_left_mco,
                                    color: Colors.white,
                                  ),
                                  Container(
                                    margin: EdgeInsets.only(left:5),
                                    child: Text(
                                      "Unfollow",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10
                                      ),
                                    ),
                                  )
                                ],
                              ):
                              Row(
                                children: <Widget>[
                                  Icon(
                                      FlutterIcons.account_arrow_right_mco,
                                    color: Colors.white,
                                  ),
                                  Container(
                                    margin: EdgeInsets.only(left:5),
                                    child: Text(
                                      "Follow",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  ],
                ),
              ), //like time and follow button
            ],
          ),
        );
      }
    }
    catch(ex){
      _kjToast.showToast(
        text: "Offline mode - kindly connect to the internet",
        duration: Duration(seconds: 3)
      );
    }
  }//fetch like block

  Map<String, bool> _following= Map<String, bool>();

  StreamController _followingNotifier= StreamController.broadcast();
  ///A block in the like list
  likeBlock(int _itemIndex){
    String _targUid= _likeIds[_itemIndex];
    if(!_following.containsKey(_targUid)){
      _following[_targUid]=false;
    }
    return FutureBuilder(
      future: fetchLikeBlock(_targUid),
      builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
        if(_snapshot.hasData){
          return _snapshot.data;
        }
        else return blockShadow();
      },
    );
  }//a block in the like list

  Widget blockShadow(){
    return Container(
      padding: EdgeInsets.only(left:12, right:12, top: 3, bottom: 3),
      margin: EdgeInsets.only(bottom: 3, right: 12),
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: Color.fromRGBO(32, 32, 32, 1)
              )
          )
      ),
      child: Row(
        children: <Widget>[
          Container(
            margin: EdgeInsets.only(right:12),
            child: CircleAvatar(
              radius: 20,
              child: Text("?"),
            ),
          ),
          Expanded(
            child: Container(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    margin: EdgeInsets.only(bottom: 5),
                    width: _screenSize.width * .3,
                    height: 12,
                    decoration: BoxDecoration(
                        color: Color.fromRGBO(32, 32, 32, 1),
                        borderRadius: BorderRadius.circular(7)
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(bottom: 5),
                    width: _screenSize.width * .5,
                    height: 12,
                    decoration: BoxDecoration(
                        color: Color.fromRGBO(32, 32, 32, 1),
                        borderRadius: BorderRadius.circular(7)
                    ),
                  )
                ],
              ),
            ),
          ),
          Container(
            child: Column(
              children: <Widget>[
                Container(
                  margin: EdgeInsets.only(bottom: 3),
                  width: 70,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(32, 32, 32, 1),
                    borderRadius: BorderRadius.circular(5)
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(bottom: 3),
                  width: 70,
                  height: 20,
                  decoration: BoxDecoration(
                      color: Color.fromRGBO(32, 32, 32, 1),
                      borderRadius: BorderRadius.circular(5)
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  pageBody(){
    return Container(
      child: Stack(
        children: <Widget>[
          StreamBuilder(
            stream: _pageLoadNotifier.stream,
            builder: (BuildContext _ctx, AsyncSnapshot snapshot){
              return Container(
                child: snapshot.hasData ?
                kjPullToRefresh(
                  child: ListView.builder(
                    controller: _globalListCtr,
                    itemCount: _likeIds.length,
                      itemBuilder: (BuildContext _ctx, int _itemIndex){
                        if(_itemIndex == 0){
                          return Container(
                            child: Column(
                              children: <Widget>[
                                pullToRefreshContainer(),
                                likeBlock(_itemIndex)
                              ],
                            ),
                          );
                        }
                        else{
                          return likeBlock(_itemIndex);
                        }
                      }
                  )
                ):
                Container(
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                  ),
                ),
              );
            },
          ),
          StreamBuilder(
            stream: _pageLoadNotifier.stream,
            builder: (BuildContext _ctx, AsyncSnapshot snapshot){
              return snapshot.hasData ? _kjToast : Container();
            },
          )
        ],
      ),
    );
  }//page body

  BuildContext _pageContext;
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext= context;
    _screenSize=MediaQuery.of(_pageContext).size;
    return Scaffold(
      backgroundColor: Color.fromRGBO(10, 10, 10, 1),
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(36, 36, 36, 1),
        title: StreamBuilder(
          stream: _pageLoadNotifier.stream,
          builder: (BuildContext _ctx, AsyncSnapshot snapshot){
            return Text(
                (snapshot.hasData) ? "${_likeIds.length} likes": "Likes"
            );
          },
        ),
      ),

      body: FocusScope(
        child: pageBody(),
        onFocusChange: (bool _focState){
          Navigator.of(_pageContext).pop();
          return false;
        },
      ),
    );
  }//route's build

  StreamController _pageLoadNotifier= StreamController.broadcast();
  StreamController _toastCtr= StreamController.broadcast();
  @override
  void dispose() {
    super.dispose();
    _pageLoadNotifier.close();
    pullRefreshCtr.close();
    _toastCtr.close();
    _followingNotifier.close();
    _globalListCtr.dispose();
  }//route's dispose

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