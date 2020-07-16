import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

  @override
  void initState() {
    super.initState();
    fetchLocalData();
  }//route's initstate

  List _likeIds= List();
  fetchLocalData()async{
    Database _con= await _dbTables.wallPosts();
    var _result= await _con.rawQuery("select likes from wall_posts where post_id=?", [widget._gPostId]);
    if(_result.length == 1){
      _likeIds= jsonDecode(_result[0]["likes"]);
      _kjToast= globals.KjToast(12, _screenSize, _toastCtr, _screenSize.height * .4);
      _pageLoadNotifier.add("event");
    }
  }//fetch local data

  ///Gets a single user's like stamp from the server
  Future fetchLikeBlock(String _userId)async{
    try{
      http.Response _resp= await http.post(
        globals.globBaseUrl + "?process_as=fetch_single_user_wall_post_like_stamp",
        body: {
          "user_id": globals.userId,
          "request": _userId
        }
      );
      if(_resp.statusCode == 200){
        var _respObj= jsonDecode(_resp.body);
        String _userDP= _respObj["dp"];
        return Container(
          margin: EdgeInsets.only(bottom: 12),
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
                child: _userId.length == 1 ?
                CircleAvatar(
                  radius: 24,
                  child: Text(
                    _userDP
                  ),
                ):
                CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(_userDP),
                ),
              ), //user dp

              Expanded(
                child: Container(
                  margin: EdgeInsets.only(left:16, right:16),
                  child: Column(
                    children: <Widget>[
                      Container(
                        margin: EdgeInsets.only(bottom: 3),
                        child: Text(
                          _respObj["username"],
                          style: TextStyle(
                            color: Color.fromRGBO(60, 60, 60, 1),
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

  likeBlock(int _itemIndex){
    return FutureBuilder(
      future: fetchLikeBlock(_likeIds[_itemIndex]),
      builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
        if(_snapshot.hasData){
          return _snapshot.data;
        }
        else return Container();
      },
    );
  }//a block in the like list

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
              return snapshot.hasData ? _kjToast : Container;
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