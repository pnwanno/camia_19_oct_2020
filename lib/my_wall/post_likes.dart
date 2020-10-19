import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../globals.dart' as globals;
import '../dbs.dart';
import './profile.dart';

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
  @override
  void initState() {
    super.initState();
    fetchPostLikes();

    _globalListCtr.addListener(() {
      if(_globalListCtr.position.pixels > (_globalListCtr.position.maxScrollExtent - _screenSize.height) && _fetching==false){
        fetchPostLikes();
      }
    });
  }//route's initstate

  List _pageData= List();
  bool _fetching=false;
  fetchPostLikes()async{
    _fetching=true;
    try{
      http.Response _resp= await http.post(
          globals.globBaseUrl + "?process_as=fetch_post_likes",
          body: {
            "user_id": globals.userId,
            "post_id": widget._gPostId,
            "start": _pageData.length.toString()
          }
      );
      if(_resp.statusCode == 200){
        List _respObj= jsonDecode(_resp.body);
        _pageData.addAll(_respObj);
        if(_respObj.length>0) _fetching=false;
        _pageLoadNotifier.add("kjut");
      }
    }
    catch(ex){
      _fetching=false;
      _pageLoadNotifier.add("offline");
    }
  }//fetch post likes

  Future followUnfollowUser(String _userId, int _itemIndex)async{
    if(_pageData[_itemIndex]["following"] == "yes"){
      _pageData[_itemIndex]["following"] = "no";
    }
    else{
      _pageData[_itemIndex]["following"] = "yes";
    }
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

          Database _con= await _dbTables.wallPosts();
          var _respObj= jsonDecode(_resp.body);
          if(_respObj["status"] == "following"){
            _con.execute("update wall_posts set section='following' where user_id='$_userId' and section='unfollowing'");
          }
          else if(_respObj["status"] == "unfollowing"){
            _con.execute("update wall_posts set section='unfollowing' where user_id='$_userId' and section='following'");
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
  }//follow and unfollow

  StreamController _followingNotifier= StreamController.broadcast();

  pageBody(){
    return Container(
      margin: EdgeInsets.only(top: 16),
      child: Stack(
        children: <Widget>[
          StreamBuilder(
            stream: _pageLoadNotifier.stream,
            builder: (BuildContext _ctx, AsyncSnapshot snapshot){
              return Container(
                child: snapshot.hasData  && snapshot.data != "offline"?
                kjPullToRefresh(
                  child: ListView.builder(
                    controller: _globalListCtr,
                    itemCount: _pageData.length+1,
                      itemBuilder: (BuildContext _ctx, int _itemIndex){
                        if(_itemIndex == 0){
                          return Container(
                            child: Column(
                              children: <Widget>[
                                pullToRefreshContainer(),
                              ],
                            ),
                          );
                        }
                        else{
                          return Container(
                            margin: EdgeInsets.only(bottom: 20),
                            padding: EdgeInsets.only(left: 16, right: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  child: GestureDetector(
                                    onTap: (){
                                      Navigator.of(_pageContext).push(CupertinoPageRoute(
                                        builder: (BuildContext _ctx){
                                          return WallProfile(_pageData[_itemIndex - 1]["user_id"], username: _pageData[_itemIndex - 1]["username"],);
                                        }
                                      ));
                                    },
                                    child: Container(
                                      alignment: Alignment.center,
                                      child: _pageData[_itemIndex - 1]["dp"].toString().length>1?
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundImage: NetworkImage(_pageData[_itemIndex - 1]["dp"]),
                                      ):
                                      CircleAvatar(
                                        radius:20,
                                        child: Text(
                                            _pageData[_itemIndex - 1]["dp"]
                                        ),
                                      ),
                                    ),
                                  ),
                                ),//user dp
                                Expanded(
                                  child: Container(
                                    margin: EdgeInsets.only(left: 12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          margin:EdgeInsets.only(bottom: 3),
                                          child: Text(
                                            _pageData[_itemIndex - 1]["username"],
                                            maxLines: 1, overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontFamily: "ubuntu"
                                            ),
                                          ),
                                        ),//username
                                        Container(
                                          margin:EdgeInsets.only(bottom: 3),
                                          child: Text(
                                              _pageData[_itemIndex - 1]["fullname"],
                                            maxLines: 1, overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Color.fromRGBO(200, 200, 200, 1),

                                            ),
                                          ),
                                        )//fullname
                                      ],
                                    ),
                                  ),
                                ),//username and fullname
                                Container(
                                  margin: EdgeInsets.only(left: 12),
                                  child: Column(
                                    children: [
                                      Container(
                                        margin:EdgeInsets.only(bottom: 5),
                                        child: Text(
                                          _pageData[_itemIndex - 1]["time"],
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontStyle: FontStyle.italic
                                          ),
                                        ),
                                      ),
                                      StreamBuilder(
                                        stream: _followingNotifier.stream,
                                        builder: (BuildContext _ctx, AsyncSnapshot _fshot){
                                          if(_pageData[_itemIndex - 1]["user_id"] == globals.userId){
                                            return Container();
                                          }
                                          return Container(
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkResponse(
                                                onTap: (){
                                                  followUnfollowUser(_pageData[_itemIndex - 1]["user_id"], _itemIndex - 1);
                                                },
                                                child: Container(
                                                  padding: EdgeInsets.only(left: 16, right: 16, top: 5, bottom: 5),
                                                  decoration: BoxDecoration(
                                                    color: _pageData[_itemIndex - 1]["following"] == "yes" ? Color.fromRGBO(32, 32, 32, 1) : Colors.orange,
                                                    borderRadius: BorderRadius.circular(12)
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        margin: EdgeInsets.only(right: 7),
                                                        child: Icon(
                                                            _pageData[_itemIndex - 1]["following"] == "yes" ? FlutterIcons.account_arrow_left_mco : FlutterIcons.account_arrow_right_mco,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      Text(
                                                          _pageData[_itemIndex - 1]["following"] == "yes" ? "Unfollow" : "Follow",
                                                        style: TextStyle(
                                                          color: Colors.white
                                                        ),
                                                      )
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    ],
                                  ),
                                )
                              ],
                            ),
                          );
                        }
                      }
                  )
                ):
                    snapshot.hasData && snapshot.data == "offline"? Container(
                      width: _screenSize.width, height: _screenSize.height,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            margin:EdgeInsets.only(bottom: 5),
                            child: Icon(
                              FlutterIcons.cloud_off_outline_mco,
                              size: 60,
                              color: Colors.grey,
                            ),
                          ),
                          Container(
                            child: Text(
                              "Offline",
                              style: TextStyle(
                                color: Colors.grey
                              ),
                            ),
                          )
                        ],
                      ),
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
          _kjToast
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
    if(_kjToast == null){
      _kjToast= globals.KjToast(Color.fromRGBO(24, 24, 24, 1), _screenSize, _toastCtr, _screenSize.height * .4);
    }
    return Scaffold(
      backgroundColor: Color.fromRGBO(10, 10, 10, 1),
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(36, 36, 36, 1),
        title: Text(
            "Post likes"
        )
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